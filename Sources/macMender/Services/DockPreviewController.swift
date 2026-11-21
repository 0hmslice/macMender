import AppKit
import Foundation
import os
import SwiftUI

/// Shows the windows of the application under the pointer in the Dock and lets the user act on them.
@MainActor
final class DockPreviewController: ObservableObject {
    struct Presentation: Equatable {
        var identity: DockAppIdentity
        var appName: String
        var windows: [WindowSummary]
        var layout: DockPreviewLayout
        var edge: DockEdge
    }

    enum Phase: Equatable {
        case hidden
        case visible
        case dismissing
    }

    @Published private(set) var presentation: Presentation?
    @Published private(set) var thumbnails: [WindowSummary.ID: CGImage] = [:]
    @Published private(set) var phase = Phase.hidden
    @Published private(set) var settings = DockPreviewSettings.default
    /// The card under the pointer or chosen with the arrow keys.
    @Published var hoveredWindowID: WindowSummary.ID? {
        didSet {
            if hoveredWindowID != oldValue { updatePeek() }
        }
    }
    /// Changes whenever a different application's windows replace the ones on show.
    @Published private(set) var contentGeneration = 0

    /// Looks up an application's Dock icon; used to anchor a preview requested from Settings.
    var dockItemLocator: ((String) -> DockHoverTarget?)?
    private(set) var lastStatus = "No preview shown yet"

    static let shadowMargin: CGFloat = 28

    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.ryan.macMender", category: "DockPreview")
    private let fallbackCatalog = WindowCatalogService()
    private var panel: NSPanel?
    private var anchor: DockHoverTarget?
    private var currentHover: DockHoverTarget?
    private var pendingIdentity: DockAppIdentity?
    private var suppressedIdentity: DockAppIdentity?
    private var showTask: Task<Void, Never>?
    private var dismissTask: Task<Void, Never>?
    private var liveTask: Task<Void, Never>?
    private var reconcileTask: Task<Void, Never>?
    private var hideTask: Task<Void, Never>?
    private var eventMonitors = [Any]()
    private var notificationObservers = [NSObjectProtocol]()
    private var showGeneration = 0
    private var lastDismissedAt = Date.distantPast
    private var pinnedUntil = Date.distantPast
    private var thumbnailOrder = [WindowSummary.ID]()
    private let thumbnailCacheLimit = 80
    /// Delay when the pointer slides from one Dock icon to another with a preview already open.
    private let handOffDelay: TimeInterval = 0.06
    private let handOffWindow: TimeInterval = 0.45
    /// Delay before another icon takes over while the pointer is heading for the open preview.
    private let aimDelay: TimeInterval = 0.3
    /// The highlighted card and an open peek refresh every tick; the other cards every third.
    private let liveTickInterval: TimeInterval = 0.1
    /// How long the pointer rests on a card before the window is shown at full size.
    private let peekDelay: TimeInterval = 0.6
    /// How long a dragged item rests on a card before its window comes forward.
    private let springLoadDelay: TimeInterval = 0.55
    private var springLoadTask: Task<Void, Never>?
    private var peekWindowID: CGWindowID?
    private let peekSwitchDelay: TimeInterval = 0.12
    private let keyTap = DockPreviewKeyTap()
    private let peekPanel = DockPreviewPeekPanel()
    private var peekTask: Task<Void, Never>?

    var isShowing: Bool { phase == .visible }

    // MARK: Configuration

    func update(settings: DockPreviewSettings) {
        guard self.settings != settings else { return }
        self.settings = settings
        if !settings.enabled {
            cancelPendingShow()
            dismiss(animated: false)
        } else if let presentation, phase == .visible {
            apply(windows: presentation.windows, identity: presentation.identity, appName: presentation.appName)
            updateKeyTap()
            updatePeek()
        }
    }

    func stop() {
        currentHover = nil
        suppressedIdentity = nil
        cancelPendingShow()
        dismiss(animated: false)
    }

    // MARK: Dock hover

    func hoverChanged(_ target: DockHoverTarget?) {
        currentHover = target
        guard let target else {
            suppressedIdentity = nil
            cancelPendingShow()
            evaluatePointer()
            return
        }

        if let suppressedIdentity {
            if suppressedIdentity.isSameDockItem(as: target.identity) { return }
            self.suppressedIdentity = nil
        }

        let isExcluded = target.identity.bundleIdentifier.map(settings.excludedBundleIdentifiers.contains) ?? false
        guard target.isRunning, !isExcluded else {
            cancelPendingShow()
            dismiss()
            return
        }

        if phase == .visible, presentation?.identity.isSameDockItem(as: target.identity) == true {
            cancelPendingShow()
            cancelDismissTimer()
            return
        }
        guard pendingIdentity?.isSameDockItem(as: target.identity) != true else { return }

        let delay: TimeInterval
        if phase == .visible {
            // Crossing a neighboring icon on the way up to the open preview should not replace it.
            delay = safeZone?.isInCorridor(NSEvent.mouseLocation) == true ? aimDelay : handOffDelay
        } else if Date().timeIntervalSince(lastDismissedAt) < handOffWindow {
            delay = handOffDelay
        } else {
            delay = settings.hoverDelay
        }
        scheduleShow(for: target, delay: delay)
    }

    /// A press on a Dock icon launches, activates, or opens that application's menu; the preview
    /// steps aside and stays away until the pointer moves to another icon.
    func dockMouseDown() {
        suppressedIdentity = currentHover?.identity
        cancelPendingShow()
        dismiss()
    }

