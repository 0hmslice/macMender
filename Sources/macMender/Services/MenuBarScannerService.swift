import AppKit
import ApplicationServices
@preconcurrency import CoreGraphics
import Foundation

// Portions of this file are adapted from Ice for macOS (GPL-3.0).
// Source: https://github.com/jordanbaird/Ice
// Ice revision used during the port: 11edd39115f3f43a83ae114b5348df6a0e1741cf.

private extension CGEventFilterMask {
    static let macMenderPermitAllEvents: CGEventFilterMask = [
        .permitLocalMouseEvents,
        .permitLocalKeyboardEvents,
        .permitSystemDefinedEvents
    ]
}

private final class ContinuationGate: @unchecked Sendable {
    private let lock = NSLock()
    private var hasEntered = false

    func tryEnter() -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard !hasEntered else { return false }
        hasEntered = true
        return true
    }
}

private struct MacMenderMenuBarItemInfo: Hashable, CustomStringConvertible {
    struct Namespace: Hashable, RawRepresentable, CustomStringConvertible {
        var rawValue: String
        var description: String { rawValue }

        init(rawValue: String) {
            self.rawValue = rawValue
        }

        init(_ value: String?) {
            self.rawValue = value ?? "<null>"
        }
    }

    var namespace: Namespace
    var title: String

    var description: String {
        "\(namespace.rawValue):\(title)"
    }

    static let visibleControlItem = MacMenderMenuBarItemInfo(namespace: .macMenderApp, title: "SItem")
    static let hiddenControlItem = MacMenderMenuBarItemInfo(namespace: .macMenderApp, title: "HItem")
    static let alwaysHiddenControlItem = MacMenderMenuBarItemInfo(namespace: .macMenderApp, title: "AHItem")
    static let clock = MacMenderMenuBarItemInfo(namespace: .controlCenter, title: "Clock")
    static let siri = MacMenderMenuBarItemInfo(namespace: .systemUIServer, title: "Siri")
    static let controlCenterItem = MacMenderMenuBarItemInfo(namespace: .controlCenter, title: "BentoBox")
    static let audioVideoModule = MacMenderMenuBarItemInfo(namespace: .controlCenter, title: "AudioVideoModule")
    static let faceTime = MacMenderMenuBarItemInfo(namespace: .controlCenter, title: "FaceTime")
    static let musicRecognition = MacMenderMenuBarItemInfo(namespace: .controlCenter, title: "MusicRecognition")

    static let immovableItems: Set<MacMenderMenuBarItemInfo> = [
        .clock,
        .siri,
        .controlCenterItem
    ]

    static let nonHideableItems: Set<MacMenderMenuBarItemInfo> = [
        .audioVideoModule,
        .faceTime,
        .musicRecognition
    ]
}

private extension MacMenderMenuBarItemInfo.Namespace {
    static let macMenderApp = Self(Bundle.main.bundleIdentifier ?? "com.ryan.macMender")
    static let controlCenter = Self("com.apple.controlcenter")
    static let systemUIServer = Self("com.apple.systemuiserver")
}

private struct MacMenderWindowInfo: Hashable {
    var windowID: CGWindowID
    var frame: CGRect
    var title: String?
    var layer: Int
    var ownerPID: pid_t
    var ownerName: String?
    var isOnScreen: Bool

    var owningApplication: NSRunningApplication? {
        NSRunningApplication(processIdentifier: ownerPID)
    }

    var isMenuBarItem: Bool {
        layer == kCGStatusWindowLevel
    }

    init?(dictionary: [String: Any]) {
        guard let windowID = dictionary[kCGWindowNumber as String] as? CGWindowID,
              let bounds = dictionary[kCGWindowBounds as String] as? NSDictionary,
              let frame = CGRect(dictionaryRepresentation: bounds),
              let layer = dictionary[kCGWindowLayer as String] as? Int,
              let ownerPID = dictionary[kCGWindowOwnerPID as String] as? pid_t else {
            return nil
        }

        self.windowID = windowID
        self.frame = MenuBarPrivateBridge.frame(for: windowID) ?? frame
        self.title = dictionary[kCGWindowName as String] as? String
        self.layer = layer
        self.ownerPID = ownerPID
        self.ownerName = dictionary[kCGWindowOwnerName as String] as? String
        self.isOnScreen = dictionary[kCGWindowIsOnscreen as String] as? Bool ?? false
    }
}

private struct MacMenderMenuBarItem: Identifiable, Hashable {
    var id: String { info.description }
    var window: MacMenderWindowInfo
    var info: MacMenderMenuBarItemInfo

    var windowID: CGWindowID { window.windowID }
    var frame: CGRect { window.frame }
    var ownerPID: pid_t { window.ownerPID }
    var ownerName: String { window.owningApplication?.localizedName ?? window.ownerName ?? "Unknown" }
    var bundleIdentifier: String? { window.owningApplication?.bundleIdentifier }
    var title: String { window.title ?? "" }
    var isOnScreen: Bool { window.isOnScreen }
    var isMovable: Bool { !MacMenderMenuBarItemInfo.immovableItems.contains(info) }
    var canBeHidden: Bool { !MacMenderMenuBarItemInfo.nonHideableItems.contains(info) }
    var isInternalControlItem: Bool {
        ["SItem", "HItem", "AHItem"].contains(title)
    }

