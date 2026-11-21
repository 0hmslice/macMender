import AppKit
import os
import SwiftUI

/// The keyboard window switcher: lists every application's windows and activates the chosen one.
@MainActor
final class WindowSwitcherService: ObservableObject {
    @Published private(set) var isShowing = false
    @Published private(set) var windows: [WindowSummary] = []
    @Published private(set) var selectedIndex = 0
    @Published private(set) var presentationStatus = "Ready to scan"
    @Published private(set) var displayThumbnailSize = 160.0
    @Published private(set) var gridColumnCount = 3
    @Published private(set) var lastActivationDiagnostic = "No window activation attempted"
    @Published private(set) var lastDiscoveryReport = WindowDiscoveryReport.empty
    @Published private(set) var hasRunWindowDiscovery = false
    @Published private(set) var lastThumbnailDiagnostic = "No thumbnail batch yet"
    @Published private var thumbnails: [WindowSummary.ID: NSImage] = [:]

    private let catalog: any WindowCatalogProviding
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.ryan.macMender", category: "WindowSwitcher")
    private var panel: NSPanel?
    private var activeSettings = WindowSwitcherSettings.default
    private var thumbnailTask: Task<Void, Never>?
    private var otherSpacesTask: Task<Void, Never>?
    private var thumbnailCache: [WindowSummary.ID: ThumbnailCacheEntry] = [:]
    private var thumbnailCacheOrder: [WindowSummary.ID] = []
    private let thumbnailCacheLimit = 80
    private let thumbnailCacheDuration: TimeInterval = 20
    private let presentsPanel: Bool

    init(catalog: any WindowCatalogProviding = WindowCatalogService(), presentsPanel: Bool = true) {
        self.catalog = catalog
        self.presentsPanel = presentsPanel
    }

    var selectedWindow: WindowSummary? {
        guard windows.indices.contains(selectedIndex) else { return nil }
        return windows[selectedIndex]
    }

    func show(settings: WindowSwitcherSettings, backwards: Bool = false) {
        activeSettings = settings
        let discovered = discoverWindows(settings: settings)
        hasRunWindowDiscovery = true

        guard !discovered.isEmpty else {
            presentationStatus = "No switchable windows detected"
            return
        }
        windows = discovered
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        selectedIndex = backwards ? windows.count - 1 :
            (windows.first?.processIdentifier == frontmostPID ? min(1, windows.count - 1) : 0)
        isShowing = true
        presentationStatus = "\(discovered.count) windows available"
        if presentsPanel {
            ensurePanel(settings: settings)
            panel?.orderFrontRegardless()
            prefetchThumbnails()
        }
        appendOtherSpaceWindows(settings: settings)
    }