    private func scheduleShow(for target: DockHoverTarget, delay: TimeInterval) {
        showTask?.cancel()
        showGeneration += 1
        let generation = showGeneration
        pendingIdentity = target.identity
        logger.debug("Preview scheduled delay=\(delay, privacy: .public)")
        showTask = Task { @MainActor [weak self] in
            if delay > 0 {
                try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
            }
            guard let self, !Task.isCancelled, self.showGeneration == generation else { return }
            let windows = await self.discoverWindows(for: target.identity)
            guard !Task.isCancelled, self.showGeneration == generation else { return }
            self.pendingIdentity = nil
            guard let hover = self.currentHover, hover.identity.isSameDockItem(as: target.identity) else {
                return
            }
            guard !windows.isEmpty else {
                self.lastStatus = "No windows found for \(target.identity.displayName)"
                self.dismiss()
                return
            }
            self.present(windows: windows, anchor: hover)
        }
    }

    private func cancelPendingShow() {
        showTask?.cancel()
        showTask = nil
        pendingIdentity = nil
        showGeneration += 1
    }

    // MARK: Discovery

    private func discoverWindows(for identity: DockAppIdentity) async -> [WindowSummary] {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let apps = NSWorkspace.shared.runningApplications
            .filter { app in
                guard !app.isTerminated else { return false }
                if identity.isMinimizedWindow {
                    // A minimized window's Dock tile does not say which application owns it.
                    return app.activationPolicy == .regular && app.processIdentifier != currentPID
                }
                if let bundleIdentifier = identity.bundleIdentifier, app.bundleIdentifier == bundleIdentifier { return true }
                return identity.processIdentifier == app.processIdentifier
            }
            .map(WindowAppTarget.init)
        guard !apps.isEmpty else { return [] }

        let scope = WindowDiscoveryScope(
            includeOtherSpaces: settings.includeOtherSpaces && !identity.isMinimizedWindow,
            screenFrames: NSScreen.screens.map(\.frame)
        )
        let result = await Task.detached(priority: .userInitiated) {
            WindowDiscoveryEngine.discover(apps: apps, scope: scope)
        }.value

        if identity.isMinimizedWindow {
            let title = identity.title.trimmingCharacters(in: .whitespacesAndNewlines)
            return result.windows.filter { window in
                window.isMinimized && (window.rawTitle ?? window.title).trimmingCharacters(in: .whitespacesAndNewlines) == title
            }
        }

        let settings = settings
        return result.windows.filter { window in
            if window.isMinimized, !settings.includeMinimizedWindows { return false }
            if window.isAppHidden, !settings.includeHiddenApps { return false }
            if window.isOnOtherSpace, !settings.includeOtherSpaces { return false }
            if window.processIdentifier == currentPID {
                // macMender's own panels and popovers are not windows worth previewing.
                let title = window.rawTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                return !title.isEmpty && window.frame.width >= 240 && window.frame.height >= 160
            }
            return true
        }
    }

    // MARK: Presentation

    private func present(windows: [WindowSummary], anchor: DockHoverTarget) {
        let isNewContent = presentation?.identity.isSameDockItem(as: anchor.identity) != true
        var anchor = anchor
        if let screenFrame = screen(for: anchor.iconFrame)?.frame {
            // An auto-hiding Dock may still be sliding in when its frames are read.
            let resting = DockPreviewPlacement.restingFrames(
                iconFrame: anchor.iconFrame,
                dockFrame: anchor.dockFrame,
                edge: anchor.edge,
                screenFrame: screenFrame
            )
            anchor.iconFrame = resting.iconFrame
            anchor.dockFrame = resting.dockFrame
        }
        self.anchor = anchor
        hideTask?.cancel()
        hideTask = nil
        cancelDismissTimer()
        hoveredWindowID = nil
        if isNewContent {
            contentGeneration += 1
        }
        apply(windows: windows, identity: anchor.identity, appName: anchor.identity.displayName)

        guard let panel = ensurePanel() else { return }
        let wasHidden = phase != .visible
        if wasHidden {
            // Start from the hidden state so the appearance animation has somewhere to begin.
            phase = .hidden
        }
        panel.orderFrontRegardless()
        if wasHidden {
            Task { @MainActor [weak self] in
                guard let self, self.presentation != nil, self.hideTask == nil else { return }
                self.phase = .visible
            }
        }

        startTracking()
        refreshThumbnails(for: windows)
        startLiveRefresh()
        lastStatus = "Showing \(windows.count) \(windows.count == 1 ? "window" : "windows") for \(anchor.identity.displayName)"
        logger.debug("\(self.lastStatus, privacy: .private)")
    }

    /// Lays the windows out and sizes the panel around them.
    private func apply(windows: [WindowSummary], identity: DockAppIdentity, appName: String) {
        guard let anchor else { return }
        let screen = screen(for: anchor.iconFrame)
        let screenFrame = screen?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let visibleFrame = screen?.visibleFrame ?? screenFrame
        let layout = DockPreviewLayout.compute(
            aspectRatios: windows.map(\.aspectRatio),
            thumbnailHeight: settings.previewSize,
            showTitles: settings.showTitles,
            showHeader: settings.showAppHeader,
            edge: anchor.edge,
            maximumContentSize: DockPreviewLayout.maximumContentSize(screenSize: visibleFrame.size, edge: anchor.edge)
        )
        presentation = Presentation(identity: identity, appName: appName, windows: windows, layout: layout, edge: anchor.edge)

        let contentFrame = DockPreviewPlacement.contentFrame(
            contentSize: layout.contentSize,
            iconFrame: anchor.iconFrame,
            dockFrame: anchor.dockFrame,
            edge: anchor.edge,
            screenFrame: screenFrame,
            visibleFrame: visibleFrame
        )
        ensurePanel()?.setFrame(contentFrame.insetBy(dx: -Self.shadowMargin, dy: -Self.shadowMargin), display: true)
    }

