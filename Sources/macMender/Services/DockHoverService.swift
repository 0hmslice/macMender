import AppKit
import ApplicationServices
import Foundation
import os

@MainActor
final class DockHoverService: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var lastHoveredApp: String?
    @Published private(set) var lastDiagnostic = "Dock previews idle"

    var hoverDelay: TimeInterval = 0.35
    var onHoverApp: ((DockAppIdentity, CGRect) -> Void)?
    var onExitDock: (() -> Void)?
    var onContextMenuInteraction: (() -> Void)?

    private var globalMouseMonitor: Any?
    private var localMouseMonitor: Any?
    private var fallbackTimer: Timer?
    private var hoverTask: Task<Void, Never>?
    private var hoverStart: Date?
    private var pendingApp: DockAppIdentity?
    private var displayedApp: DockAppIdentity?
    private var suppressHoverUntil: Date?
    private var lastInsideDockAt: Date?
    private var cachedDockItems: [DockItem] = []
    private var lastDockItemRefresh: Date?
    private var lastDiagnosticMessage = "Dock previews idle"
    private var lastDiagnosticAt: Date?
    private let exitGrace: TimeInterval = 0.22
    private let dockItemCacheDuration: TimeInterval = 30
    private let fallbackPollInterval: TimeInterval = 1.25
    private let diagnosticPublishInterval: TimeInterval = 1.25
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.ryan.macMender", category: "DockHover")

    func start() {
        guard globalMouseMonitor == nil, localMouseMonitor == nil else { return }

        let mask: NSEvent.EventTypeMask = [
            .mouseMoved,
            .leftMouseDragged,
            .rightMouseDragged,
            .otherMouseDragged,
            .leftMouseDown,
            .rightMouseDown,
            .otherMouseDown
        ]
        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleMonitoredEvent(event)
            }
        }
        localMouseMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            Task { @MainActor [weak self] in
                self?.handleMonitoredEvent(event)
            }
            return event
        }
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: fallbackPollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pollFallback()
            }
        }

        setRunning(true)
        refreshDockItems(force: true)
    }

    func stop() {
        if let globalMouseMonitor {
            NSEvent.removeMonitor(globalMouseMonitor)
        }
        if let localMouseMonitor {
            NSEvent.removeMonitor(localMouseMonitor)
        }
        fallbackTimer?.invalidate()
        globalMouseMonitor = nil
        localMouseMonitor = nil
        fallbackTimer = nil
        setRunning(false)
        setLastHoveredApp(nil)
        hoverStart = nil
        pendingApp = nil
        displayedApp = nil
        hoverTask?.cancel()
        hoverTask = nil
        suppressHoverUntil = nil
        cachedDockItems = []
        lastDockItemRefresh = nil
        onExitDock?()
    }

    private func poll(allowNewHover: Bool = true) {
        guard let item = dockItemUnderMouse() else {
            suppressHoverUntil = nil
            clearPendingHover()
            if let lastInsideDockAt, Date().timeIntervalSince(lastInsideDockAt) < exitGrace {
                return
            }
            if displayedApp != nil {
                displayedApp = nil
                onExitDock?()
            }
            return
        }

        lastInsideDockAt = Date()
        setLastHoveredApp(item.identity.displayName)
        guard !isHoverSuppressed() else {
            clearPendingHover()
            displayedApp = nil
            return
        }
        guard allowNewHover || pendingApp != nil || displayedApp != nil else {
            return
        }
        if pendingApp != item.identity {
            pendingApp = item.identity
            hoverStart = Date()
            schedulePreview(for: item)
            return
        }

        guard displayedApp != item.identity,
              let hoverStart,
              Date().timeIntervalSince(hoverStart) >= hoverDelay else {
            return
        }

        displayedApp = item.identity
        onHoverApp?(item.identity, item.anchorFrame)
    }

    private func pollFallback() {
        guard pendingApp != nil || displayedApp != nil || lastInsideDockAt != nil else {
            return
        }
        poll(allowNewHover: false)
    }

    private func schedulePreview(for item: DockItem) {
        hoverTask?.cancel()
        hoverTask = Task { @MainActor [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(Int(self.hoverDelay * 1000)))
            guard !Task.isCancelled,
                  !self.isHoverSuppressed(),
                  self.pendingApp == item.identity,
                  self.displayedApp != item.identity,
                  let current = self.dockItemUnderMouse(),
                  current.identity == item.identity else {
                return
            }

            self.displayedApp = item.identity
            self.onHoverApp?(item.identity, current.anchorFrame)
        }
    }

    private func handleMonitoredEvent(_ event: NSEvent) {
        if handleContextMenuTriggerIfNeeded(event) {
            return
        }

        switch event.type {
        case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
            poll()
        default:
            break
        }
    }

    private func handleContextMenuTriggerIfNeeded(_ event: NSEvent) -> Bool {
        guard DockPreviewContextMenuInteraction.isTrigger(eventType: event.type, modifierFlags: event.modifierFlags),
              dockItemUnderMouse() != nil else {
            return false
        }

        suppressHoverUntil = Date().addingTimeInterval(DockPreviewContextMenuInteraction.suppressionDuration)
        clearPendingHover()
        displayedApp = nil
        onContextMenuInteraction?()
        return true
    }

    private func isHoverSuppressed(now: Date = Date()) -> Bool {
        guard let suppressHoverUntil else { return false }
        guard suppressHoverUntil > now else {
            self.suppressHoverUntil = nil
            return false
        }
        return true
    }

    private func dockItemUnderMouse() -> DockItem? {
        guard let mouse = CGEvent(source: nil)?.location else { return nil }
        guard let dockList = visibleDockList() else {
            cachedDockItems = []
            lastDockItemRefresh = nil
            recordDiagnostic("suppressed: Dock list unavailable mouse=\(mouse.debugDescription)")
            return nil
        }

        if let selectedItem = selectedDockItem(in: dockList),
           let item = dockItem(from: selectedItem),
           item.identity.hasResolvedApplicationIdentity,
           item.hitFrame.contains(mouse) {
            recordDiagnostic("selected Dock item title=\(item.identity.displayName) frame=\(item.hitFrame.debugDescription) bundle=\(item.identity.bundleIdentifier ?? "nil") pid=\(item.identity.processIdentifier.map(String.init) ?? "nil")")
            return item
        }

        refreshDockItemsIfNeeded(near: mouse)
        let candidates = cachedDockItems.filter {
            $0.identity.hasResolvedApplicationIdentity &&
                !$0.identity.displayName.isEmpty &&
                $0.hitFrame.contains(mouse)
        }
        guard !candidates.isEmpty else {
            recordDiagnostic("suppressed: no resolved Dock item under mouse=\(mouse.debugDescription)")
            return nil
        }
        guard candidates.count == 1, let item = candidates.first else {
            let titles = candidates.map(\.identity.displayName).joined(separator: ", ")
            recordDiagnostic("suppressed: ambiguous Dock hit mouse=\(mouse.debugDescription) candidates=\(titles)")
            return nil
        }
        recordDiagnostic("frame Dock item title=\(item.identity.displayName) frame=\(item.hitFrame.debugDescription) bundle=\(item.identity.bundleIdentifier ?? "nil") pid=\(item.identity.processIdentifier.map(String.init) ?? "nil")")
        return item
    }

    private func recordDiagnostic(_ message: String) {
        let now = Date()
        let messageChanged = message != lastDiagnosticMessage
        let shouldPublish = messageChanged ||
            lastDiagnosticAt.map { now.timeIntervalSince($0) >= diagnosticPublishInterval } ?? true
        guard shouldPublish else { return }
        lastDiagnosticMessage = message
        lastDiagnosticAt = now
        lastDiagnostic = message
        logger.debug("\(message, privacy: .private)")
    }

    private func refreshDockItems(force: Bool) {
        guard force || shouldRefreshDockItems(near: nil) else {
            return
        }
        cachedDockItems = loadDockItems()
        lastDockItemRefresh = Date()
    }

    private func refreshDockItemsIfNeeded(near mouse: CGPoint) {
        if cachedDockItems.isEmpty {
            refreshDockItems(force: true)
            return
        }
        guard shouldRefreshDockItems(near: mouse) else { return }
        refreshDockItems(force: true)
    }

    private func shouldRefreshDockItems(near mouse: CGPoint?) -> Bool {
        guard let lastDockItemRefresh else { return true }
        guard Date().timeIntervalSince(lastDockItemRefresh) >= dockItemCacheDuration else { return false }
        guard let mouse else { return true }
        return cachedDockItems
            .map(\.hitFrame)
            .reduce(CGRect.null) { $0.union($1) }
            .insetBy(dx: -180, dy: -140)
            .contains(mouse)
    }

    private func clearPendingHover() {
        setLastHoveredApp(nil)
        if pendingApp != nil {
            pendingApp = nil
        }
        if hoverStart != nil {
            hoverStart = nil
        }
        if hoverTask != nil {
            hoverTask?.cancel()
            hoverTask = nil
        }
    }

    private func setRunning(_ value: Bool) {
        if isRunning != value {
            isRunning = value
        }
    }

    private func setLastHoveredApp(_ value: String?) {
        if lastHoveredApp != value {
            lastHoveredApp = value
        }
    }

    private func loadDockItems() -> [DockItem] {
        guard let list = visibleDockList() else {
            return []
        }

        var itemValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(list, kAXChildrenAttribute as CFString, &itemValue) == .success,
              let elements = itemValue as? [AXUIElement] else {
            return []
        }

        return elements.compactMap(dockItem(from:))
    }

    private func identity(for element: AXUIElement, title: String) -> DockAppIdentity {
        if let bundleIdentifier = bundleIdentifierFromDockURL(element) {
            let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first
            return DockAppIdentity(
                title: runningApp?.localizedName ?? title,
                bundleIdentifier: bundleIdentifier,
                processIdentifier: runningApp?.processIdentifier
            )
        }

        return DockAppIdentity(
            title: title,
            bundleIdentifier: nil,
            processIdentifier: nil
        )
    }

    private func dockItem(from element: AXUIElement) -> DockItem? {
        var roleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleValue)
        guard (roleValue as? String) == "AXDockItem" else { return nil }

        var titleValue: CFTypeRef?
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &titleValue)
        AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue)
        AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue)

        guard let title = titleValue as? String,
              let positionValue,
              let sizeValue else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        let hitFrame = quartzFrame(fromAccessibilityPosition: position, size: size)
        return DockItem(
            identity: identity(for: element, title: title),
            hitFrame: hitFrame,
            anchorFrame: appKitFrame(fromQuartzFrame: hitFrame)
        )
    }

    private func bundleIdentifierFromDockURL(_ element: AXUIElement) -> String? {
        var urlValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXURLAttribute as CFString, &urlValue) == .success else {
            return nil
        }
        let url: URL?
        if let value = urlValue as? URL {
            url = value
        } else if let value = urlValue as? String {
            url = URL(string: value)
        } else {
            url = nil
        }
        guard let url, url.isFileURL, let bundle = Bundle(url: url) else {
            return nil
        }
        return bundle.bundleIdentifier
    }

    private func isDockCurrentlyVisible() -> Bool {
        visibleDockList() != nil
    }

    private func visibleDockList() -> AXUIElement? {
        guard let dock = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return nil
        }

        let dockElement = AXUIElementCreateApplication(dock.processIdentifier)
        var childrenValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(dockElement, kAXChildrenAttribute as CFString, &childrenValue) == .success,
              let children = childrenValue as? [AXUIElement],
              let list = children.first else {
            return nil
        }

        return isDockListVisible(list) ? list : nil
    }

    private func selectedDockItem(in list: AXUIElement) -> AXUIElement? {
        var selectedChildren: CFTypeRef?
        guard AXUIElementCopyAttributeValue(list, kAXSelectedChildrenAttribute as CFString, &selectedChildren) == .success,
              let selected = selectedChildren as? [AXUIElement],
              let hoveredItem = selected.first else {
            return nil
        }
        return hoveredItem
    }

    private func isDockListVisible(_ list: AXUIElement) -> Bool {
        let frame = rawFrame(for: list)
        guard frame.width > 0, frame.height > 0 else { return false }

        return NSScreen.screens.contains { screen in
            let intersection = frame.intersection(screen.frame)
            let visibleArea = intersection.width * intersection.height
            let totalArea = frame.width * frame.height
            return visibleArea >= totalArea * 0.55
        }
    }

    private func rawFrame(for element: AXUIElement) -> CGRect {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(element, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue,
              let sizeValue else {
            return .zero
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: position, size: size)
    }

    private func quartzFrame(fromAccessibilityPosition position: CGPoint, size: CGSize) -> CGRect {
        let screen = NSScreen.screens.first { screen in
            position.x >= screen.frame.minX &&
                position.x <= screen.frame.maxX &&
                position.y >= screen.frame.minY &&
                position.y <= screen.frame.maxY
        } ?? NSScreen.main

        guard let screen else {
            return CGRect(origin: position, size: size)
        }

        var origin = position
        if position.y >= screen.frame.maxY - 1 {
            origin.y = screen.frame.maxY - size.height
        }
        if position.x >= screen.frame.maxX - 1 {
            origin.x = screen.frame.maxX - size.width
        }

        return CGRect(origin: origin, size: size)
    }

    private func appKitFrame(fromQuartzFrame frame: CGRect) -> CGRect {
        let screen = NSScreen.screens.first { screen in
            frame.midX >= screen.frame.minX &&
                frame.midX <= screen.frame.maxX &&
                frame.midY >= screen.frame.minY &&
                frame.midY <= screen.frame.maxY
        } ?? NSScreen.main

        guard let screen else {
            return frame
        }

        return CGRect(
            x: frame.minX,
            y: screen.frame.maxY - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }
}

private struct DockItem {
    var identity: DockAppIdentity
    var hitFrame: CGRect
    var anchorFrame: CGRect
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}