    init?(window: MacMenderWindowInfo) {
        guard window.isMenuBarItem else { return nil }
        self.window = window
        self.info = MacMenderMenuBarItemInfo(
            namespace: MacMenderMenuBarItemInfo.Namespace(window.owningApplication?.bundleIdentifier),
            title: window.title ?? ""
        )
    }

    var displayName: String {
        let bestName = window.owningApplication?.localizedName ??
            window.ownerName ??
            window.owningApplication?.bundleIdentifier ??
            "Unknown"
        guard !title.isEmpty else { return bestName }

        switch info.namespace {
        case .controlCenter:
            switch title {
            case "AccessibilityShortcuts": return "Accessibility Shortcuts"
            case "BentoBox": return bestName
            case "CombinedModules": return "Control Center Modules"
            case "FocusModes": return "Focus"
            case "KeyboardBrightness": return "Keyboard Brightness"
            case "MusicRecognition": return "Music Recognition"
            case "NowPlaying": return "Now Playing"
            case "ScreenMirroring": return "Screen Mirroring"
            case "StageManager": return "Stage Manager"
            case "UserSwitcher": return "Fast User Switching"
            case "WiFi": return "Wi-Fi"
            default: return title
            }
        case .systemUIServer:
            switch title {
            case "TimeMachine.TMMenuExtraHost", "TimeMachineMenuExtra.TMMenuExtraHost":
                return "Time Machine"
            default:
                return title
            }
        case MacMenderMenuBarItemInfo.Namespace("com.apple.Passwords.MenuBarExtra"):
            return "Passwords"
        default:
            if title.range(of: #"^Item-\d+$"#, options: .regularExpression) != nil {
                return bestName
            }
            if title.contains("."), !title.contains(" ") {
                return title.split(separator: ".").last.map(String.init) ?? bestName
            }
            return bestName
        }
    }

    func detectedItem() -> DetectedMenuBarItem {
        DetectedMenuBarItem(
            id: info.description,
            windowID: windowID,
            ownerName: ownerName,
            title: title,
            processIdentifier: ownerPID,
            sourceBundleIdentifier: bundleIdentifier,
            frame: frame,
            isPrivateWindowBacked: true,
            infoKey: info.description,
            isMovableBySystem: isMovable,
            canBeHiddenBySystem: canBeHidden
        )
    }
}

struct DetectedMenuBarItem: Identifiable, Equatable {
    var id: String
    var windowID: CGWindowID
    var ownerName: String
    var title: String
    var processIdentifier: pid_t
    var sourceBundleIdentifier: String?
    var frame: CGRect
    var isPrivateWindowBacked: Bool = false
    var infoKey: String?
    var isMovableBySystem: Bool = true
    var canBeHiddenBySystem: Bool = true
    var actualSection: MenuBarSection = .pinned

    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if sourceBundleIdentifier == "com.apple.controlcenter" {
            switch trimmedTitle {
            case "AccessibilityShortcuts": return "Accessibility Shortcuts"
            case "BentoBox": return ownerName
            case "CombinedModules": return "Control Center Modules"
            case "FocusModes": return "Focus"
            case "KeyboardBrightness": return "Keyboard Brightness"
            case "MusicRecognition": return "Music Recognition"
            case "NowPlaying": return "Now Playing"
            case "ScreenMirroring": return "Screen Mirroring"
            case "StageManager": return "Stage Manager"
            case "UserSwitcher": return "Fast User Switching"
            case "WiFi": return "Wi-Fi"
            default: break
            }
        }
        if sourceBundleIdentifier == "com.apple.systemuiserver" {
            switch trimmedTitle {
            case "TimeMachine.TMMenuExtraHost", "TimeMachineMenuExtra.TMMenuExtraHost":
                return "Time Machine"
            default:
                break
            }
        }
        if trimmedTitle.range(of: #"^Item-\d+$"#, options: .regularExpression) != nil {
            return ownerName
        }
        if trimmedTitle.contains("."), !trimmedTitle.contains(" ") {
            return trimmedTitle.split(separator: ".").last.map(String.init) ?? ownerName
        }
        if !trimmedTitle.isEmpty { return trimmedTitle }
        return ownerName
    }

    var isInternalMacMenderItem: Bool {
        ["SItem", "HItem", "AHItem"].contains(title) ||
            title.hasPrefix("macMender.") ||
            title.contains("macMender.OverflowDivider") ||
            title.contains("macMender.AlwaysHiddenDivider")
    }

    var sectionKey: String {
        infoKey ?? "\(sourceBundleIdentifier ?? ownerName):\(title)"
    }

    var isSystemManaged: Bool {
        !isHideCandidate
    }

    var isHideCandidate: Bool {
        isPrivateWindowBacked && isMovableBySystem && canBeHiddenBySystem && !isInternalMacMenderItem
    }

    var controllabilityDescription: String {
        if !isPrivateWindowBacked { return "Not exposed as a movable menu-bar item" }
        if !isMovableBySystem { return "Fixed by macOS" }
        if !canBeHiddenBySystem { return "Can move, but cannot be hidden reliably" }
        return "Can be moved into macMender sections"
    }
}

@MainActor
final class MenuBarScannerService: NSObject, ObservableObject {
    @Published private(set) var detectedItems: [DetectedMenuBarItem] = []
    @Published private(set) var lastScanDescription = "Not scanned yet"
    @Published private(set) var overflowVisible = false
    @Published private(set) var controlsInstalled = false
    @Published private(set) var hasConcealableItems = false
    @Published private(set) var shelfEnabled = false
    @Published private(set) var spacingStatusDescription = "Default spacing"
    @Published private(set) var isApplyingSpacing = false