    private var contentFrame: CGRect? {
        guard let panel, presentation != nil else { return nil }
        return panel.frame.insetBy(dx: Self.shadowMargin, dy: Self.shadowMargin)
    }

    func dismiss(animated: Bool = true) {
        guard phase == .visible || (phase == .hidden && presentation != nil) else { return }
        stopTracking()
        cancelDismissTimer()
        liveTask?.cancel()
        liveTask = nil
        reconcileTask?.cancel()
        reconcileTask = nil
        lastDismissedAt = Date()
        hoveredWindowID = nil
        springLoadTask?.cancel()
        springLoadTask = nil

        let duration = animated && settings.animationStyle != .none ? dismissAnimationDuration : 0
        guard duration > 0 else {
            finishDismiss()
            return
        }
        phase = .dismissing
        hideTask?.cancel()
        hideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(duration * 1000)))
            guard let self, !Task.isCancelled else { return }
            self.finishDismiss()
        }
    }

    private func finishDismiss() {
        hideTask = nil
        phase = .hidden
        peekPanel.hide(animated: false)
        panel?.orderOut(nil)
        presentation = nil
        anchor = nil
    }

    /// Appearance timing, shortened when the user prefers reduced motion.
    var appearAnimationDuration: TimeInterval {
        let duration = settings.animationDuration
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? min(duration, 0.12) : duration
    }

    var dismissAnimationDuration: TimeInterval {
        max(appearAnimationDuration * 0.7, 0.05)
    }

    private func ensurePanel() -> NSPanel? {
        if let panel { return panel }
        let panel = DockPreviewPanel(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 240),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.acceptsMouseMovedEvents = true
        panel.animationBehavior = .none
        panel.isReleasedWhenClosed = false
        let hostingView = DockPreviewHostingView(rootView: DockPreviewView(controller: self))
        hostingView.sizingOptions = []
        panel.contentView = hostingView
        self.panel = panel
        return panel
    }

    private func screen(for frame: CGRect) -> NSScreen? {
        let center = CGPoint(x: frame.midX, y: frame.midY)
        return NSScreen.screens.first { $0.frame.insetBy(dx: -2, dy: -2).contains(center) }
            ?? NSScreen.screens.min { lhs, rhs in
                // A hidden Dock's frames lie just beyond the edge of its screen.
                Self.distance(from: center, to: lhs.frame) < Self.distance(from: center, to: rhs.frame)
            }
            ?? NSScreen.main
    }

    private static func distance(from point: CGPoint, to rect: CGRect) -> CGFloat {
        let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
        let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
        return hypot(dx, dy)
    }

    // MARK: Pointer tracking

    private func startTracking() {
        guard eventMonitors.isEmpty else { return }
        let moveMask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged]
        let downMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        eventMonitors = [
            NSEvent.addGlobalMonitorForEvents(matching: moveMask) { [weak self] _ in
                MainActor.assumeIsolated { self?.evaluatePointer() }
            },
            NSEvent.addLocalMonitorForEvents(matching: moveMask) { [weak self] event in
                MainActor.assumeIsolated { self?.evaluatePointer() }
                return event
            },
            NSEvent.addGlobalMonitorForEvents(matching: downMask) { [weak self] _ in
                MainActor.assumeIsolated { self?.mouseDownOutsidePreview() }
            },
            NSEvent.addLocalMonitorForEvents(matching: [.otherMouseDown, .rightMouseDown]) { [weak self] event in
                let handled = MainActor.assumeIsolated {
                    guard let self else { return false }
                    if event.type == .rightMouseDown { return self.showMenuForHoveredWindow(with: event) }
                    return event.buttonNumber == 2 && self.closeHoveredWindow()
                }
                return handled ? nil : event
            }
        ].compactMap { $0 }

        let workspaceCenter = NSWorkspace.shared.notificationCenter
        keyTap.handler = { [weak self] keyCode, flags in
            self?.handleKey(keyCode: keyCode, flags: flags) ?? false
        }
        updateKeyTap()

        notificationObservers = [
            workspaceCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.dismiss(animated: false) }
            },
            workspaceCenter.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] notification in
                let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
                let bundleIdentifier = app?.bundleIdentifier
                MainActor.assumeIsolated {
                    guard let self, let presentation = self.presentation, bundleIdentifier != nil,
                          presentation.identity.bundleIdentifier == bundleIdentifier
                            || presentation.windows.contains(where: { $0.bundleIdentifier == bundleIdentifier }) else {
                        return
                    }
                    self.dismiss()
                }
            }
        ]
    }

    private func stopTracking() {
        eventMonitors.forEach(NSEvent.removeMonitor)
        eventMonitors = []
        keyTap.stop()
        notificationObservers.forEach(NSWorkspace.shared.notificationCenter.removeObserver)
        notificationObservers = []
    }

    private var safeZone: DockPreviewSafeZone? {
        guard let anchor, let contentFrame else { return nil }
        return DockPreviewSafeZone(iconFrame: anchor.iconFrame, contentFrame: contentFrame, edge: anchor.edge)
    }

    private var isPointerInSafeZone: Bool {
        safeZone?.contains(NSEvent.mouseLocation) ?? false
    }

    /// A context menu opened from a card runs its own event loop; the preview must outlive it.
    private var isMenuOpen: Bool {
        isMenuTracking || RunLoop.main.currentMode == .eventTracking
    }

    private var isMenuTracking = false

    private func evaluatePointer() {
        guard phase == .visible else { return }
        if isPointerInSafeZone || Date() < pinnedUntil {
            cancelDismissTimer()
        } else if dismissTask == nil {
            startDismissTimer()
        }
    }

    private func startDismissTimer() {
        let delay = settings.dismissDelay
        dismissTask = Task { @MainActor [weak self] in
            while true {
                try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
                guard let self, !Task.isCancelled else { return }
                if self.isPointerInSafeZone {
                    self.dismissTask = nil
                    return
                }
                // Keep waiting while pinned, while a menu is open, or while another icon's
                // preview is about to replace this one.
                if Date() < self.pinnedUntil || self.isMenuOpen || self.pendingIdentity != nil { continue }
                self.dismissTask = nil
                self.dismiss()
                return
            }
        }
    }

    private func cancelDismissTimer() {
        dismissTask?.cancel()
        dismissTask = nil
    }

    private func mouseDownOutsidePreview() {
        // Presses on Dock icons are handled by `dockMouseDown`; this covers clicks elsewhere.
        guard phase == .visible, !isMenuOpen, Date() >= pinnedUntil, !isPointerInSafeZone else { return }
        dismiss()
    }

    // MARK: Thumbnails

    private func refreshThumbnails(for windows: [WindowSummary]) {
        Task { @MainActor [weak self] in
            await self?.captureThumbnails(for: windows)
        }
    }

    private func captureThumbnails(for windows: [WindowSummary]) async {
        guard !windows.isEmpty else { return }
        let scale = panel?.screen?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let height = presentation?.layout.thumbnailHeight ?? CGFloat(settings.previewSize)
        let maxPixelSize = CGSize(
            width: height * DockPreviewLayout.Metrics.maximumAspectRatio * scale,
            height: height * scale
        )
        var images = [WindowSummary.ID: CGImage]()
        if PrivateWindowAPI.canCaptureWindows {
            let requests = windows.compactMap { window in
                window.windowID.map { WindowThumbnailRequest(id: window.id, windowID: $0, maxPixelSize: maxPixelSize) }
            }
            images = await WindowThumbnailCapturer.capture(requests)
        } else {
            let pointSize = CGSize(width: maxPixelSize.width / scale, height: maxPixelSize.height / scale)
            for (id, image) in await fallbackCatalog.thumbnails(for: windows, maxSize: pointSize) {
                images[id] = image.cgImage(forProposedRect: nil, context: nil, hints: nil)
            }
        }
        guard !images.isEmpty else { return }
        store(images)
    }

    private func store(_ images: [WindowSummary.ID: CGImage]) {
        var updated = thumbnails
        for (id, image) in images {
            updated[id] = image
            thumbnailOrder.removeAll { $0 == id }
            thumbnailOrder.append(id)
        }
        while thumbnailOrder.count > thumbnailCacheLimit {
            updated[thumbnailOrder.removeFirst()] = nil
        }
        thumbnails = updated
    }

    /// Keeps the preview current while it is open. Captures are awaited one batch at a time, so
    /// a slow window server lowers the frame rate instead of queueing work.
    private func startLiveRefresh() {
        liveTask?.cancel()
        let interval = liveTickInterval
        liveTask = Task { @MainActor [weak self] in
            var tick = 0
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(Int(interval * 1000)))
                guard let self, !Task.isCancelled, self.phase == .visible, let presentation = self.presentation else { return }
                tick += 1
                if tick.isMultiple(of: 18) {
                    await self.reconcile()
                }
                guard self.settings.livePreviews else { continue }
                // Minimized windows do not change, so their first capture is kept. Without the
                // fast capture path every refresh is costly, so only the slower rate is used.
                let live = presentation.windows.filter { !$0.isMinimized }
                if tick.isMultiple(of: 3) {
                    await self.captureThumbnails(for: live)
                } else if PrivateWindowAPI.canCaptureWindows, let hovered = live.first(where: { $0.id == self.hoveredWindowID }) {
                    await self.captureThumbnails(for: [hovered])
                }
                if tick.isMultiple(of: 2) {
                    await self.refreshPeek()
                }
            }
        }
    }

    /// Updates an open peek so it tracks the window instead of freezing at its first frame.
    private func refreshPeek() async {
        guard peekPanel.isVisible, let windowID = peekWindowID else { return }
        let image = await Task.detached(priority: .userInitiated) {
            PrivateWindowAPI.captureWindow(windowID, fullResolution: true)
        }.value
        guard let image, peekPanel.isVisible, peekWindowID == windowID else { return }
        peekPanel.update(image: image)
    }

    /// Re-reads the application's windows so cards appear and disappear as windows do.
    private func reconcile() async {
        guard let presentation, phase == .visible else { return }
        let identity = presentation.identity
        let discovered = await discoverWindows(for: identity)
        guard phase == .visible, let current = self.presentation, current.identity == identity else { return }
        guard !discovered.isEmpty else {
            dismiss()
            return
        }

        // Keep existing cards where they are; new windows join at the end.
        let discoveredByID = Dictionary(discovered.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        let existingIDs = Set(current.windows.map(\.id))
        let merged = current.windows.compactMap { discoveredByID[$0.id] } + discovered.filter { !existingIDs.contains($0.id) }
        guard merged != current.windows else { return }
        apply(windows: merged, identity: identity, appName: current.appName)
        refreshThumbnails(for: merged.filter { thumbnails[$0.id] == nil || !existingIDs.contains($0.id) })
    }

    private func scheduleReconcile(after delays: [TimeInterval]) {
        reconcileTask?.cancel()
        reconcileTask = Task { @MainActor [weak self] in
            var elapsed: TimeInterval = 0
            for delay in delays {
                try? await Task.sleep(for: .milliseconds(Int((delay - elapsed) * 1000)))
                elapsed = delay
                guard let self, !Task.isCancelled else { return }
                await self.reconcile()
            }
        }
    }

    // MARK: Window actions

    func activate(_ window: WindowSummary) {
        dismiss()
        let outcome = WindowActions.activate(window)
        lastStatus = outcome.success ? "Activated \(window.title)" : "Could not activate \(window.title)"
        logger.debug("\(outcome.reason, privacy: .private)")
    }

    func close(_ window: WindowSummary) {
        guard WindowActions.close(window) else {
            NSSound.beep()
            return
        }
        guard let presentation else { return }
        // Remove the card at once; a window that refuses to close (unsaved changes) returns on reconcile.
        let remaining = presentation.windows.filter { $0.id != window.id }
        if hoveredWindowID == window.id {
            hoveredWindowID = nil
        }
        if remaining.isEmpty {
            dismiss()
        } else {
            apply(windows: remaining, identity: presentation.identity, appName: presentation.appName)
        }
        scheduleReconcile(after: [0.45, 1.2])
    }

    @discardableResult
    private func closeHoveredWindow() -> Bool {
        guard phase == .visible, let hoveredWindowID,
              let window = presentation?.windows.first(where: { $0.id == hoveredWindowID }) else {
            return false
        }
        close(window)
        return true
    }

    /// The right-click menu is an AppKit menu: its items keep working while the preview behind
    /// it redraws with fresh thumbnails.
    private func showMenuForHoveredWindow(with event: NSEvent) -> Bool {
        guard phase == .visible, let hoveredWindowID, let view = panel?.contentView,
              let window = presentation?.windows.first(where: { $0.id == hoveredWindowID }) else {
            return false
        }
        peekPanel.hide()
        let menu = NSMenu()
        menu.autoenablesItems = false
        func add(_ title: String, enabled: Bool = true, _ action: @escaping @MainActor () -> Void) {
            let item = DockPreviewMenuItem(title: title, handler: action)
            item.isEnabled = enabled
            menu.addItem(item)
        }
        add("Bring to Front") { [weak self] in self?.activate(window) }
        add(window.isMinimized ? "Restore" : "Minimize") { [weak self] in self?.toggleMinimized(window) }
        add(window.isFullScreen ? "Exit Full Screen" : "Enter Full Screen") { [weak self] in self?.toggleFullScreen(window) }
        add("Close Window") { [weak self] in self?.close(window) }
        menu.addItem(.separator())
        for arrangement in WindowArrangement.allCases {
            add(arrangement.title, enabled: !window.isFullScreen) { [weak self] in self?.arrange(window, as: arrangement) }
        }
        if hasMultipleDisplays {
            add("Move to Next Display", enabled: !window.isFullScreen) { [weak self] in self?.moveToNextDisplay(window) }
        }
        menu.addItem(.separator())
        add("Close All Windows") { [weak self] in self?.closeAllWindows() }
        add("Hide \(window.appName)") { [weak self] in self?.hideApplication() }
        add("Quit \(window.appName)") { [weak self] in self?.quitApplication() }

        isMenuTracking = true
        menu.popUp(positioning: nil, at: view.convert(event.locationInWindow, from: nil), in: view)
        isMenuTracking = false
        evaluatePointer()
        return true
    }

    func toggleMinimized(_ window: WindowSummary) {
        guard WindowActions.setMinimized(window, minimized: !window.isMinimized) else {
            NSSound.beep()
            return
        }
        scheduleReconcile(after: [0.35, 0.9])
    }

    func toggleFullScreen(_ window: WindowSummary) {
        dismiss()
        if window.isMinimized {
            WindowActions.setMinimized(window, minimized: false)
        }
        if !WindowActions.toggleFullScreen(window) {
            NSSound.beep()
        }
    }

    func arrange(_ window: WindowSummary, as arrangement: WindowArrangement) {
        dismiss()
        guard WindowActions.arrange(window, as: arrangement) else {
            NSSound.beep()
            return
        }
        WindowActions.activate(window)
    }

    func moveToNextDisplay(_ window: WindowSummary) {
        dismiss()
        guard WindowActions.moveToNextDisplay(window) else {
            NSSound.beep()
            return
        }
        WindowActions.activate(window)
    }

    var hasMultipleDisplays: Bool {
        NSScreen.screens.count > 1
    }

    /// A dragged item is resting on a card: bring that window forward so it can be dropped there.
    func dragTargetChanged(_ window: WindowSummary, isTargeted: Bool) {
        springLoadTask?.cancel()
        springLoadTask = nil
        guard isTargeted else {
            if hoveredWindowID == window.id { hoveredWindowID = nil }
            return
        }
        hoveredWindowID = window.id
        cancelDismissTimer()
        let delay = springLoadDelay
        springLoadTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
            guard let self, !Task.isCancelled, self.phase == .visible, self.hoveredWindowID == window.id else { return }
            self.activate(window)
        }
    }

    func closeAllWindows() {
        guard let presentation else { return }
        presentation.windows.forEach { WindowActions.close($0) }
        scheduleReconcile(after: [0.45, 1.2])
    }

    func hideApplication() {
        guard let presentation else { return }
        dismiss()
        runningApplications(for: presentation).forEach { $0.hide() }
    }

    func quitApplication() {
        guard let presentation else { return }
        dismiss()
        runningApplications(for: presentation).forEach { $0.terminate() }
    }

    private func runningApplications(for presentation: Presentation) -> [NSRunningApplication] {
        if let bundleIdentifier = presentation.identity.bundleIdentifier {
            return NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
        }
        // A minimized window's tile names no application; its windows do.
        let pids = Set(presentation.windows.map(\.processIdentifier)).union(presentation.identity.processIdentifier.map { [$0] } ?? [])
        return pids.compactMap(NSRunningApplication.init(processIdentifier:))
    }

    func applicationIcon(for presentation: Presentation) -> NSImage? {
        runningApplications(for: presentation).first?.icon
    }

    // MARK: Keyboard

    private func updateKeyTap() {
        if settings.keyboardNavigation, phase != .dismissing, presentation != nil, !eventMonitors.isEmpty {
            keyTap.start()
        } else {
            keyTap.stop()
        }
    }

    /// Keys act on the preview only while the pointer is over it, so typing in another
    /// application with the pointer parked on the Dock is never interrupted.
    private func handleKey(keyCode: Int64, flags: CGEventFlags) -> Bool {
        guard phase == .visible, settings.keyboardNavigation, !isMenuOpen,
              let presentation, let contentFrame,
              contentFrame.insetBy(dx: -8, dy: -8).contains(NSEvent.mouseLocation) else {
            return false
        }
        let layout = presentation.layout
        let cards = Array(presentation.windows.prefix(layout.cardFrames.count))
        let selectedIndex = hoveredWindowID.flatMap { id in cards.firstIndex { $0.id == id } }
        let modifiers = flags.intersection([.maskCommand, .maskControl, .maskAlternate])

        if modifiers == .maskCommand, keyCode == 13 { // Command-W
            guard let selectedIndex else { return false }
            close(cards[selectedIndex])
            if let remaining = self.presentation?.windows.prefix(self.presentation?.layout.cardFrames.count ?? 0), !remaining.isEmpty {
                hoveredWindowID = remaining[min(selectedIndex, remaining.count - 1)].id
            }
            return true
        }
        guard modifiers.isEmpty else { return false }

        let direction: DockPreviewLayout.Direction
        switch keyCode {
        case 123: direction = .left
        case 124: direction = .right
        case 125: direction = .down
        case 126: direction = .up
        case 36, 76: // Return, Enter
            guard let selectedIndex else { return false }
            activate(cards[selectedIndex])
            return true
        case 53: // Escape
            dismiss()
            return true
        default:
            return false
        }
        if let next = layout.cardIndex(from: selectedIndex, moving: direction, edge: presentation.edge) {
            hoveredWindowID = cards[next].id
        }
        return true
    }

    // MARK: Peek

    /// Shows the highlighted window at full size once the pointer has rested on its card.
    private func updatePeek() {
        peekTask?.cancel()
        peekTask = nil
        guard settings.peekOnHover, phase == .visible, WindowThumbnailCapturer.isAvailable,
              springLoadTask == nil, NSEvent.pressedMouseButtons == 0,
              let id = hoveredWindowID,
              let window = presentation?.windows.first(where: { $0.id == id }),
              let windowID = window.windowID else {
            peekPanel.hide()
            return
        }

        // Moving between cards with a peek already open swaps it quickly instead of starting over.
        let delay = peekPanel.isVisible ? peekSwitchDelay : peekDelay
        peekTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
            guard let self, !Task.isCancelled, self.hoveredWindowID == id else { return }
            let image = await Task.detached(priority: .userInitiated) {
                PrivateWindowAPI.captureWindow(windowID, fullResolution: true)
            }.value
            guard !Task.isCancelled, self.hoveredWindowID == id, self.phase == .visible, let panel = self.panel else { return }
            guard let image else {
                self.peekPanel.hide()
                return
            }
            let screen = panel.screen ?? NSScreen.main
            let visibleFrame = screen?.visibleFrame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
            let scale = screen?.backingScaleFactor ?? 2
            let isOnScreen = !window.isMinimized && !window.isOnOtherSpace && !window.isAppHidden
            let windowSize = window.frame.width > 1 && window.frame.height > 1
                ? window.frame.size
                : CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
            let frame = DockPreviewPeekPlacement.frame(
                windowFrame: isOnScreen ? Self.appKitFrame(fromAccessibilityFrame: window.frame) : nil,
                windowSize: windowSize,
                visibleFrame: visibleFrame
            )
            self.peekWindowID = windowID
            self.peekPanel.show(
                image: image,
                frame: frame,
                level: NSWindow.Level(rawValue: panel.level.rawValue - 1),
                animated: !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
            )
        }
    }

    /// Window frames from Accessibility have their origin at the top left of the primary display.
    private static func appKitFrame(fromAccessibilityFrame frame: CGRect) -> CGRect {
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return frame }
        return CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
    }

    // MARK: Settings preview

    /// Shows a real preview for a running application so settings can be judged without visiting the Dock.
    func showSamplePreview(preferring preferredBundleIdentifier: String? = nil, pinnedFor pinDuration: TimeInterval = 4) {
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let candidates = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != currentPID && $0.bundleIdentifier != nil }
            .sorted { lhs, _ in lhs.bundleIdentifier == preferredBundleIdentifier }
        Task { @MainActor [weak self] in
            guard let self else { return }
            for app in candidates {
                guard let bundleIdentifier = app.bundleIdentifier else { continue }
                let identity = DockAppIdentity(
                    title: app.localizedName ?? bundleIdentifier,
                    bundleIdentifier: bundleIdentifier,
                    processIdentifier: app.processIdentifier
                )
                let windows = await self.discoverWindows(for: identity)
                guard !windows.isEmpty else { continue }
                let anchor = self.dockItemLocator?(bundleIdentifier) ?? Self.fallbackAnchor(for: identity)
                self.cancelPendingShow()
                self.pinnedUntil = Date().addingTimeInterval(pinDuration)
                self.present(windows: windows, anchor: anchor)
                self.startDismissTimer()
                return
            }
            self.lastStatus = "No application windows are open to preview"
        }
    }

    private static func fallbackAnchor(for identity: DockAppIdentity) -> DockHoverTarget {
        let screenFrame = NSScreen.main?.frame ?? CGRect(x: 0, y: 0, width: 1440, height: 900)
        let iconFrame = CGRect(x: screenFrame.midX - 28, y: screenFrame.minY + 6, width: 56, height: 56)
        return DockHoverTarget(
            identity: identity,
            isRunning: true,
            iconFrame: iconFrame,
            dockFrame: CGRect(x: screenFrame.minX, y: screenFrame.minY, width: screenFrame.width, height: 68),
            edge: .bottom
        )
    }
}

