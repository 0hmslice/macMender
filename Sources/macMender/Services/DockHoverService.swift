import AppKit
import ApplicationServices
import Foundation
import os

/// The Dock application icon or minimized-window tile currently under the pointer.
struct DockHoverTarget: Equatable {
    var identity: DockAppIdentity
    var isRunning: Bool
    /// AppKit screen coordinates.
    var iconFrame: CGRect
    /// The whole Dock's frame in AppKit screen coordinates.
    var dockFrame: CGRect
    var edge: DockEdge
}

/// Reports which Dock application icon the pointer is over.
///
/// The Dock marks the hovered icon as its selected child. An Accessibility observer delivers that
/// change the moment it happens; pointer movement near the Dock's screen edge is a second,
/// throttled trigger in case a notification is missed. Pointer movement elsewhere costs nothing
/// beyond a rectangle test.
@MainActor
final class DockHoverService: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var lastHoveredApp: String?

    /// Called when the hovered item changes; `nil` when the pointer is not on an application icon or minimized window.
    var onHoverChanged: ((DockHoverTarget?) -> Void)?
    /// Called when a mouse button goes down on a Dock application icon.
    var onDockMouseDown: (() -> Void)?

    private(set) var currentTarget: DockHoverTarget?

    private var mouseMonitors = [Any]()
    /// Pointer-movement monitors, installed only while the pointer is at the Dock.
    private var moveMonitors = [Any]()
    private var workspaceObserver: NSObjectProtocol?
    private var dock: DockConnection?
    private var lastConnectionAttempt = Date.distantPast
    private var lastEvaluation = Date.distantPast
    private var settleEvaluation: Task<Void, Never>?
    private var cachedItem: (element: AXUIElement, identity: DockAppIdentity)?
    private var edge = DockEdge.bottom
    private var pressBeganNearDock = false
    private var dragPasteboardChangeCount = 0
    private let evaluationInterval: TimeInterval = 1.0 / 30.0
    /// Tallest Dock (largest magnification) plus room for the pointer to arrive.
    private let edgeBandDepth: CGFloat = 180
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.ryan.macMender", category: "DockHover")

    func start() {
        guard !isRunning else { return }
        isRunning = true
        logger.debug("Dock hover watching started")
        edge = Self.edgeFromDockPreferences()
        connectToDock()

        // Drags are always watched, so a file dragged onto a Dock icon can reach that app's
        // windows. Plain pointer movement is far more frequent and is only followed while the
        // pointer is at the Dock; see `followPointer()`.
        let downMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        mouseMonitors = [
            NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDragged) { [weak self] _ in
                MainActor.assumeIsolated { self?.pointerMoved() }
            },
            NSEvent.addLocalMonitorForEvents(matching: .leftMouseDragged) { [weak self] event in
                MainActor.assumeIsolated { self?.pointerMoved() }
                return event
            },
            NSEvent.addGlobalMonitorForEvents(matching: downMask) { [weak self] _ in
                MainActor.assumeIsolated { self?.mouseDown() }
            },
            NSEvent.addLocalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] event in
                MainActor.assumeIsolated { self?.noteLeftMouseDown() }
                return event
            }
        ].compactMap { $0 }
        if dock?.observesSelection != true {
            // Without the Dock's own notifications, movement is the only signal there is.
            followPointer()
        }

        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.bundleIdentifier == "com.apple.dock" else { return }
            MainActor.assumeIsolated {
                // The Dock restarted; its old Accessibility elements are dead.
                self?.disconnectFromDock()
                self?.connectToDock()
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        mouseMonitors.forEach(NSEvent.removeMonitor)
        mouseMonitors = []
        stopFollowingPointer()
        if let workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(workspaceObserver)
        }
        workspaceObserver = nil
        settleEvaluation?.cancel()
        settleEvaluation = nil
        disconnectFromDock()
        setTarget(nil)
    }

    /// Finds the Dock icon for an application without the pointer being on it.
    func target(forBundleIdentifier bundleIdentifier: String) -> DockHoverTarget? {
        if dock == nil { connectToDock() }
        guard let dock,
              let items = WindowDiscoveryEngine.copyAttribute(kAXChildrenAttribute, from: dock.list) as? [AXUIElement] else {
            return nil
        }
        for item in items {
            guard let target = makeTarget(from: item), target.identity.bundleIdentifier == bundleIdentifier else { continue }
            return target
        }
        return nil
    }

    // MARK: Triggers

    /// Starts watching pointer movement. Watching it all the time would wake the app for every
    /// movement anywhere on screen, so it begins when the Dock reports the pointer on an icon and
    /// ends when the pointer leaves the Dock's edge of the screen.
    private func followPointer() {
        guard moveMonitors.isEmpty else { return }
        moveMonitors = [
            NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
                MainActor.assumeIsolated { self?.pointerMoved() }
            },
            NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
                MainActor.assumeIsolated { self?.pointerMoved() }
                return event
            }
        ].compactMap { $0 }
    }

    private func stopFollowingPointer() {
        moveMonitors.forEach(NSEvent.removeMonitor)
        moveMonitors = []
    }

    private func pointerMoved() {
        guard isRunning else { return }
        guard isNearDockEdge(NSEvent.mouseLocation) else {
            settleEvaluation?.cancel()
            settleEvaluation = nil
            if currentTarget != nil {
                setTarget(nil)
            }
            if dock?.observesSelection == true {
                stopFollowingPointer()
            }
            return
        }

        if Date().timeIntervalSince(lastEvaluation) >= evaluationInterval {
            evaluate()
        }
        // The Dock updates its selection a moment after the pointer arrives, and its icons keep
        // moving while magnification animates. Look again once the pointer has settled.
        settleEvaluation?.cancel()
        settleEvaluation = Task { @MainActor [weak self] in
            for delay in [40, 140, 320] {
                try? await Task.sleep(for: .milliseconds(delay))
                guard let self, !Task.isCancelled, self.isRunning else { return }
                self.evaluate()
            }
        }
    }

    fileprivate func dockSelectionChanged() {
        guard isRunning else { return }
        followPointer()
        evaluate()
    }

    private func mouseDown() {
        guard isRunning else { return }
        noteLeftMouseDown()
        guard currentTarget != nil else { return }
        onDockMouseDown?()
    }

    private func noteLeftMouseDown() {
        pressBeganNearDock = isNearDockEdge(NSEvent.mouseLocation)
        dragPasteboardChangeCount = NSPasteboard(name: .drag).changeCount
    }

    /// A drag-and-drop session that began away from the Dock. Presses that begin on the Dock
    /// rearrange its icons, and other drags (moving a window, selecting text) carry nothing.
    private var isDraggingItemsFromElsewhere: Bool {
        NSEvent.pressedMouseButtons == 1
            && !pressBeganNearDock
            && NSPasteboard(name: .drag).changeCount != dragPasteboardChangeCount
    }

    // MARK: Evaluation

    private func evaluate() {
        lastEvaluation = Date()
        setTarget(hoveredTarget())
    }

    private func hoveredTarget() -> DockHoverTarget? {
        // The Dock also selects icons during keyboard navigation; previews follow the pointer.
        let isDragging = isDraggingItemsFromElsewhere
        guard NSEvent.pressedMouseButtons == 0 || isDragging, isNearDockEdge(NSEvent.mouseLocation) else { return nil }
        if dock == nil { connectToDock() }
        guard let dock else { return nil }

        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(dock.list, kAXSelectedChildrenAttribute as CFString, &value)
        if result == .invalidUIElement || result == .cannotComplete {
            disconnectFromDock()
            return nil
        }
        if result == .success, let item = (value as? [AXUIElement])?.first {
            return makeTarget(from: item)
        }
        // The Dock does not always mark a selection while something is dragged over it.
        return isDragging ? targetUnderPointer(in: dock.list) : nil
    }

    private func targetUnderPointer(in list: AXUIElement) -> DockHoverTarget? {
        guard let primaryHeight = NSScreen.screens.first?.frame.height,
              let items = WindowDiscoveryEngine.copyAttribute(kAXChildrenAttribute, from: list) as? [AXUIElement] else {
            return nil
        }
        let pointer = NSEvent.mouseLocation
        let point = CGPoint(x: pointer.x, y: primaryHeight - pointer.y)
        guard let item = items.first(where: { WindowDiscoveryEngine.frame(of: $0).contains(point) }) else { return nil }
        return makeTarget(from: item)
    }

    private func makeTarget(from item: AXUIElement) -> DockHoverTarget? {
        guard let dock else { return nil }
        let identity: DockAppIdentity
        if let cachedItem, CFEqual(cachedItem.element, item) {
            identity = cachedItem.identity
        } else {
            let subrole = WindowDiscoveryEngine.copyAttribute(kAXSubroleAttribute, from: item) as? String
            let resolved: DockAppIdentity?
            switch subrole {
            case "AXApplicationDockItem": resolved = Self.identity(of: item)
            case "AXMinimizedWindowDockItem": resolved = Self.minimizedWindowIdentity(of: item)
            default: resolved = nil
            }
            guard let resolved else { return nil }
            identity = resolved
            cachedItem = (item, resolved)
        }

        let itemFrame = WindowDiscoveryEngine.frame(of: item)
        guard itemFrame.width > 0, itemFrame.height > 0 else { return nil }
        let listFrame = WindowDiscoveryEngine.frame(of: dock.list)
        edge = Self.edge(of: dock.list, listFrame: listFrame) ?? edge

        // Running state changes while the icon stays the same, so it is never cached.
        let runningApp = identity.bundleIdentifier.flatMap {
            NSRunningApplication.runningApplications(withBundleIdentifier: $0).first { !$0.isTerminated }
        }
        var current = identity
        current.processIdentifier = runningApp?.processIdentifier
        return DockHoverTarget(
            identity: current,
            isRunning: runningApp != nil || identity.isMinimizedWindow,
            iconFrame: Self.appKitFrame(fromAccessibilityFrame: itemFrame),
            dockFrame: Self.appKitFrame(fromAccessibilityFrame: listFrame),
            edge: edge
        )
    }

    private func setTarget(_ target: DockHoverTarget?) {
        let changed = currentTarget?.identity != target?.identity || currentTarget?.isRunning != target?.isRunning
        currentTarget = target
        guard changed else { return }
        let name = target?.identity.displayName
        logger.debug("Dock hover changed onIcon=\(target != nil, privacy: .public) running=\(target?.isRunning ?? false, privacy: .public) app=\(name ?? "none", privacy: .private)")
        if lastHoveredApp != name {
            lastHoveredApp = name
        }
        onHoverChanged?(target)
    }

    private func isNearDockEdge(_ point: CGPoint) -> Bool {
        guard let screen = NSScreen.screens.first(where: { $0.frame.insetBy(dx: -1, dy: -1).contains(point) }) else {
            return false
        }
        switch edge {
        case .bottom: return point.y - screen.frame.minY <= edgeBandDepth
        case .left: return point.x - screen.frame.minX <= edgeBandDepth
        case .right: return screen.frame.maxX - point.x <= edgeBandDepth
        }
    }

    // MARK: Dock connection

    private struct DockConnection {
        var processIdentifier: pid_t
        var list: AXUIElement
        var observer: AXObserver?
        /// Whether the Dock tells us when the icon under the pointer changes.
        var observesSelection: Bool
    }

    private func connectToDock() {
        let now = Date()
        guard dock == nil, now.timeIntervalSince(lastConnectionAttempt) >= 1 else { return }
        lastConnectionAttempt = now

        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else {
            return
        }
        let pid = app.processIdentifier
        let appElement = AXUIElementCreateApplication(pid)
        guard let children = WindowDiscoveryEngine.copyAttribute(kAXChildrenAttribute, from: appElement) as? [AXUIElement],
              let list = children.first(where: {
                  WindowDiscoveryEngine.copyAttribute(kAXRoleAttribute, from: $0) as? String == kAXListRole as String
              }) else {
            return
        }

        var observer: AXObserver?
        var observesSelection = false
        let callback: AXObserverCallback = { _, _, _, context in
            guard let context else { return }
            let service = Unmanaged<DockHoverService>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { service.dockSelectionChanged() }
        }
        if AXObserverCreate(pid, callback, &observer) == .success, let observer {
            let context = Unmanaged.passUnretained(self).toOpaque()
            if AXObserverAddNotification(observer, list, kAXSelectedChildrenChangedNotification as CFString, context) == .success {
                CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
                observesSelection = true
            } else {
                logger.debug("Dock selection observer unavailable; using pointer movement only")
            }
        }
        dock = DockConnection(processIdentifier: pid, list: list, observer: observer, observesSelection: observesSelection)
        if !observesSelection, isRunning {
            followPointer()
        }
        logger.debug("Connected to Dock pid=\(pid, privacy: .public)")
    }

    private func disconnectFromDock() {
        if let observer = dock?.observer {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .commonModes)
        }
        dock = nil
        cachedItem = nil
        lastConnectionAttempt = .distantPast
        if isRunning {
            // Until the Dock is reachable again, movement is the only signal there is.
            followPointer()
        }
    }

    // MARK: Dock item details

    private static func identity(of item: AXUIElement) -> DockAppIdentity? {
        let title = WindowDiscoveryEngine.copyAttribute(kAXTitleAttribute, from: item) as? String ?? ""
        let urlValue = WindowDiscoveryEngine.copyAttribute(kAXURLAttribute, from: item)
        let url = (urlValue as? URL) ?? (urlValue as? String).flatMap(URL.init(string:))
        guard let url, url.isFileURL, let bundleIdentifier = Bundle(url: url)?.bundleIdentifier else {
            return nil
        }
        return DockAppIdentity(title: title, bundleIdentifier: bundleIdentifier, processIdentifier: nil)
    }

    /// A minimized window's Dock tile carries the window's title and nothing about its application.
    private static func minimizedWindowIdentity(of item: AXUIElement) -> DockAppIdentity? {
        guard let title = WindowDiscoveryEngine.copyAttribute(kAXTitleAttribute, from: item) as? String,
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return DockAppIdentity(title: title, bundleIdentifier: nil, processIdentifier: nil, isMinimizedWindow: true)
    }

    private static func edge(of list: AXUIElement, listFrame: CGRect) -> DockEdge? {
        guard let orientation = WindowDiscoveryEngine.copyAttribute(kAXOrientationAttribute, from: list) as? String else {
            return nil
        }
        if orientation == kAXHorizontalOrientationValue as String {
            return .bottom
        }
        let frame = appKitFrame(fromAccessibilityFrame: listFrame)
        let center = CGPoint(x: frame.midX, y: frame.midY)
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(center) }) ?? NSScreen.screens.first else {
            return nil
        }
        return frame.midX < screen.frame.midX ? .left : .right
    }

    private static func edgeFromDockPreferences() -> DockEdge {
        let orientation = UserDefaults(suiteName: "com.apple.dock")?.string(forKey: "orientation")
        return orientation.flatMap(DockEdge.init(rawValue:)) ?? .bottom
    }

    /// Accessibility frames have their origin at the top left of the primary display.
    private static func appKitFrame(fromAccessibilityFrame frame: CGRect) -> CGRect {
        guard let primaryHeight = NSScreen.screens.first?.frame.height else { return frame }
        return CGRect(x: frame.minX, y: primaryHeight - frame.maxY, width: frame.width, height: frame.height)
    }
}