    private enum ControlLength {
        static let standard: CGFloat = NSStatusItem.variableLength
        static let expanded: CGFloat = 10_000
        static let divider: CGFloat = 7
    }

    private enum ControlAutosaveName {
        static let visible = "SItem"
        static let overflow = "HItem"
        static let alwaysHidden = "AHItem"
    }

    private enum MoveDestination {
        case leftOfItem(MacMenderMenuBarItem)
        case rightOfItem(MacMenderMenuBarItem)

        var target: MacMenderMenuBarItem {
            switch self {
            case .leftOfItem(let item), .rightOfItem(let item):
                item
            }
        }
    }

    private struct ItemCache {
        var visible: [MacMenderMenuBarItem] = []
        var hidden: [MacMenderMenuBarItem] = []
        var alwaysHidden: [MacMenderMenuBarItem] = []

        var allManaged: [MacMenderMenuBarItem] {
            visible + hidden + alwaysHidden
        }
    }

    private var overflowControl: NSStatusItem?
    private var alwaysHiddenControl: NSStatusItem?
    private var autoRehideTask: Task<Void, Never>?
    private var revealMonitors: [Any] = []
    private var revealTimer: Timer?
    private var lastRefresh: Date?
    private var moveTask: Task<Void, Never>?
    private var cache = ItemCache()
    private var layout = MenuBarLayout.default
    private var isHidingApplicationMenus = false
    private var lastMouseMoveDate: Date?
    private var mouseButtonIsDown = false
    private var isReconcilingSections = false

    var overflowActionTitle: String {
        guard hasConcealableItems else { return "Choose an Icon to Hide" }
        return overflowVisible ? "Hide Selected Icons" : "Reveal Hidden Icons"
    }

    var overflowStatusDescription: String {
        guard controlsInstalled else { return shelfEnabled ? "Ready to hide icons" : "Paused" }
        return overflowVisible ? "Hidden icons revealed" : "Hidden icons tucked away"
    }

    func configureControls(enabled: Bool, hasConcealableItems: Bool, layout: MenuBarLayout) {
        shelfEnabled = enabled
        self.hasConcealableItems = hasConcealableItems
        self.layout = layout
        spacingStatusDescription = layout.itemSpacingOffset == 0 ? "Default spacing" : "Spacing offset \(layout.itemSpacingOffset)"

        guard enabled else {
            self.hasConcealableItems = false
            removeControls()
            return
        }

        installControlsIfNeeded()
        updateControlAppearance(isExpanded: overflowVisible)
        if hasConcealableItems {
            hideOverflow()
        } else {
            showOverflow()
        }
        startRevealMonitors()
        refresh(force: true)
    }

    func toggleOverflow() {
        overflowVisible ? hideOverflow() : showOverflow()
    }

    func showOverflow() {
        installControlsIfNeeded()
        autoRehideTask?.cancel()
        autoRehideTask = nil
        overflowControl?.length = ControlLength.standard
        alwaysHiddenControl?.length = layout.showSectionDividers ? ControlLength.divider : ControlLength.standard
        updateControlAppearance(isExpanded: true)
        overflowVisible = true
        hideApplicationMenusIfNeeded()
        refresh(force: true)
    }

    func hideOverflow() {
        guard controlsInstalled else { return }
        guard hasConcealableItems else {
            overflowControl?.length = ControlLength.standard
            alwaysHiddenControl?.length = layout.showSectionDividers ? ControlLength.divider : 0
            updateControlAppearance(isExpanded: true)
            overflowVisible = true
            restoreApplicationMenusIfNeeded()
            return
        }
        overflowControl?.length = ControlLength.expanded
        alwaysHiddenControl?.length = ControlLength.expanded
        updateControlAppearance(isExpanded: false)
        overflowVisible = false
        autoRehideTask?.cancel()
        autoRehideTask = nil
        restoreApplicationMenusIfNeeded()
        refresh(force: true)
    }

    func refresh(force: Bool = false) {
        if !force,
           let lastRefresh,
           Date().timeIntervalSince(lastRefresh) < 1.25 {
            return
        }
        lastRefresh = Date()

        let allItems = menuBarItems(onScreenOnly: false)
        cache = makeCache(from: allItems)
        let actualSections = actualSectionMap(from: cache)
        let detected = allItems
            .filter { !$0.isInternalControlItem }
            .map { item -> DetectedMenuBarItem in
                var detected = item.detectedItem()
                detected.actualSection = actualSections[item.info.description] ?? .pinned
                return detected
            }
            .sorted { $0.frame.minX < $1.frame.minX }

        detectedItems = detected
        lastScanDescription = detected.isEmpty ? "No menu bar items detected" : "Detected \(detected.count) menu bar items"
    }

    func move(_ item: DetectedMenuBarItem, to section: MenuBarSection) {
        guard item.isHideCandidate else { return }
        installControlsIfNeeded()

        let previousMoveTask = moveTask
        moveTask = Task { @MainActor [weak self] in
            await previousMoveTask?.value
            guard let self else { return }
            await moveItem(withKey: item.sectionKey, to: section)
        }
    }