private final class DockPreviewMenuItem: NSMenuItem {
    private let handler: @MainActor () -> Void

    init(title: String, handler: @escaping @MainActor () -> Void) {
        self.handler = handler
        super.init(title: title, action: #selector(run), keyEquivalent: "")
        target = self
    }

    @available(*, unavailable)
    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    @objc @MainActor private func run() {
        handler()
    }
}

private final class DockPreviewPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class DockPreviewHostingView<Content: View>: NSHostingView<Content> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}

#if DEBUG
@preconcurrency import ScreenCaptureKit

extension DockPreviewController {
    /// Development aid: with `MACMENDER_PREVIEW_SNAPSHOT=<directory>` set, shows a preview shortly
    /// after launch and writes a screenshot of it plus a discovery report to that directory.
    /// `MACMENDER_PREVIEW_APP=<bundle id>` picks the application.
    func runDebugSnapshotIfRequested(
        openSettings: ((SettingsSection) -> Void)? = nil,
        showPopover: (() -> Void)? = nil,
        showSwitcher: (() -> Void)? = nil
    ) {
        let environment = ProcessInfo.processInfo.environment
        guard let path = environment["MACMENDER_PREVIEW_SNAPSHOT"], !path.isEmpty else { return }
        let directory = URL(fileURLWithPath: path, isDirectory: true)
        let preferred = environment["MACMENDER_PREVIEW_APP"]
        switch environment["MACMENDER_PREVIEW_APPEARANCE"] {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: break
        }
        let wantsSettings = environment["MACMENDER_SNAPSHOT_SETTINGS"] != nil

        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard let self else { return }
            var lines = [
                "accessibility=\(AXIsProcessTrusted()) screenRecording=\(CGPreflightScreenCaptureAccess())",
                "privateFocus=\(PrivateWindowAPI.canFocusSingleWindow) privateCapture=\(PrivateWindowAPI.canCaptureWindows) privateSpaces=\(PrivateWindowAPI.canEnumerateAllSpaces)",
                "spaces=\(PrivateWindowAPI.spaceSnapshot())"
            ]
            for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
                let identity = DockAppIdentity(title: app.localizedName ?? "?", bundleIdentifier: app.bundleIdentifier, processIdentifier: app.processIdentifier)
                let start = Date()
                let windows = await self.discoverWindows(for: identity)
                let elapsed = Int(Date().timeIntervalSince(start) * 1000)
                let locator = app.bundleIdentifier.flatMap { self.dockItemLocator?($0) }
                lines.append("app=\(app.bundleIdentifier ?? "?") hidden=\(app.isHidden) windows=\(windows.count) discovery=\(elapsed)ms dockIcon=\(locator.map { "\($0.iconFrame) edge=\($0.edge)" } ?? "none")")
                for window in windows {
                    lines.append("  cg=\(window.windowID.map(String.init) ?? "nil") minimized=\(window.isMinimized) otherSpace=\(window.isOnOtherSpace) fullScreen=\(window.isFullScreen) size=\(Int(window.frame.width))x\(Int(window.frame.height))")
                }
            }

