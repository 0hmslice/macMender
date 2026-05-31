import AppKit
import os
import SwiftUI

@MainActor
final class WindowSwitcherService: ObservableObject {
    @Published private(set) var isShowing = false
    @Published private(set) var windows: [WindowSummary] = []
    @Published private(set) var selectedIndex = 0
    @Published private(set) var presentationStatus = "Ready"
    @Published private(set) var overlayTitle = "Window Switcher"
    @Published private(set) var overlaySubtitle = ""
    @Published private(set) var displayThumbnailSize = 160.0
    @Published private(set) var gridColumnCount = 3
    @Published private(set) var isDockPreview = false
    @Published private(set) var lastActivationDiagnostic = "No window activation attempted"
    @Published private var thumbnails: [WindowSummary.ID: NSImage] = [:]

    private let catalog: any WindowCatalogProviding
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.ryan.macMender", category: "WindowSwitcher")
    private var panel: NSPanel?
    private var dockPreviewAnchorFrame: CGRect?
    private var dockPreviewDismissTask: Task<Void, Never>?
    private var dockPreviewMouseMonitor: Any?
    private var dockPreviewLocalMouseMonitor: Any?
    private var thumbnailTask: Task<Void, Never>?
    private var dockPreviewIdleTimeout: TimeInterval = DockPreviewSettings.default.previewIdleTimeout
    private let presentsPanel: Bool

    init(catalog: any WindowCatalogProviding = WindowCatalogService(), presentsPanel: Bool = true) {
        self.catalog = catalog
        self.presentsPanel = presentsPanel
    }

    var selectedWindow: WindowSummary? {
        guard windows.indices.contains(selectedIndex) else { return nil }
        return windows[selectedIndex]
    }

    func show(settings: WindowSwitcherSettings) {
        let discovered = catalog.visibleWindows()
            .filter { settings.includeMinimizedWindows || !$0.isMinimized }
            .filter { settings.includeHiddenApps || !(NSRunningApplication(processIdentifier: $0.processIdentifier)?.isHidden ?? false) }

        guard !discovered.isEmpty else {
            presentationStatus = "No switchable windows detected"
            return
        }
        windows = discovered
        selectedIndex = 0
        isShowing = true
        isDockPreview = false
        overlayTitle = "Window Switcher"
        overlaySubtitle = "All open windows"
        presentationStatus = "\(discovered.count) windows available"
        if presentsPanel {
            ensurePanel(settings: settings, anchorFrame: nil)
            prefetchThumbnails()
            panel?.orderFrontRegardless()
        }
    }

    func showDockPreview(appName: String, settings: WindowSwitcherSettings, anchorFrame: CGRect) {
        showDockPreview(
            identity: DockAppIdentity(title: appName, bundleIdentifier: nil, processIdentifier: nil),
            settings: settings,
            anchorFrame: anchorFrame
        )
    }

    func showDockPreview(identity: DockAppIdentity, settings: WindowSwitcherSettings, anchorFrame: CGRect) {
        guard identity.hasResolvedApplicationIdentity else {
            presentationStatus = "Dock preview skipped for unresolved Dock item \(identity.displayName)"
            logger.debug("Dock preview suppressed unresolved title=\(identity.displayName, privacy: .public)")
            cancel()
            return
        }

        let discovered = catalog.visibleWindows()
            .filter { windowMatchesDockIdentity($0, identity: identity) }
            .filter { settings.includeMinimizedWindows || !$0.isMinimized }
            .filter { settings.includeHiddenApps || !(NSRunningApplication(processIdentifier: $0.processIdentifier)?.isHidden ?? false) }

        guard !discovered.isEmpty else {
            presentationStatus = "No windows detected for \(identity.displayName)"
            logger.debug("Dock preview suppressed noWindows title=\(identity.displayName, privacy: .public) bundle=\(identity.bundleIdentifier ?? "nil", privacy: .public) pid=\(identity.processIdentifier.map(String.init) ?? "nil", privacy: .public)")
            cancel()
            return
        }
        windows = discovered
        selectedIndex = 0
        isShowing = true
        isDockPreview = true
        overlayTitle = identity.displayName
        overlaySubtitle = discovered.count == 1 ? "1 window" : "\(discovered.count) windows"
        presentationStatus = "\(discovered.count) \(identity.displayName) windows available"
        dockPreviewAnchorFrame = anchorFrame
        if presentsPanel {
            ensurePanel(settings: settings, anchorFrame: anchorFrame)
            prefetchThumbnails()
            panel?.orderFrontRegardless()
            startDockPreviewMouseTracking()
        }
    }