    func reconcileDesiredSections(_ desiredSections: [String: MenuBarSection]) {
        guard controlsInstalled, !isReconcilingSections else { return }
        isReconcilingSections = true
        let previousMoveTask = moveTask
        moveTask = Task { @MainActor [weak self] in
            await previousMoveTask?.value
            guard let self else { return }
            defer { self.isReconcilingSections = false }

            self.showOverflow()
            var items = self.menuBarItems(onScreenOnly: false)
            var actualSections = self.actualSectionMap(from: self.makeCache(from: items))

            for item in items where !item.isInternalControlItem && item.isMovable && item.canBeHidden {
                let desired = desiredSections[item.info.description] ?? .pinned
                let actual = actualSections[item.info.description] ?? .pinned
                guard desired != actual else { continue }
                await self.moveItem(withKey: item.info.description, to: desired)
                items = self.menuBarItems(onScreenOnly: false)
                actualSections = self.actualSectionMap(from: self.makeCache(from: items))
            }

            if self.hasConcealableItems {
                self.hideOverflow()
            }
        }
    }

    func applySpacingOffset(_ offset: Int) {
        guard !isApplyingSpacing else { return }
        isApplyingSpacing = true
        spacingStatusDescription = "Applying spacing..."

        Task { [weak self] in
            let result = await Self.writeSpacingOffset(offset)
            await MainActor.run {
                self?.isApplyingSpacing = false
                self?.spacingStatusDescription = result
            }
        }
    }

    private func installControlsIfNeeded() {
        guard overflowControl == nil else {
            controlsInstalled = true
            return
        }

        setPreferredStatusItemPosition(9_000, autosaveName: ControlAutosaveName.overflow)
        setPreferredStatusItemPosition(9_001, autosaveName: ControlAutosaveName.alwaysHidden)

        let overflow = NSStatusBar.system.statusItem(withLength: ControlLength.standard)
        overflow.autosaveName = ControlAutosaveName.overflow
        overflow.button?.target = self
        overflow.button?.action = #selector(toggleOverflowFromStatusItem)
        overflow.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        overflow.button?.toolTip = "macMender hidden-section divider"
        overflowControl = overflow

        let alwaysHidden = NSStatusBar.system.statusItem(withLength: ControlLength.divider)
        alwaysHidden.autosaveName = ControlAutosaveName.alwaysHidden
        alwaysHidden.button?.target = self
        alwaysHidden.button?.action = #selector(toggleAlwaysHiddenFromStatusItem)
        alwaysHidden.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        alwaysHidden.button?.toolTip = "macMender always-hidden divider"
        alwaysHiddenControl = alwaysHidden

        controlsInstalled = true
        updateControlAppearance(isExpanded: overflowVisible)
    }

    private func setPreferredStatusItemPosition(_ position: CGFloat, autosaveName: String) {
        let key = "NSStatusItem Preferred Position \(autosaveName)"
        let current = UserDefaults.standard.object(forKey: key) as? Double
        if current == nil || current.map({ abs($0 - Double(position)) > 1 }) == true {
            UserDefaults.standard.set(position, forKey: key)
        }
    }

    private func removeControls() {
        if let overflowControl {
            NSStatusBar.system.removeStatusItem(overflowControl)
        }
        if let alwaysHiddenControl {
            NSStatusBar.system.removeStatusItem(alwaysHiddenControl)
        }
        overflowControl = nil
        alwaysHiddenControl = nil
        overflowVisible = false
        controlsInstalled = false
        stopRevealMonitors()
        autoRehideTask?.cancel()
        autoRehideTask = nil
        restoreApplicationMenusIfNeeded()
        refresh(force: true)
    }

    @objc private func toggleOverflowFromStatusItem() {
        if NSEvent.modifierFlags.contains(.option) {
            toggleAlwaysHidden()
        } else {
            toggleOverflow()
        }
    }

    @objc private func toggleAlwaysHiddenFromStatusItem() {
        toggleAlwaysHidden()
    }

    private func toggleAlwaysHidden() {
        installControlsIfNeeded()
        if alwaysHiddenControl?.length == ControlLength.expanded {
            showOverflow()
            alwaysHiddenControl?.length = ControlLength.standard
        } else {
            alwaysHiddenControl?.length = ControlLength.expanded
        }
        refresh(force: true)
    }

    private func updateControlAppearance(isExpanded: Bool) {
        overflowControl?.button?.toolTip = isExpanded ? "Hide selected menu-bar icons" : "Reveal selected menu-bar icons"
        alwaysHiddenControl?.button?.toolTip = "Reveal always-hidden menu-bar icons"

        if layout.showSectionDividers || isExpanded {
            overflowControl?.button?.image = dividerImage(symbolName: "chevron.left")
            alwaysHiddenControl?.button?.image = dividerImage(symbolName: "chevron.compact.left")
        } else {
            overflowControl?.button?.image = nil
            alwaysHiddenControl?.button?.image = nil
        }
    }

    private func dividerImage(symbolName: String) -> NSImage? {
        let image = NSImage(systemSymbolName: symbolName, accessibilityDescription: nil)
        image?.isTemplate = true
        image?.size = NSSize(width: 12, height: 12)
        return image
    }

    private func menuBarItems(onScreenOnly: Bool) -> [MacMenderMenuBarItem] {
        let ids = MenuBarPrivateBridge.menuBarWindowIDs()
        let descriptions = MenuBarPrivateBridge.windowDescriptions(for: ids)
        let currentPID = ProcessInfo.processInfo.processIdentifier

        var seen = Set<String>()
        return descriptions
            .compactMap(MacMenderWindowInfo.init(dictionary:))
            .compactMap(MacMenderMenuBarItem.init(window:))
            .filter { item in
                guard item.ownerPID != currentPID || item.isInternalControlItem else { return false }
                guard item.ownerName != "Window Server", item.ownerName != "Dock" else { return false }
                guard item.frame.width > 0, item.frame.height > 0 else { return false }
                guard !onScreenOnly || item.isOnScreen else { return false }
                let key = "\(item.info.description)-\(item.windowID)"
                guard !seen.contains(key) else { return false }
                seen.insert(key)
                return true
            }
            .sorted { $0.frame.maxX < $1.frame.maxX }
    }