            if environment["MACMENDER_SNAPSHOT_SKIP_PREVIEW"] == nil {
                self.showSamplePreview(preferring: preferred, pinnedFor: 6)
                try? await Task.sleep(for: .milliseconds(1500))
                self.hoveredWindowID = self.presentation?.windows.first?.id
                try? await Task.sleep(for: .milliseconds(400))
                if let presentation = self.presentation, let panel = self.panel {
                    lines.append("presented=\(presentation.identity.bundleIdentifier ?? "?") windows=\(presentation.windows.count) cards=\(presentation.layout.cardFrames.count) hidden=\(presentation.layout.hiddenCount) thumbnailHeight=\(presentation.layout.thumbnailHeight) content=\(presentation.layout.contentSize) panel=\(panel.frame) phase=\(self.phase)")
                    lines.append("thumbnails=\(presentation.windows.filter { self.thumbnails[$0.id] != nil }.count)/\(presentation.windows.count)")
                    if let image = await Self.debugScreenshot(of: panel) {
                        let url = directory.appendingPathComponent("preview.png")
                        if let destination = CGImageDestinationCreateWithURL(url as CFURL, "public.png" as CFString, 1, nil) {
                            CGImageDestinationAddImage(destination, image, nil)
                            lines.append("screenshot=\(CGImageDestinationFinalize(destination))")
                        }
                    } else {
                        lines.append("screenshot=unavailable")
                    }
                } else {
                    lines.append("presented=nothing status=\(self.lastStatus)")
                }
            }
            if wantsSettings, let openSettings {
                self.dismiss(animated: false)
                // `MACMENDER_SNAPSHOT_SETTINGS=all` captures every section; anything else, Dock & Windows.
                let sections = environment["MACMENDER_SNAPSHOT_SETTINGS"] == "all" ? SettingsSection.allCases : [.dockPreviews]
                let size = environment["MACMENDER_SNAPSHOT_SIZE"]?.split(separator: "x").compactMap { Double($0) } ?? []
                for section in sections {
                    openSettings(section)
                    try? await Task.sleep(for: .milliseconds(section == sections.first ? 1800 : 500))
                    guard let window = NSApp.windows.first(where: { $0.isVisible && $0.styleMask.contains(.titled) }),
                          let screen = window.screen ?? NSScreen.main else { continue }
                    let visible = screen.visibleFrame
                    let width = size.count == 2 ? size[0] : 1100
                    let height = size.count == 2 ? min(size[1], visible.height - 80) : visible.height
                    window.setFrame(CGRect(x: visible.minX + 60, y: visible.maxY - height - 40, width: width, height: height), display: true)
                    NSApp.activate(ignoringOtherApps: true)
                    window.orderFrontRegardless()
                    try? await Task.sleep(for: .milliseconds(700))
                    let name = sections.count == 1 ? "settings.png" : "settings-\(section.rawValue).png"
                    if let image = await Self.debugScreenshot(of: window),
                       let destination = CGImageDestinationCreateWithURL(directory.appendingPathComponent(name) as CFURL, "public.png" as CFString, 1, nil) {
                        CGImageDestinationAddImage(destination, image, nil)
                        lines.append("\(name)=\(CGImageDestinationFinalize(destination))")
                    }
                }
            }
            if environment["MACMENDER_SNAPSHOT_SWITCHER"] != nil, let showSwitcher {
                // Set MACMENDER_SWITCHER_APP too, so only sample windows are pictured.
                showSwitcher()
                try? await Task.sleep(for: .milliseconds(1600))
                if let window = NSApp.windows.first(where: { $0.isVisible && $0 !== self.panel && $0.level == .popUpMenu }),
                   let image = await Self.debugScreenshot(of: window),
                   let destination = CGImageDestinationCreateWithURL(directory.appendingPathComponent("switcher.png") as CFURL, "public.png" as CFString, 1, nil) {
                    CGImageDestinationAddImage(destination, image, nil)
                    lines.append("switcher=\(CGImageDestinationFinalize(destination)) size=\(window.frame.size)")
                } else {
                    lines.append("switcher=unavailable")
                }
            }
            if environment["MACMENDER_SNAPSHOT_POPOVER"] != nil, let showPopover {
                showPopover()
                try? await Task.sleep(for: .milliseconds(900))
                if let window = NSApp.windows.first(where: { $0.isVisible && String(describing: type(of: $0)).contains("Popover") }),
                   let image = await Self.debugScreenshot(of: window),
                   let destination = CGImageDestinationCreateWithURL(directory.appendingPathComponent("popover.png") as CFURL, "public.png" as CFString, 1, nil) {
                    CGImageDestinationAddImage(destination, image, nil)
                    lines.append("popover=\(CGImageDestinationFinalize(destination))")
                } else {
                    lines.append("popover=unavailable windows=\(NSApp.windows.filter(\.isVisible).map { String(describing: type(of: $0)) })")
                }
            }
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try? lines.joined(separator: "\n").write(to: directory.appendingPathComponent("report.txt"), atomically: true, encoding: .utf8)
        }
    }

    /// Captures one of this app's own windows and nothing else, so whatever else is on screen
    /// never ends up in a development screenshot.
    /// Captures a window of this app over a plain backdrop. Only this app's windows are included,
    /// so whatever else is on screen never ends up in a development screenshot.
    private static func debugScreenshot(of window: NSWindow) async -> CGImage? {
        let appKitRect = window.frame.insetBy(dx: -40, dy: -40)
        guard let screen = window.screen ?? NSScreen.main,
              let displayID = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else {
            return nil
        }
        let rect = appKitRect.intersection(screen.frame)

        let backdrop = NSWindow(contentRect: rect, styleMask: .borderless, backing: .buffered, defer: false)
        backdrop.level = window.level
        backdrop.ignoresMouseEvents = true
        backdrop.isReleasedWhenClosed = false
        let view = NSView(frame: CGRect(origin: .zero, size: rect.size))
        view.wantsLayer = true
        let gradient = CAGradientLayer()
        gradient.frame = view.bounds
        let isDark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        gradient.colors = isDark
            ? [NSColor(red: 0.10, green: 0.13, blue: 0.30, alpha: 1).cgColor, NSColor(red: 0.33, green: 0.16, blue: 0.45, alpha: 1).cgColor, NSColor(red: 0.75, green: 0.33, blue: 0.36, alpha: 1).cgColor]
            : [NSColor(red: 0.55, green: 0.75, blue: 0.98, alpha: 1).cgColor, NSColor(red: 0.80, green: 0.72, blue: 0.97, alpha: 1).cgColor, NSColor(red: 0.99, green: 0.80, blue: 0.70, alpha: 1).cgColor]
        gradient.startPoint = CGPoint(x: 0, y: 1)
        gradient.endPoint = CGPoint(x: 1, y: 0)
        view.layer?.addSublayer(gradient)
        backdrop.contentView = view
        backdrop.order(.below, relativeTo: window.windowNumber)
        defer { backdrop.close() }
        try? await Task.sleep(for: .milliseconds(400))

        // Looked up after the backdrop is showing: an app with no ordinary window is not listed.
        guard let content = try? await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false),
              let display = content.displays.first(where: { $0.displayID == displayID }),
              let application = content.applications.first(where: { $0.processID == ProcessInfo.processInfo.processIdentifier }) else {
            return nil
        }

        let configuration = SCStreamConfiguration()
        configuration.sourceRect = CGRect(
            x: rect.minX - screen.frame.minX,
            y: screen.frame.maxY - rect.maxY,
            width: rect.width,
            height: rect.height
        )
        configuration.width = Int(rect.width * screen.backingScaleFactor)
        configuration.height = Int(rect.height * screen.backingScaleFactor)
        configuration.showsCursor = false
        // Blur of what is behind a window only exists in the real composite. Capturing that
        // shows whatever is on top of this app's windows too, so it is opt-in and the result
        // must be looked at before it is used anywhere.
        let filter = ProcessInfo.processInfo.environment["MACMENDER_SNAPSHOT_COMPOSITED"] != nil
            ? SCContentFilter(display: display, excludingWindows: [])
            : SCContentFilter(display: display, including: [application], exceptingWindows: [])
        return try? await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
    }
}
#endif