    func showDockPreviewForMostRecentApp(settings: WindowSwitcherSettings, anchorFrame: CGRect) {
        guard let window = catalog.visibleWindows().first else {
            presentationStatus = "No windows available for preview"
            return
        }
        showDockPreview(appName: window.appName, settings: settings, anchorFrame: anchorFrame)
    }

    func cycle() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % windows.count
        logger.debug("Selected window index=\(self.selectedIndex, privacy: .public) source=keyboard")
    }

    func cancel() {
        isShowing = false
        dockPreviewAnchorFrame = nil
        thumbnailTask?.cancel()
        thumbnailTask = nil
        dockPreviewDismissTask?.cancel()
        dockPreviewDismissTask = nil
        if let dockPreviewMouseMonitor {
            NSEvent.removeMonitor(dockPreviewMouseMonitor)
        }
        if let dockPreviewLocalMouseMonitor {
            NSEvent.removeMonitor(dockPreviewLocalMouseMonitor)
        }
        dockPreviewMouseMonitor = nil
        dockPreviewLocalMouseMonitor = nil
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

    func activate(_ window: WindowSummary, source: WindowActivationSource = .programmatic) {
        let displayedIndex = windows.firstIndex(where: { $0.id == window.id }) ?? selectedIndex
        activateSelectedWindow(window, displayedIndex: displayedIndex, source: source)
    }

    func activateDisplayedWindow(_ window: WindowSummary, displayedIndex: Int, source: WindowActivationSource) {
        activateSelectedWindow(window, displayedIndex: displayedIndex, source: source)
    }

    func select(index: Int, source: WindowActivationSource) {
        guard windows.indices.contains(index) else { return }
        guard selectedIndex != index else { return }
        selectedIndex = index
        logger.debug("Selected window index=\(index, privacy: .public) source=\(source.rawValue, privacy: .public)")
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

    func updateDockPreviewIdleTimeout(_ timeout: TimeInterval) {
        dockPreviewIdleTimeout = DockPreviewSettings.clampedPreviewIdleTimeout(timeout)
    }

    func scheduleDockPreviewDismiss() {
        guard isDockPreview, isShowing else {
            cancel()
            return
        }

        dockPreviewDismissTask?.cancel()
        dockPreviewDismissTask = Task { @MainActor [weak self] in
            guard let delay = self?.dockPreviewIdleTimeout else { return }
            try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
            guard let self, !Task.isCancelled else { return }
            if !self.isMouseInDockPreviewSafeArea() {
                self.cancel()
            }
        }
    }

    private func refreshKeepingSelection() {
        let selectedID = selectedWindow?.id
        windows = catalog.visibleWindows()
        thumbnails = thumbnails.filter { cached in
            windows.contains(where: { $0.id == cached.key })
        }
        if let selectedID, let index = windows.firstIndex(where: { $0.id == selectedID }) {
            selectedIndex = index
        } else {
            selectedIndex = min(selectedIndex, max(windows.count - 1, 0))
        }
        prefetchThumbnails()
    }

    private func windowMatchesDockIdentity(_ window: WindowSummary, identity: DockAppIdentity) -> Bool {
        if let bundleIdentifier = identity.bundleIdentifier {
            return window.bundleIdentifier == bundleIdentifier
        }
        if let processIdentifier = identity.processIdentifier {
            return window.processIdentifier == processIdentifier
        }
        return false
    }

    private func activateSelectedWindow(_ window: WindowSummary, displayedIndex: Int, source: WindowActivationSource) {
        let context = WindowActivationContext(selectedIndex: displayedIndex, highlightedIndex: displayedIndex)
        let diagnosticPrefix = "source=\(source.rawValue) selectedIndex=\(displayedIndex) highlightedIndex=\(displayedIndex) title=\(window.title) cg=\(window.windowID.map(String.init) ?? "nil") pid=\(window.processIdentifier) bundle=\(window.bundleIdentifier ?? "nil")"
        logger.debug("Activating highlighted window \(diagnosticPrefix, privacy: .public)")
        cancel()
        let outcome = catalog.activate(window, source: source, context: context)
        lastActivationDiagnostic = outcome.reason
        if outcome.success {
            presentationStatus = "Activated \(window.title)"
        } else {
            presentationStatus = "Activation failed for \(window.title)"
            logger.debug("Activation failed \(self.lastActivationDiagnostic, privacy: .public)")
        }
    }

    private func prefetchThumbnails() {
        thumbnailTask?.cancel()
        let currentWindows = windows
        let maxSize = CGSize(width: displayThumbnailSize, height: displayThumbnailSize * 0.68)
        thumbnails = thumbnails.filter { cached in
            currentWindows.contains(where: { $0.id == cached.key })
        }

        thumbnailTask = Task { @MainActor [weak self] in
            guard let self else { return }
            for window in currentWindows where self.thumbnails[window.id] == nil {
                guard !Task.isCancelled else { return }
                if let image = await self.catalog.thumbnail(for: window, maxSize: maxSize), !Task.isCancelled {
                    self.thumbnails[window.id] = image
                }
            }
        }
    }

    private func ensurePanel(settings: WindowSwitcherSettings, anchorFrame: CGRect?) {
        let screen = screen(for: anchorFrame) ?? NSApp.keyWindow?.screen ?? NSApp.mainWindow?.screen ?? NSScreen.main
        let size = panelSize(for: settings, screen: screen)
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(origin: .zero, size: size),
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
            panel.hasShadow = true
            panel.contentView = FirstMouseHostingView(rootView: WindowSwitcherOverlayView(service: self, settings: settings))
            self.panel = panel
        } else {
            panel?.contentView = FirstMouseHostingView(rootView: WindowSwitcherOverlayView(service: self, settings: settings))
            panel?.setContentSize(size)
        }

        if let screen {
            panel?.setFrameOrigin(panelOrigin(size: size, screen: screen, anchorFrame: anchorFrame))
        }
    }

    private func panelSize(for settings: WindowSwitcherSettings, screen: NSScreen?) -> CGSize {
        let visibleSize = screen?.visibleFrame.size ?? CGSize(width: 1200, height: 800)
        let maxWidth = visibleSize.width * (isDockPreview ? 0.48 : 0.72)
        let maxHeight = visibleSize.height * (isDockPreview ? 0.44 : 0.72)
        let windowCount = max(windows.count, 1)
        let maxColumns = isDockPreview ? 3 : 5
        let preferredColumns = isDockPreview ? min(windowCount, 2) : Int(ceil(sqrt(Double(windowCount))))
        let columns = max(1, min(maxColumns, preferredColumns))
        let rows = Int(ceil(Double(windowCount) / Double(columns)))
        let spacing = 12.0
        let horizontalPadding = 36.0
        let verticalPadding = 76.0
        let cardChrome = 22.0
        let cardFooter = 58.0
        let preferredThumbnail = min(settings.thumbnailSize, isDockPreview ? 144 : 168)

        let availableCardWidth = (maxWidth - horizontalPadding - spacing * Double(max(columns - 1, 0))) / Double(columns)
        let availableCardHeight = (maxHeight - verticalPadding - spacing * Double(max(rows - 1, 0))) / Double(rows)
        let thumbnailByWidth = availableCardWidth - cardChrome
        let thumbnailByHeight = (availableCardHeight - cardFooter) / 0.68
        let thumbnail = max(92, min(preferredThumbnail, thumbnailByWidth, thumbnailByHeight))
        displayThumbnailSize = thumbnail
        gridColumnCount = columns

        let cardWidth = thumbnail + cardChrome
        let cardHeight = thumbnail * 0.68 + cardFooter
        let width = cardWidth * Double(columns) + spacing * Double(max(columns - 1, 0)) + horizontalPadding
        let height = cardHeight * Double(rows) + spacing * Double(max(rows - 1, 0)) + verticalPadding
        return CGSize(width: min(maxWidth, max(width, isDockPreview ? 330 : 520)), height: min(maxHeight, max(height, isDockPreview ? 230 : 360)))
    }

    private func panelOrigin(size: CGSize, screen: NSScreen, anchorFrame: CGRect?) -> CGPoint {
        let visible = screen.visibleFrame
        guard let anchorFrame else {
            return CGPoint(x: visible.midX - size.width / 2, y: visible.midY - size.height / 2)
        }

        let centeredX = anchorFrame.midX - size.width / 2
        let x = min(max(centeredX, visible.minX + 16), visible.maxX - size.width - 16)
        let gap = isDockPreview ? 36.0 : 14.0
        let aboveY = anchorFrame.maxY + gap
        let belowY = anchorFrame.minY - size.height - gap
        let y: CGFloat
        if aboveY + size.height <= visible.maxY - 16 {
            y = aboveY
        } else if belowY >= visible.minY + 16 {
            y = belowY
        } else {
            y = min(max(visible.midY - size.height / 2, visible.minY + 16), visible.maxY - size.height - 16)
        }
        return CGPoint(x: x, y: y)
    }

    private func screen(for frame: CGRect?) -> NSScreen? {
        guard let frame else { return nil }
        return NSScreen.screens.max { lhs, rhs in
            lhs.frame.intersection(frame).width * lhs.frame.intersection(frame).height <
                rhs.frame.intersection(frame).width * rhs.frame.intersection(frame).height
        }
    }

    private func startDockPreviewMouseTracking() {
        dockPreviewDismissTask?.cancel()
        if dockPreviewMouseMonitor == nil {
            dockPreviewMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown]) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self, self.isDockPreview, self.isShowing else { return }
                    if !self.isMouseInDockPreviewSafeArea() {
                        self.scheduleDockPreviewDismiss()
                    }
                }
            }
        }
        if dockPreviewLocalMouseMonitor == nil {
            dockPreviewLocalMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved, .leftMouseDown, .rightMouseDown]) { [weak self] event in
                Task { @MainActor [weak self] in
                    guard let self, self.isDockPreview, self.isShowing else { return }
                    if !self.isMouseInDockPreviewSafeArea() {
                        self.scheduleDockPreviewDismiss()
                    }
                }
                return event
            }
        }
    }

    private func isMouseInsidePanel(padding: CGFloat) -> Bool {
        guard let panel, panel.isVisible else { return false }
        return panel.frame.insetBy(dx: -padding, dy: -padding).contains(NSEvent.mouseLocation)
    }

    private func isMouseInsideDockAnchor(padding: CGFloat) -> Bool {
        guard let dockPreviewAnchorFrame else { return false }
        return dockPreviewAnchorFrame.insetBy(dx: -padding, dy: -padding).contains(NSEvent.mouseLocation)
    }

    private func isMouseInDockPreviewSafeArea() -> Bool {
        isMouseInsidePanel(padding: 22) || isMouseInsideDockAnchor(padding: 18)
    }
}

private final class FirstMouseHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