    private func makeCache(from items: [MacMenderMenuBarItem]) -> ItemCache {
        var mutableItems = items
        let hiddenControl = mutableItems.firstIndex { $0.title == ControlAutosaveName.overflow }.map { mutableItems.remove(at: $0) }
        let alwaysHiddenControl = mutableItems.firstIndex { $0.title == ControlAutosaveName.alwaysHidden }.map { mutableItems.remove(at: $0) }

        guard let hiddenControl else { return ItemCache() }

        if let alwaysHiddenControl, hiddenControl.frame.maxX <= alwaysHiddenControl.frame.minX, !mouseButtonIsDown {
            Task { @MainActor [weak self] in
                try? await self?.move(item: alwaysHiddenControl, to: .leftOfItem(hiddenControl))
            }
        }

        let userItems = mutableItems.filter { !$0.isInternalControlItem }
        var result = ItemCache()
        for item in userItems {
            guard item.canBeHidden else { continue }
            if item.frame.minX >= hiddenControl.frame.maxX {
                result.visible.append(item)
            } else if let alwaysHiddenControl, item.frame.maxX <= alwaysHiddenControl.frame.minX {
                result.alwaysHidden.append(item)
            } else if let alwaysHiddenControl {
                if item.frame.maxX <= hiddenControl.frame.minX, item.frame.minX >= alwaysHiddenControl.frame.maxX {
                    result.hidden.append(item)
                }
            } else if item.frame.maxX <= hiddenControl.frame.minX {
                result.hidden.append(item)
            }
        }
        return result
    }

    private func actualSectionMap(from cache: ItemCache) -> [String: MenuBarSection] {
        var sections = [String: MenuBarSection]()
        for item in cache.visible {
            sections[item.info.description] = .pinned
        }
        for item in cache.hidden {
            sections[item.info.description] = .overflow
        }
        for item in cache.alwaysHidden {
            sections[item.info.description] = .hidden
        }
        return sections
    }

    private func moveItem(withKey key: String, to section: MenuBarSection) async {
        refresh(force: true)
        let items = menuBarItems(onScreenOnly: false)
        guard let item = items.first(where: { $0.info.description == key }),
              item.isMovable else {
            refresh(force: true)
            return
        }
        guard let destination = destination(for: section, in: items) else {
            refresh(force: true)
            return
        }

        do {
            try await move(item: item, to: destination)
        } catch {
            try? await wakeUpItem(item)
            try? await move(item: item, to: destination)
        }
        try? await Task.sleep(for: .milliseconds(120))
        refresh(force: true)
    }

    private func destination(for section: MenuBarSection, in items: [MacMenderMenuBarItem]) -> MoveDestination? {
        guard let hiddenControl = items.first(where: { $0.title == ControlAutosaveName.overflow }) else { return nil }
        let alwaysHiddenControl = items.first { $0.title == ControlAutosaveName.alwaysHidden }
        switch section {
        case .pinned:
            return .rightOfItem(hiddenControl)
        case .overflow:
            return alwaysHiddenControl.map { .rightOfItem($0) } ?? .leftOfItem(hiddenControl)
        case .hidden:
            return alwaysHiddenControl.map { MoveDestination.leftOfItem($0) } ?? .leftOfItem(hiddenControl)
        }
    }