    /// Windows on other Spaces take longer to find, so the switcher opens with the current
    /// Space at once and these join the end of the list a moment later.
    private func appendOtherSpaceWindows(settings: WindowSwitcherSettings) {
        otherSpacesTask?.cancel()
        guard settings.includeOtherSpaces else { return }
        otherSpacesTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let found = await self.catalog.otherSpaceWindows()
            guard !Task.isCancelled, self.isShowing else { return }
            let existing = Set(self.windows.map(\.id))
            let additions = found.filter { window in
                !existing.contains(window.id)
                    && (settings.includeMinimizedWindows || !window.isMinimized)
                    && (settings.includeHiddenApps || !window.isAppHidden)
            }
            guard !additions.isEmpty else { return }
            self.windows.append(contentsOf: additions)
            self.presentationStatus = "\(self.windows.count) windows available"
            if self.presentsPanel {
                self.ensurePanel(settings: settings)
                self.prefetchThumbnails()
            }
        }
    }

    func refreshDiscovery(settings: WindowSwitcherSettings) {
        let discovered = discoverWindows(settings: settings)
        hasRunWindowDiscovery = true
        presentationStatus = discovered.isEmpty ? "No switchable windows detected" : "\(discovered.count) windows available"
    }

    func cycle(backwards: Bool = false) {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex + (backwards ? -1 : 1) + windows.count) % windows.count
    }

    /// Moves the selection with the arrow keys. Sideways wraps like Tab; up and down move a row
    /// in the grid and stop at its edges.
    func moveSelection(columns: Int, rows: Int) {
        guard isShowing, !windows.isEmpty else { return }
        if columns != 0 {
            cycle(backwards: columns < 0)
        }
        if rows != 0, activeSettings.layout == .grid {
            let target = selectedIndex + rows * max(gridColumnCount, 1)
            if windows.indices.contains(target) {
                selectedIndex = target
            }
        }
    }

    func closeSelected() {
        guard isShowing, let selectedWindow else { return }
        close(selectedWindow)
    }

    func minimizeSelected() {
        guard isShowing, let selectedWindow else { return }
        minimize(selectedWindow)
    }

    func cancel() {
        isShowing = false
        otherSpacesTask?.cancel()
        otherSpacesTask = nil
        thumbnailTask?.cancel()
        thumbnailTask = nil
        panel?.orderOut(nil)
    }

    func commit(source: WindowActivationSource = .keyboard) {
        guard isShowing else { return }
        guard let selectedWindow else {
            cancel()
            return
        }
        activateSelectedWindow(selectedWindow, displayedIndex: selectedIndex, source: source)
    }

    func activateDisplayedWindow(_ window: WindowSummary, displayedIndex: Int, source: WindowActivationSource) {
        activateSelectedWindow(window, displayedIndex: displayedIndex, source: source)
    }

    func select(index: Int, source: WindowActivationSource) {
        guard windows.indices.contains(index), selectedIndex != index else { return }
        selectedIndex = index
    }

    func minimize(_ window: WindowSummary) {
        catalog.minimize(window)
        refreshKeepingSelection()
    }

    func close(_ window: WindowSummary) {
        catalog.close(window)
        refreshKeepingSelection()
    }

    func thumbnail(for window: WindowSummary, size: CGSize) -> NSImage? {
        thumbnails[window.id]
    }

    private func discoverWindows(settings: WindowSwitcherSettings) -> [WindowSummary] {
        var discovered = catalog.visibleWindows()
            .filter { settings.includeMinimizedWindows || !$0.isMinimized }
            .filter { settings.includeHiddenApps || !$0.isAppHidden }
        #if DEBUG
        // Development aid: limit the switcher to one application when taking screenshots.
        if let only = ProcessInfo.processInfo.environment["MACMENDER_SWITCHER_APP"] {
            discovered = discovered.filter { NSRunningApplication(processIdentifier: $0.processIdentifier)?.bundleIdentifier == only }
        }
        #endif
        lastDiscoveryReport = catalog.lastDiscoveryReport
        return discovered
    }

    private func refreshKeepingSelection() {
        let selectedID = selectedWindow?.id
        windows = discoverWindows(settings: activeSettings)
        guard !windows.isEmpty else {
            cancel()
            return
        }
        thumbnails = thumbnails.filter { cached in
            windows.contains(where: { $0.id == cached.key })
        }
        if let selectedID, let index = windows.firstIndex(where: { $0.id == selectedID }) {
            selectedIndex = index
        } else {
            selectedIndex = min(selectedIndex, max(windows.count - 1, 0))
        }
        if presentsPanel {
            ensurePanel(settings: activeSettings)
            prefetchThumbnails()
        }
    }

    private func activateSelectedWindow(_ window: WindowSummary, displayedIndex: Int, source: WindowActivationSource) {
        let context = WindowActivationContext(selectedIndex: displayedIndex, highlightedIndex: displayedIndex)
        cancel()
        let outcome = catalog.activate(window, source: source, context: context)
        lastActivationDiagnostic = outcome.reason
        if outcome.success {
            presentationStatus = "Activated \(window.title)"
        } else {
            presentationStatus = "Activation failed for \(window.title)"
            logger.debug("Activation failed \(self.lastActivationDiagnostic, privacy: .private)")
        }
    }

    private func prefetchThumbnails() {
        thumbnailTask?.cancel()
        let currentWindows = windows
        let maxSize = CGSize(width: displayThumbnailSize, height: displayThumbnailSize * 0.68)
        let requestedCount = currentWindows.count
        let start = Date()
        var cachedHits = 0
        var displayThumbnails = [WindowSummary.ID: NSImage]()
        var missingWindows = [WindowSummary]()

        pruneExpiredThumbnailCache()
        for window in currentWindows {
            if let cached = thumbnailCache[window.id], Date().timeIntervalSince(cached.createdAt) < thumbnailCacheDuration {
                displayThumbnails[window.id] = cached.image
                cachedHits += 1
            } else {
                thumbnailCache[window.id] = nil
                missingWindows.append(window)
            }
        }
        thumbnails = displayThumbnails

        guard !missingWindows.isEmpty else {
            lastThumbnailDiagnostic = "thumbnail batch requested=\(requestedCount) cached=\(cachedHits) captured=0 duration=0ms"
            return
        }

        thumbnailTask = Task { @MainActor [weak self] in
            guard let self else { return }
            let captured = await self.catalog.thumbnails(for: missingWindows, maxSize: maxSize)
            guard !Task.isCancelled else { return }
            var updated = self.thumbnails
            for window in missingWindows {
                if let image = captured[window.id] {
                    self.insertThumbnailCache(image, for: window.id)
                    updated[window.id] = image
                }
            }
            self.thumbnails = updated
            let elapsedMS = Int(Date().timeIntervalSince(start) * 1000)
            self.lastThumbnailDiagnostic = "thumbnail batch requested=\(requestedCount) cached=\(cachedHits) captured=\(captured.count) duration=\(elapsedMS)ms"
            self.logger.debug("\(self.lastThumbnailDiagnostic, privacy: .public)")
        }
    }

    private func insertThumbnailCache(_ image: NSImage, for id: WindowSummary.ID) {
        thumbnailCache[id] = ThumbnailCacheEntry(image: image, createdAt: Date())
        thumbnailCacheOrder.removeAll { $0 == id }
        thumbnailCacheOrder.append(id)
        while thumbnailCacheOrder.count > thumbnailCacheLimit, let evicted = thumbnailCacheOrder.first {
            thumbnailCacheOrder.removeFirst()
            thumbnailCache[evicted] = nil
        }
    }

    private func pruneExpiredThumbnailCache() {
        let now = Date()
        thumbnailCache = thumbnailCache.filter { _, entry in
            now.timeIntervalSince(entry.createdAt) < thumbnailCacheDuration
        }
        thumbnailCacheOrder.removeAll { thumbnailCache[$0] == nil }
    }

    private func ensurePanel(settings: WindowSwitcherSettings) {
        // The screen the pointer is on, which is where the person is looking.
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(pointer) } ?? NSScreen.main
        let visibleSize = screen?.visibleFrame.size ?? CGSize(width: 1200, height: 800)
        let metrics = WindowSwitcherPresentationMetrics.calculate(
            layout: settings.layout,
            windowCount: windows.count,
            requestedThumbnailSize: settings.thumbnailSize,
            visibleSize: visibleSize
        )
        displayThumbnailSize = metrics.thumbnailSize
        gridColumnCount = metrics.gridColumnCount

        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(origin: .zero, size: CGSize(width: 480, height: 240)),
                styleMask: [.borderless, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .popUpMenu
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
            panel.backgroundColor = .clear
            panel.isOpaque = false
            panel.ignoresMouseEvents = false
            panel.acceptsMouseMovedEvents = true
            panel.hasShadow = false
            self.panel = panel
        }
        // The panel takes its size from its content, capped to the screen.
        let maximumSize = CGSize(width: visibleSize.width * 0.9, height: visibleSize.height * 0.9)
        let content = WindowSwitcherOverlayView(service: self, settings: settings, maximumWidth: maximumSize.width - Self.shadowMargin * 2)
            .padding(Self.shadowMargin)
        let hostingView = FirstMouseHostingView(rootView: content)
        let fitting = hostingView.fittingSize
        let size = CGSize(width: min(fitting.width, maximumSize.width), height: min(fitting.height, maximumSize.height))
        panel?.contentView = hostingView
        panel?.setContentSize(size)

        if let screen {
            let visible = screen.visibleFrame
            panel?.setFrameOrigin(CGPoint(x: (visible.midX - size.width / 2).rounded(), y: (visible.midY - size.height / 2).rounded()))
        }
    }

    /// Room around the glass panel for its shadow.
    private static let shadowMargin: CGFloat = 28
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

private struct ThumbnailCacheEntry {
    var image: NSImage
    var createdAt: Date
}
