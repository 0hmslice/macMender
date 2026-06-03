import AppKit
import os
import QuartzCore
import SwiftUI

@MainActor
final class WindowSwitcherService: ObservableObject {
    @Published private(set) var isShowing = false
    @Published private(set) var windows: [WindowSummary] = []
    @Published private(set) var selectedIndex = 0
    @Published private(set) var presentationStatus = "Ready to scan"
    @Published private(set) var overlayTitle = "Window Switcher"
    @Published private(set) var overlaySubtitle = ""
    @Published private(set) var displayThumbnailSize = 160.0
    @Published private(set) var gridColumnCount = 3
    @Published private(set) var isDockPreview = false
    @Published private(set) var lastActivationDiagnostic = "No window activation attempted"
    @Published private(set) var lastDiscoveryReport = WindowDiscoveryReport.empty
    @Published private(set) var hasRunWindowDiscovery = false
    @Published private(set) var lastThumbnailDiagnostic = "No thumbnail batch yet"
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
    private var dockPreviewAnimationStyle = DockPreviewSettings.default.animationStyle
    private var dockPreviewAnimationDurationValue = DockPreviewSettings.default.animationDuration
    private var panelAnimationGeneration = 0
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

    func show(settings: WindowSwitcherSettings) {
        let discovered = catalog.visibleWindows()
            .filter { settings.includeMinimizedWindows || !$0.isMinimized }
            .filter { settings.includeHiddenApps || !(NSRunningApplication(processIdentifier: $0.processIdentifier)?.isHidden ?? false) }
        lastDiscoveryReport = catalog.lastDiscoveryReport
        hasRunWindowDiscovery = true

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
            panel?.orderFrontRegardless()
            prefetchThumbnails()
        }
    }

    func refreshDiscovery(settings: WindowSwitcherSettings) {
        let discovered = catalog.visibleWindows()
            .filter { settings.includeMinimizedWindows || !$0.isMinimized }
            .filter { settings.includeHiddenApps || !(NSRunningApplication(processIdentifier: $0.processIdentifier)?.isHidden ?? false) }
        lastDiscoveryReport = catalog.lastDiscoveryReport
        hasRunWindowDiscovery = true
        presentationStatus = discovered.isEmpty ? "No switchable windows detected" : "\(discovered.count) windows available"
    }

    func showDockPreview(identity: DockAppIdentity, settings: WindowSwitcherSettings, anchorFrame: CGRect) {
        guard identity.hasResolvedApplicationIdentity else {
            presentationStatus = "Dock preview skipped for unresolved Dock item \(identity.displayName)"
            logger.debug("Dock preview suppressed unresolved title=\(identity.displayName, privacy: .public)")
            cancel()
            return
        }

        let discovered = catalog.dockPreviewWindows(for: identity)
            .filter { settings.includeMinimizedWindows || !$0.isMinimized }
            .filter { settings.includeHiddenApps || !(NSRunningApplication(processIdentifier: $0.processIdentifier)?.isHidden ?? false) }
        lastDiscoveryReport = catalog.lastDiscoveryReport

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
            presentPanel()
            prefetchThumbnails()
            startDockPreviewMouseTracking()
        }
    }

    func showDockPreviewForMostRecentApp(settings: WindowSwitcherSettings, anchorFrame: CGRect) {
        guard let window = catalog.visibleWindows().first else {
            lastDiscoveryReport = catalog.lastDiscoveryReport
            presentationStatus = "No windows available for preview"
            return
        }
        lastDiscoveryReport = catalog.lastDiscoveryReport
        showDockPreview(
            identity: DockAppIdentity(
                title: window.appName,
                bundleIdentifier: window.bundleIdentifier,
                processIdentifier: window.processIdentifier
            ),
            settings: settings,
            anchorFrame: anchorFrame
        )
    }

    func showDockPreviewAnimationSample(settings: WindowSwitcherSettings, anchorFrame: CGRect) {
        thumbnailTask?.cancel()
        thumbnailTask = nil
        thumbnails = [:]
        windows = [
            WindowSummary(
                id: "macmender-animation-sample",
                windowID: nil,
                appName: "Animation Test",
                bundleIdentifier: Bundle.main.bundleIdentifier,
                title: "\(effectiveDockPreviewAnimationStyle.title) preview",
                processIdentifier: NSRunningApplication.current.processIdentifier,
                frame: anchorFrame,
                isMinimized: false,
                stackIndex: 0,
                axElement: nil
            )
        ]
        selectedIndex = 0
        isShowing = true
        isDockPreview = true
        overlayTitle = "Animation Test"
        overlaySubtitle = "\(effectiveDockPreviewAnimationStyle.title) • \(dockPreviewAnimationDuration.formatted(.number.precision(.fractionLength(2))))s"
        presentationStatus = "Previewing \(effectiveDockPreviewAnimationStyle.title)"
        lastThumbnailDiagnostic = "animation sample uses local placeholder; capture not requested"
        dockPreviewAnchorFrame = anchorFrame
        if presentsPanel {
            ensurePanel(settings: settings, anchorFrame: anchorFrame)
            presentPanel()
            scheduleAnimationSampleDismiss()
        }
    }

    func cycle() {
        guard !windows.isEmpty else { return }
        selectedIndex = (selectedIndex + 1) % windows.count
        logger.debug("Selected window index=\(self.selectedIndex, privacy: .public) source=keyboard")
    }

    func cancel() {
        let shouldAnimateDockDismiss = isDockPreview && (panel?.isVisible == true)
        let wasAnimationSample = overlayTitle == "Animation Test"
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
        if shouldAnimateDockDismiss {
            dismissPanel()
        } else {
            panel?.orderOut(nil)
        }
        if wasAnimationSample {
            presentationStatus = "Ready to scan"
            lastThumbnailDiagnostic = "animation sample dismissed; capture not requested"
        }
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

    func updateDockPreviewAnimation(style: DockPreviewAnimationStyle, duration: Double) {
        dockPreviewAnimationStyle = style.legacyMappedStyle
        dockPreviewAnimationDurationValue = DockPreviewSettings.clampedAnimationDuration(duration)
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

    private func scheduleAnimationSampleDismiss() {
        dockPreviewDismissTask?.cancel()
        dockPreviewDismissTask = Task { @MainActor [weak self] in
            let duration = self?.dockPreviewAnimationDuration ?? DockPreviewSettings.default.animationDuration
            let delay = max(850, Int((duration + 0.72) * 1000))
            try? await Task.sleep(for: .milliseconds(delay))
            guard let self, !Task.isCancelled, self.overlayTitle == "Animation Test" else { return }
            self.cancel()
        }
    }

    private func refreshKeepingSelection() {
        let selectedID = selectedWindow?.id
        windows = catalog.visibleWindows()
        lastDiscoveryReport = catalog.lastDiscoveryReport
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
            for window in missingWindows {
                if let image = captured[window.id] {
                    self.insertThumbnailCache(image, for: window.id)
                    self.thumbnails[window.id] = image
                }
            }
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

    private func presentPanel() {
        guard let panel else { return }
        panelAnimationGeneration += 1
        let generation = panelAnimationGeneration
        let style = effectiveDockPreviewAnimationStyle
        let finalFrame = panel.frame

        resetPanelHighlight()
        panel.alphaValue = 1
        panel.setFrame(finalFrame, display: false)
        let layer = preparePanelAnimationLayer()
        let startState = layerState(for: style, appearing: true)
        setLayerState(startState, on: layer)
        panel.orderFrontRegardless()

        guard style != .none else {
            setLayerState(.identity, on: layer)
            return
        }
        animateLayer(
            layer,
            from: startState,
            to: .identity,
            duration: dockPreviewAnimationDuration,
            timingFunction: timingFunction(for: style, appearing: true),
            key: "macmender.preview.appear"
        ) { [weak self] in
            guard let self, self.panelAnimationGeneration == generation else { return }
            self.setLayerState(.identity, on: layer)
        }
    }

    private func presentGlassPop(layer: CALayer, generation: Int) {
        applyPanelHighlight()
        let start = layerState(for: .glassPop, appearing: true)
        let overshoot = PanelLayerState(
            opacity: 1,
            transform: CATransform3DMakeScale(1.055, 1.055, 1)
        )
        animateLayerKeyframes(
            layer,
            transforms: [start.transform, overshoot.transform, PanelLayerState.identity.transform],
            opacities: [start.opacity, 1, 1],
            keyTimes: [0, 0.58, 1],
            duration: dockPreviewAnimationDuration,
            timingFunction: CAMediaTimingFunction(controlPoints: 0.08, 0.82, 0.16, 1.0),
            key: "macmender.preview.glassPop"
        ) { [weak self] in
            guard let self, self.panelAnimationGeneration == generation else { return }
            self.setLayerState(.identity, on: layer)
            self.fadePanelHighlight()
        }
    }

    private func presentGenie(layer: CALayer, from start: PanelLayerState, generation: Int) {
        let stretch = PanelLayerState(
            opacity: 1,
            transform: transformed(scaleX: 1.035, scaleY: 1.015, y: -5)
        )
        animateLayerKeyframes(
            layer,
            transforms: [start.transform, stretch.transform, PanelLayerState.identity.transform],
            opacities: [start.opacity, 1, 1],
            keyTimes: [0, 0.72, 1],
            duration: dockPreviewAnimationDuration,
            timingFunction: timingFunction(for: .genie, appearing: true),
            key: "macmender.preview.genie"
        ) { [weak self] in
            guard let self, self.panelAnimationGeneration == generation else { return }
            self.setLayerState(.identity, on: layer)
        }
    }

    private func dismissPanel() {
        guard let panel else { return }
        panelAnimationGeneration += 1
        let generation = panelAnimationGeneration
        let style = effectiveDockPreviewAnimationStyle
        let layer = preparePanelAnimationLayer()
        let targetState = layerState(for: style, appearing: false)

        guard style != .none else {
            panel.alphaValue = 1
            setLayerState(.identity, on: layer)
            panel.orderOut(nil)
            return
        }

        animateLayer(
            layer,
            from: .identity,
            to: targetState,
            duration: dockPreviewDismissDuration,
            timingFunction: timingFunction(for: style, appearing: false),
            key: "macmender.preview.dismiss"
        ) { [weak self, weak panel] in
            guard let self, self.panelAnimationGeneration == generation else { return }
            panel?.orderOut(nil)
            panel?.alphaValue = 1
            self.setLayerState(.identity, on: layer)
            self.resetPanelHighlight()
        }
    }

    private func preparePanelAnimationLayer() -> CALayer {
        guard let contentView = panel?.contentView else {
            return CALayer()
        }
        contentView.wantsLayer = true
        let layer = contentView.layer ?? CALayer()
        layer.removeAllAnimations()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        layer.bounds = contentView.bounds
        layer.position = CGPoint(x: contentView.bounds.midX, y: contentView.bounds.midY)
        layer.opacity = 1
        layer.transform = CATransform3DIdentity
        layer.masksToBounds = false
        CATransaction.commit()
        return layer
    }

    private func setLayerState(_ state: PanelLayerState, on layer: CALayer) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.opacity = state.opacity
        layer.transform = state.transform
        CATransaction.commit()
    }

    private func animateLayer(
        _ layer: CALayer,
        from start: PanelLayerState,
        to end: PanelLayerState,
        duration: TimeInterval,
        timingFunction: CAMediaTimingFunction,
        key: String,
        completion: @escaping @MainActor () -> Void
    ) {
        setLayerState(end, on: layer)

        let transform = CABasicAnimation(keyPath: "transform")
        transform.fromValue = start.transform
        transform.toValue = end.transform

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = start.opacity
        opacity.toValue = end.opacity

        let group = CAAnimationGroup()
        group.animations = [transform, opacity]
        group.duration = duration
        group.timingFunction = timingFunction
        group.isRemovedOnCompletion = true
        layer.add(group, forKey: key)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(max(duration, 0) * 1000)))
            completion()
        }
    }

    private func animateLayerKeyframes(
        _ layer: CALayer,
        transforms: [CATransform3D],
        opacities: [Float],
        keyTimes: [NSNumber],
        duration: TimeInterval,
        timingFunction: CAMediaTimingFunction,
        key: String,
        completion: @escaping @MainActor () -> Void
    ) {
        setLayerState(.identity, on: layer)

        let transform = CAKeyframeAnimation(keyPath: "transform")
        transform.values = transforms
        transform.keyTimes = keyTimes

        let opacity = CAKeyframeAnimation(keyPath: "opacity")
        opacity.values = opacities
        opacity.keyTimes = keyTimes

        let group = CAAnimationGroup()
        group.animations = [transform, opacity]
        group.duration = duration
        group.timingFunction = timingFunction
        group.isRemovedOnCompletion = true
        layer.add(group, forKey: key)

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(Int(max(duration, 0) * 1000)))
            completion()
        }
    }

    private func layerState(for style: DockPreviewAnimationStyle, appearing: Bool) -> PanelLayerState {
        switch style {
        case .none:
            return .identity
        case .fade:
            return PanelLayerState(opacity: 0, transform: PanelLayerState.identity.transform)
        case .system:
            return PanelLayerState(opacity: 0, transform: transformed(scaleX: appearing ? 0.965 : 0.975, scaleY: appearing ? 0.965 : 0.975, y: dockOriginYOffset(magnitude: appearing ? 14 : 10)))
        case .scale:
            return PanelLayerState(opacity: 0, transform: transformed(scaleX: appearing ? 0.82 : 0.88, scaleY: appearing ? 0.82 : 0.88, y: 0))
        case .slideUp:
            return PanelLayerState(opacity: 0, transform: transformed(scaleX: 1, scaleY: 1, y: dockOriginYOffset(magnitude: appearing ? 72 : 58)))
        case .glassPop:
            return layerState(for: .system, appearing: appearing)
        case .genie:
            return layerState(for: .scale, appearing: appearing)
        }
    }

    private func transformed(scaleX: CGFloat, scaleY: CGFloat, y: CGFloat) -> CATransform3D {
        CATransform3DConcat(
            CATransform3DMakeScale(scaleX, scaleY, 1),
            CATransform3DMakeTranslation(0, y, 0)
        )
    }

    private func dockOriginYOffset(magnitude: CGFloat) -> CGFloat {
        guard let panel, let dockPreviewAnchorFrame else {
            return -magnitude
        }
        return panel.frame.midY >= dockPreviewAnchorFrame.midY ? -magnitude : magnitude
    }

    private var effectiveDockPreviewAnimationStyle: DockPreviewAnimationStyle {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            dockPreviewAnimationStyle.legacyMappedStyle == .none ? .none : .fade
        } else {
            dockPreviewAnimationStyle.legacyMappedStyle
        }
    }

    private var dockPreviewAnimationDuration: TimeInterval {
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            return min(dockPreviewAnimationDurationValue, 0.12)
        }
        return dockPreviewAnimationDurationValue
    }

    private var dockPreviewDismissDuration: TimeInterval {
        switch effectiveDockPreviewAnimationStyle {
        case .none:
            0
        case .fade:
            max(dockPreviewAnimationDuration * 0.72, 0.05)
        case .system:
            max(dockPreviewAnimationDuration * 0.70, 0.05)
        case .scale, .slideUp:
            max(dockPreviewAnimationDuration * 0.76, 0.06)
        case .glassPop:
            max(dockPreviewAnimationDuration * 0.62, 0.06)
        case .genie:
            max(dockPreviewAnimationDuration * 0.82, 0.07)
        }
    }

    private func timingFunction(for style: DockPreviewAnimationStyle, appearing: Bool) -> CAMediaTimingFunction {
        switch style {
        case .none:
            CAMediaTimingFunction(name: .linear)
        case .fade:
            CAMediaTimingFunction(name: appearing ? .easeOut : .easeIn)
        case .system:
            CAMediaTimingFunction(controlPoints: 0.21, 0.62, 0.20, 1.0)
        case .scale:
            CAMediaTimingFunction(controlPoints: 0.10, 0.82, 0.20, 1.0)
        case .slideUp:
            CAMediaTimingFunction(controlPoints: 0.12, 0.86, 0.16, 1.0)
        case .glassPop:
            CAMediaTimingFunction(name: appearing ? .easeOut : .easeIn)
        case .genie:
            appearing
                ? CAMediaTimingFunction(controlPoints: 0.08, 0.80, 0.16, 1.12)
                : CAMediaTimingFunction(controlPoints: 0.34, 0.02, 0.78, 0.42)
        }
    }

    private func applyPanelHighlight() {
        guard let contentView = panel?.contentView else { return }
        contentView.wantsLayer = true
        guard let layer = contentView.layer else { return }
        layer.cornerRadius = LiquidGlassSurface.preview.radius
        layer.masksToBounds = false
        layer.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.82).cgColor
        layer.borderWidth = 2.4
        layer.shadowColor = NSColor.controlAccentColor.withAlphaComponent(0.78).cgColor
        layer.shadowOpacity = 0.58
        layer.shadowRadius = 34
        layer.shadowOffset = CGSize(width: 0, height: 0)
    }

    private func fadePanelHighlight() {
        guard let layer = panel?.contentView?.layer else { return }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = 0.14
        fade.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(fade, forKey: "macmender.glassPopHighlightFade")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
            layer.borderWidth = 0
            layer.shadowOpacity = 0
            layer.opacity = 1
        }
    }

    private func resetPanelHighlight() {
        guard let layer = panel?.contentView?.layer else { return }
        layer.borderWidth = 0
        layer.shadowOpacity = 0
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

private struct ThumbnailCacheEntry {
    var image: NSImage
    var createdAt: Date
}

private struct PanelLayerState {
    var opacity: Float
    var transform: CATransform3D

    static let identity = PanelLayerState(opacity: 1, transform: CATransform3DIdentity)
}