    private func move(item: MacMenderMenuBarItem, to destination: MoveDestination) async throws {
        if itemHasCorrectPosition(item: item, for: destination) {
            return
        }

        await waitForNoModifiersPressed()
        await waitForMouseToStopMoving()

        guard let originalCursorLocation = CGEvent(source: nil)?.location,
              let source = CGEventSource(stateID: .hidSystemState) else {
            throw MoveError.invalidEventSource
        }

        source.setLocalEventsFilterDuringSuppressionState(.macMenderPermitAllEvents, state: .eventSuppressionStateRemoteMouseDrag)
        source.setLocalEventsFilterDuringSuppressionState(.macMenderPermitAllEvents, state: .eventSuppressionStateSuppressionInterval)
        source.localEventsSuppressionInterval = 0

        CGDisplayHideCursor(CGMainDisplayID())
        defer {
            CGWarpMouseCursorPosition(originalCursorLocation)
            CGAssociateMouseAndMouseCursorPosition(1)
            CGDisplayShowCursor(CGMainDisplayID())
        }

        let initialFrame = currentFrame(for: item) ?? item.frame
        for attempt in 1...5 {
            do {
                try await moveItemOnce(item: item, to: destination, source: source)
                guard let newFrame = currentFrame(for: item), newFrame != initialFrame else {
                    throw MoveError.frameDidNotChange
                }
                return
            } catch {
                if attempt == 5 { throw error }
                try? await wakeUpItem(item)
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }

    private func moveItemOnce(
        item: MacMenderMenuBarItem,
        to destination: MoveDestination,
        source: CGEventSource
    ) async throws {
        let start = CGPoint(x: 20_000, y: 20_000)
        let end = try endPoint(for: destination)
        let target = destination.target
        let fallbackPoint = CGPoint(x: item.frame.midX, y: item.frame.midY)

        guard let down = menuBarItemEvent(type: .leftMouseDown, location: start, item: item, pid: item.ownerPID, source: source, moving: true),
              let up = menuBarItemEvent(type: .leftMouseUp, location: end, item: target, pid: item.ownerPID, source: source, moving: false),
              let fallback = menuBarItemEvent(type: .leftMouseUp, location: fallbackPoint, item: item, pid: item.ownerPID, source: source, moving: false) else {
            throw MoveError.eventCreation
        }

        let frameBeforeDown = currentFrame(for: item) ?? item.frame
        do {
            try await scrombleEvent(down, from: .pid(item.ownerPID), to: .sessionEventTap)
            try await waitForFrameChange(windowID: item.windowID, initialFrame: frameBeforeDown, timeout: .milliseconds(90))
            let frameBeforeUp = currentFrame(for: item) ?? frameBeforeDown
            try await scrombleEvent(up, from: .pid(item.ownerPID), to: .sessionEventTap)
            try await waitForFrameChange(windowID: item.windowID, initialFrame: frameBeforeUp, timeout: .milliseconds(120))
        } catch {
            fallback.post(tap: .cgSessionEventTap)
            throw error
        }
    }

    private enum MoveError: Error {
        case invalidEventSource
        case invalidItem
        case eventCreation
        case eventOperationTimeout
        case frameDidNotChange
    }

    private func endPoint(for destination: MoveDestination) throws -> CGPoint {
        switch destination {
        case .leftOfItem(let target):
            guard let frame = currentFrame(for: target) else { throw MoveError.invalidItem }
            return CGPoint(x: frame.minX, y: frame.midY)
        case .rightOfItem(let target):
            guard let frame = currentFrame(for: target) else { throw MoveError.invalidItem }
            return CGPoint(x: frame.maxX, y: frame.midY)
        }
    }

    private func currentFrame(for item: MacMenderMenuBarItem) -> CGRect? {
        MenuBarPrivateBridge.frame(for: item.windowID)
    }

    private func itemHasCorrectPosition(item: MacMenderMenuBarItem, for destination: MoveDestination) -> Bool {
        guard let itemFrame = currentFrame(for: item),
              let targetFrame = currentFrame(for: destination.target) else {
            return false
        }
        switch destination {
        case .leftOfItem:
            return abs(itemFrame.maxX - targetFrame.minX) <= 1
        case .rightOfItem:
            return abs(itemFrame.minX - targetFrame.maxX) <= 1
        }
    }

    private func wakeUpItem(_ item: MacMenderMenuBarItem) async throws {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let frame = currentFrame(for: item),
              let down = menuBarItemEvent(type: .leftMouseDown, location: CGPoint(x: frame.midX, y: frame.midY), item: item, pid: item.ownerPID, source: source, moving: true),
              let up = menuBarItemEvent(type: .leftMouseUp, location: CGPoint(x: frame.midX, y: frame.midY), item: item, pid: item.ownerPID, source: source, moving: true) else {
            throw MoveError.eventCreation
        }

        try await scrombleEvent(down, from: .pid(item.ownerPID), to: .sessionEventTap)
        try await scrombleEvent(up, from: .pid(item.ownerPID), to: .sessionEventTap)
    }

    private func menuBarItemEvent(
        type: CGEventType,
        location: CGPoint,
        item: MacMenderMenuBarItem,
        pid: pid_t,
        source: CGEventSource,
        moving: Bool
    ) -> CGEvent? {
        let button: CGMouseButton = type == .otherMouseDown || type == .otherMouseUp ? .center : .left
        guard let event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: location, mouseButton: button) else {
            return nil
        }

        event.flags = moving && type == .leftMouseDown ? .maskCommand : []
        event.setIntegerValueField(.eventTargetUnixProcessID, value: Int64(pid))
        event.setIntegerValueField(.eventSourceUserData, value: Int64(truncatingIfNeeded: Int(bitPattern: ObjectIdentifier(event))))
        event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: Int64(item.windowID))
        event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: Int64(item.windowID))
        event.setIntegerValueField(CGEventField(rawValue: 0x33)!, value: Int64(item.windowID))
        return event
    }

    private func scrombleEvent(
        _ event: CGEvent,
        from firstLocation: MacMenderIceEventTap.Location,
        to secondLocation: MacMenderIceEventTap.Location
    ) async throws {
        guard let nullEvent = CGEvent(source: nil) else {
            throw MoveError.eventCreation
        }
        let nullUserData = Int64(truncatingIfNeeded: Int(bitPattern: ObjectIdentifier(nullEvent)))
        nullEvent.setIntegerValueField(.eventSourceUserData, value: nullUserData)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let gate = ContinuationGate()
            let resumeOnce: @Sendable (Result<Void, Error>) -> Void = { result in
                guard gate.tryEnter() else { return }
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            let firstTap = MacMenderIceEventTap(
                options: .defaultTap,
                location: firstLocation,
                place: .tailAppendEventTap,
                types: [nullEvent.type]
            ) { proxy, type, receivedEvent in
                if type == .tapDisabledByUserInput || type == .tapDisabledByTimeout {
                    proxy.enable()
                    return nil
                }
                guard receivedEvent.getIntegerValueField(.eventSourceUserData) == nullUserData else {
                    return nil
                }
                proxy.disable()
                Self.postIceEvent(event, to: secondLocation)
                return nil
            }

            let secondTap = MacMenderIceEventTap(
                options: .listenOnly,
                location: secondLocation,
                place: .tailAppendEventTap,
                types: [event.type]
            ) { proxy, type, receivedEvent in
                if type == .tapDisabledByUserInput || type == .tapDisabledByTimeout {
                    proxy.enable()
                    return nil
                }
                guard Self.menuBarEventsMatch(receivedEvent, event) else {
                    return nil
                }
                guard proxy.isEnabled else {
                    return nil
                }
                proxy.disable()
                Self.postIceEvent(event, to: firstLocation)
                resumeOnce(.success(()))
                return nil
            }

            firstTap.enable()
            secondTap.enable(timeout: .milliseconds(90)) {
                firstTap.disable()
                secondTap.disable()
                resumeOnce(.failure(MoveError.eventOperationTimeout))
            }
            Self.postIceEvent(nullEvent, to: firstLocation)
        }
    }

    private nonisolated static func postIceEvent(_ event: CGEvent, to location: MacMenderIceEventTap.Location) {
        switch location {
        case .pid(let pid):
            event.postToPid(pid)
        case .sessionEventTap:
            event.post(tap: .cgSessionEventTap)
        }
    }

    private nonisolated static func menuBarEventsMatch(_ lhs: CGEvent, _ rhs: CGEvent) -> Bool {
        [
            CGEventField.eventSourceUserData,
            .mouseEventWindowUnderMousePointer,
            .mouseEventWindowUnderMousePointerThatCanHandleThisEvent,
            CGEventField(rawValue: 0x33)!
        ].allSatisfy {
            lhs.getIntegerValueField($0) == rhs.getIntegerValueField($0)
        }
    }

    private func waitForFrameChange(windowID: CGWindowID, initialFrame: CGRect, timeout: Duration) async throws {
        let deadline = Date().addingTimeInterval(Double(timeout.components.seconds) + Double(timeout.components.attoseconds) / 1_000_000_000_000_000_000)
        while Date() < deadline {
            try Task.checkCancellation()
            if let current = MenuBarPrivateBridge.frame(for: windowID), current != initialFrame {
                return
            }
            try await Task.sleep(for: .milliseconds(5))
        }
        throw MoveError.frameDidNotChange
    }

    private func waitForNoModifiersPressed() async {
        for _ in 0..<40 {
            if NSEvent.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty {
                return
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    private func waitForMouseToStopMoving() async {
        for _ in 0..<40 {
            guard let lastMouseMoveDate else { return }
            if Date().timeIntervalSince(lastMouseMoveDate) > 0.12 {
                return
            }
            try? await Task.sleep(for: .milliseconds(20))
        }
    }

    private func scheduleAutoRehideIfNeeded() {
        guard autoRehideTask == nil else { return }
        guard layout.autoRehideEnabled, hasConcealableItems else { return }
        let delay = max(0.4, min(8, layout.autoRehideDelay))
        autoRehideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
            guard !Task.isCancelled else { return }
            self?.hideOverflow()
        }
    }

    private func startRevealMonitors() {
        guard revealMonitors.isEmpty else { return }
        let movementMask: NSEvent.EventTypeMask = [.mouseMoved, .leftMouseDragged, .rightMouseDragged]
        let clickMask: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown]
        let upMask: NSEvent.EventTypeMask = [.leftMouseUp, .rightMouseUp, .otherMouseUp]
        let scrollMask: NSEvent.EventTypeMask = [.scrollWheel]

        addMonitor(mask: movementMask) { [weak self] event in
            self?.lastMouseMoveDate = Date()
            self?.updateHoverRevealState()
        }
        addMonitor(mask: clickMask) { [weak self] event in
            self?.mouseButtonIsDown = true
            self?.handleRevealClick(event)
        }
        addMonitor(mask: upMask) { [weak self] event in
            self?.mouseButtonIsDown = false
        }
        addMonitor(mask: scrollMask) { [weak self] event in
            self?.handleRevealScroll(event)
        }

        revealTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updateHoverRevealState()
            }
        }
    }

    private func addMonitor(mask: NSEvent.EventTypeMask, handler: @escaping (NSEvent) -> Void) {
        if let local = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
            handler(event)
            return event
        }) {
            revealMonitors.append(local)
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { event in
            handler(event)
        }) {
            revealMonitors.append(global)
        }
    }

    private func stopRevealMonitors() {
        for monitor in revealMonitors {
            NSEvent.removeMonitor(monitor)
        }
        revealMonitors.removeAll()
        revealTimer?.invalidate()
        revealTimer = nil
    }

    private func updateHoverRevealState() {
        guard shelfEnabled, hasConcealableItems, controlsInstalled else { return }
        if isMouseOverRevealTrigger() {
            if !overflowVisible {
                showOverflow()
            }
        } else if overflowVisible, !isMouseInsideMenuBar(), !isMouseInsideMendyPopover() {
            scheduleAutoRehideIfNeeded()
        }
    }

    private func handleRevealClick(_ event: NSEvent) {
        guard shelfEnabled, hasConcealableItems, controlsInstalled else { return }
        if event.type == .rightMouseDown, isMouseInsideEmptyMenuBarSpace() {
            return
        }
        guard isMouseInsideEmptyMenuBarSpace() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.toggleOverflow()
        }
    }

    private func handleRevealScroll(_ event: NSEvent) {
        guard shelfEnabled, hasConcealableItems, controlsInstalled, isMouseInsideMenuBar() else { return }
        let averageDelta = (event.scrollingDeltaX + event.scrollingDeltaY) / 2
        if averageDelta > 5 {
            showOverflow()
        } else if averageDelta < -5 {
            hideOverflow()
        }
    }

    private func isMouseOverRevealTrigger() -> Bool {
        isMouseOverMacMenderStatusItem() || isMouseInsideEmptyMenuBarSpace()
    }

    private func isMouseOverMacMenderStatusItem() -> Bool {
        guard let mouseLocation = CGEvent(source: nil)?.location,
              let frame = itemFrame(forControlNamed: ControlAutosaveName.visible) else {
            return false
        }
        return frame.insetBy(dx: -8, dy: -8).contains(mouseLocation)
    }

    private func isMouseInsideMenuBar() -> Bool {
        guard let mouseLocation = CGEvent(source: nil)?.location else { return false }
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            let height = screen.frame.height - screen.visibleFrame.height
            return mouseLocation.y >= screen.frame.minY && mouseLocation.y <= screen.frame.minY + max(24, height + 4)
        }
        return mouseLocation.y >= 0 && mouseLocation.y <= menuBarHeight + 4
    }

    private func isMouseInsideEmptyMenuBarSpace() -> Bool {
        guard isMouseInsideMenuBar(),
              let mouseLocation = CGEvent(source: nil)?.location else {
            return false
        }
        if isMouseInsideApplicationMenu(mouseLocation) {
            return false
        }
        let onScreenItems = menuBarItems(onScreenOnly: true).filter { !$0.isInternalControlItem }
        return !onScreenItems.contains { $0.frame.insetBy(dx: -2, dy: -4).contains(mouseLocation) }
    }

    private func isMouseInsideMendyPopover() -> Bool {
        false
    }

    private var menuBarHeight: CGFloat {
        NSScreen.screens.map { $0.frame.height - $0.visibleFrame.height }.max() ?? 40
    }

    private func itemFrame(forControlNamed name: String) -> CGRect? {
        menuBarItems(onScreenOnly: false)
            .first { $0.title == name }
            .flatMap { MenuBarPrivateBridge.frame(for: $0.windowID) ?? $0.frame }
    }

    private func isMouseInsideApplicationMenu(_ mouseLocation: CGPoint) -> Bool {
        guard let frame = applicationMenuFrame() else { return false }
        return frame.insetBy(dx: 4, dy: 4).contains(mouseLocation)
    }

    private func applicationMenuFrame() -> CGRect? {
        guard let frontmost = NSWorkspace.shared.frontmostApplication else { return nil }
        let element = AXUIElementCreateApplication(frontmost.processIdentifier)
        AXUIElementSetMessagingTimeout(element, 0.06)
        let menuBar = axChildren(of: element).first { axString($0, kAXRoleAttribute) == kAXMenuBarRole }
        guard let menuBar else { return nil }
        let enabledItems = axChildren(of: menuBar).filter {
            axString($0, kAXRoleAttribute) == kAXMenuBarItemRole && axString($0, kAXSubroleAttribute) != "AXMenuExtra"
        }
        let frame = enabledItems.reduce(CGRect.null) { partial, item in
            partial.union(axFrame(of: item))
        }
        guard !frame.isNull, frame.width > 0 else { return nil }
        return frame
    }

    private func hideApplicationMenusIfNeeded() {
        guard !isHidingApplicationMenus,
              NSApp.windows.allSatisfy({ !$0.isVisible || $0.title != "macMender" }),
              let applicationMenuFrame = applicationMenuFrame() else {
            return
        }
        let visibleItems = menuBarItems(onScreenOnly: true).filter { !$0.isInternalControlItem }
        guard let leftmost = visibleItems.min(by: { $0.frame.minX < $1.frame.minX }),
              leftmost.frame.minX <= applicationMenuFrame.maxX else {
            return
        }
        NSApp.setActivationPolicy(.accessory)
        NSApp.activate(ignoringOtherApps: false)
        isHidingApplicationMenus = true
    }

    private func restoreApplicationMenusIfNeeded() {
        guard isHidingApplicationMenus else { return }
        NSApp.hide(nil)
        isHidingApplicationMenus = false
    }

    private func axChildren(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let children = value as? [AXUIElement] else {
            return []
        }
        return children
    }

    private func axString(_ element: AXUIElement, _ attribute: String) -> String {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return ""
        }
        return value as? String ?? ""
    }

    private func axFrame(of element: AXUIElement) -> CGRect {
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

    private nonisolated static func writeSpacingOffset(_ offset: Int) async -> String {
        let clamped = max(-10, min(16, offset))
        let spacingKey = "NSStatusItemSpacing"
        let paddingKey = "NSStatusItemSelectionPadding"
        let spacingDefault = 16
        let paddingDefault = 16

        do {
            if clamped == 0 {
                _ = try await runDefaults(["-currentHost", "delete", "-globalDomain", spacingKey])
                _ = try await runDefaults(["-currentHost", "delete", "-globalDomain", paddingKey])
                return "Default spacing restored; apps may need to relaunch"
            } else {
                _ = try await runDefaults(["-currentHost", "write", "-globalDomain", spacingKey, "-int", "\(spacingDefault + clamped)"])
                _ = try await runDefaults(["-currentHost", "write", "-globalDomain", paddingKey, "-int", "\(paddingDefault + clamped)"])
                return "Spacing applied; apps may need to relaunch"
            }
        } catch {
            return "Spacing update failed"
        }
    }

    private nonisolated static func runDefaults(_ arguments: [String]) async throws -> Int32 {
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            process.arguments = arguments
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus
        }.value
    }
}
