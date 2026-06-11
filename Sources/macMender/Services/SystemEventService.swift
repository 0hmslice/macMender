import AppKit
import ApplicationServices
@preconcurrency import CoreGraphics
import Foundation

private let macMenderSyntheticEventMarker: Int64 = 0x6D61634D656E6465
private let escapeKeyCode: Int64 = 53

struct RuntimeStatus: Equatable {
    var eventTapRunning: Bool = false
    var lastEventDescription: String = "Waiting for permissions"
}

final class SystemEventService: ObservableObject, @unchecked Sendable {
    @Published private(set) var status = RuntimeStatus()

    var onShowSwitcher: (() -> Void)?
    var onCycleSwitcher: (() -> Void)?
    var onCommitSwitcher: (() -> Void)?
    var onCancelSwitcher: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let stateLock = NSLock()
    private var state = RuntimeEventState()
    private var switcherSessionActive = false
    private let posterQueue = DispatchQueue(label: "macMender.scroll.poster", qos: .userInteractive)
    private var lastPublishedStatus = RuntimeStatus()

    deinit {
        stop()
    }

    func update(profile: MacMenderProfile, safeModeEnabled: Bool, accessibilityGranted: Bool, featureToggles: FeatureToggles) {
        stateLock.lock()
        state.profile = profile
        state.safeModeEnabled = safeModeEnabled
        state.accessibilityGranted = accessibilityGranted
        state.featureToggles = featureToggles
        stateLock.unlock()

        if accessibilityGranted, !safeModeEnabled {
            start()
        } else {
            stop()
            publishStatus(eventTapRunning: false, description: safeModeEnabled ? "Paused by Safe Mode" : "Waiting for Accessibility")
        }
    }

    func start() {
        guard eventTap == nil else {
            return
        }

        let mask =
            CGEventMask(1 << CGEventType.scrollWheel.rawValue) |
            CGEventMask(1 << CGEventType.leftMouseDown.rawValue) |
            CGEventMask(1 << CGEventType.otherMouseDown.rawValue) |
            CGEventMask(1 << CGEventType.keyDown.rawValue) |
            CGEventMask(1 << CGEventType.keyUp.rawValue) |
            CGEventMask(1 << CGEventType.flagsChanged.rawValue)

        let refcon = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: Self.eventCallback,
            userInfo: refcon
        ) else {
            publishStatus(eventTapRunning: false, description: "Unable to create event tap")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        eventTap = tap
        runLoopSource = source
        publishStatus(eventTapRunning: true, description: "Event tap running")
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private static let eventCallback: CGEventTapCallBack = { proxy, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let service = Unmanaged<SystemEventService>.fromOpaque(refcon).takeUnretainedValue()

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = service.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        return service.handle(proxy: proxy, type: type, event: event)
    }

    private func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if event.getIntegerValueField(.eventSourceUserData) == macMenderSyntheticEventMarker {
            return Unmanaged.passUnretained(event)
        }

        let snapshot = currentState()
        guard snapshot.accessibilityGranted, !snapshot.safeModeEnabled else {
            return Unmanaged.passUnretained(event)
        }

        switch type {
        case .scrollWheel where snapshot.featureToggles.scrolling:
            return handleScroll(event: event, snapshot: snapshot)
        case .leftMouseDown, .otherMouseDown:
            return handleMouse(type: type, event: event, snapshot: snapshot)
        case .keyDown where snapshot.featureToggles.windowSwitcher,
             .keyUp where snapshot.featureToggles.windowSwitcher,
             .flagsChanged where snapshot.featureToggles.windowSwitcher:
            return handleSwitcher(type: type, event: event, snapshot: snapshot)
        default:
            return Unmanaged.passUnretained(event)
        }
    }

    private func handleScroll(event: CGEvent, snapshot: RuntimeEventState) -> Unmanaged<CGEvent>? {
        let isTrackpad = looksLikeTrackpadScroll(event)
        let deviceKind: DeviceKind = isTrackpad ? .builtInTrackpad : .externalMouse
        let deviceRule = snapshot.profile.scroll.deviceRules.first { $0.deviceKind == deviceKind }
        let appRule = appRule(for: event, in: snapshot.profile.scroll)

        let original = ScrollSample(
            x: bestScrollValue(event: event, pointField: .scrollWheelEventPointDeltaAxis2, fixedField: .scrollWheelEventFixedPtDeltaAxis2, intField: .scrollWheelEventDeltaAxis2),
            y: bestScrollValue(event: event, pointField: .scrollWheelEventPointDeltaAxis1, fixedField: .scrollWheelEventFixedPtDeltaAxis1, intField: .scrollWheelEventDeltaAxis1)
        )
        guard original.x != 0 || original.y != 0 else {
            return Unmanaged.passUnretained(event)
        }

        if isTrackpad {
            let reverseVertical = appRule?.reverseVerticalOverride ?? deviceRule?.reverseVertical ?? snapshot.profile.scroll.reverseVertical
            let reverseHorizontal = appRule?.reverseHorizontalOverride ?? deviceRule?.reverseHorizontal ?? snapshot.profile.scroll.reverseHorizontal
            if reverseVertical || reverseHorizontal {
                applyScrollValues(
                    to: event,
                    sample: ScrollSample(
                        x: original.x * (reverseHorizontal ? -1 : 1),
                        y: original.y * (reverseVertical ? -1 : 1)
                    ),
                    markSynthetic: false
                )
                publishStatus(eventTapRunning: true, description: "Continuous scroll direction adjusted")
                return Unmanaged.passUnretained(event)
            }

            publishStatus(eventTapRunning: true, description: "Continuous scroll passed through")
            return Unmanaged.passUnretained(event)
        }

        let transformer = ScrollTransformer(settings: snapshot.profile.scroll)
        let transformed = transformer.transform(original, deviceRule: deviceRule, appRule: appRule)
        let smoothingEnabled = isSmoothingEnabled(settings: snapshot.profile.scroll, deviceRule: deviceRule, appRule: appRule, axisSample: original)
        if smoothingEnabled, snapshot.profile.scroll.duration > 0.02, let template = event.copy() {
            let stepped = steppedScroll(original: original, transformed: transformed, settings: snapshot.profile.scroll)
            postSmoothedScroll(template: template, total: stepped, duration: snapshot.profile.scroll.duration)
            publishStatus(eventTapRunning: true, description: "Smoothed mouse scroll")
            return nil
        }

        applyScrollValues(to: event, sample: transformed, markSynthetic: false)
        publishStatus(eventTapRunning: true, description: "Mouse scroll transformed")
        return Unmanaged.passUnretained(event)
    }

    private func handleMouse(type: CGEventType, event: CGEvent, snapshot: RuntimeEventState) -> Unmanaged<CGEvent>? {
        let settings = snapshot.profile.middleClick
        guard settings.enabled, settings.trigger != .disabled else {
            return Unmanaged.passUnretained(event)
        }

        let shouldTrigger: Bool
        switch settings.trigger {
        case .modifierClick:
            shouldTrigger = type == .leftMouseDown && event.flags.contains(.maskControl)
        case .extraMouseButton:
            shouldTrigger = type == .otherMouseDown && event.getIntegerValueField(.mouseEventButtonNumber) > 2
        case .experimentalThreeFinger, .disabled:
            shouldTrigger = false
        }

        guard shouldTrigger else {
            return Unmanaged.passUnretained(event)
        }

        performMiddleClickAction(settings.action, at: event.location)
        publishStatus(eventTapRunning: true, description: "Middle-click action posted")
        return nil
    }

    private func handleSwitcher(type: CGEventType, event: CGEvent, snapshot: RuntimeEventState) -> Unmanaged<CGEvent>? {
        guard snapshot.profile.windowSwitcher.enabled,
              let shortcut = SwitcherShortcut(snapshot.profile.windowSwitcher.shortcut) else {
            return Unmanaged.passUnretained(event)
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

        switch SwitcherKeyboardRouter.decision(
            type: type,
            keyCode: keyCode,
            flags: event.flags,
            shortcut: shortcut,
            switcherSessionActive: switcherSessionActive
        ) {
        case .passThrough:
            return Unmanaged.passUnretained(event)
        case .consume(.showOrCycle):
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.switcherSessionActive {
                    self.onCycleSwitcher?()
                } else {
                    self.switcherSessionActive = true
                    self.onShowSwitcher?()
                }
            }
            publishStatus(eventTapRunning: true, description: "Window switcher opened")
            return nil
        case .consume(.commit):
            switcherSessionActive = false
            DispatchQueue.main.async { [weak self] in
                self?.onCommitSwitcher?()
            }
            return nil
        case .consume(.cancel):
            switcherSessionActive = false
            DispatchQueue.main.async { [weak self] in
                self?.onCancelSwitcher?()
            }
            return nil
        }
    }

    private func postSmoothedScroll(template: CGEvent, total: ScrollSample, duration: Double) {
        let frames = max(4, min(18, Int(duration / 0.012)))
        let interval = duration / Double(frames)
        var previousEase = 0.0

        for frame in 1...frames {
            let progress = Double(frame) / Double(frames)
            let ease = 1 - pow(1 - progress, 3)
            let weight = ease - previousEase
            previousEase = ease

            posterQueue.asyncAfter(deadline: .now() + interval * Double(frame - 1)) {
                guard let event = template.copy() else { return }
                self.applyScrollValues(to: event, sample: ScrollSample(x: total.x * weight, y: total.y * weight), markSynthetic: true)
                event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
                event.post(tap: .cghidEventTap)
            }
        }
    }

    private func applyScrollValues(to event: CGEvent, sample: ScrollSample, markSynthetic: Bool) {
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: sample.y)
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: sample.x)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: sample.y)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: sample.x)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: Int64(sample.y.rounded(.toNearestOrAwayFromZero)))
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: Int64(sample.x.rounded(.toNearestOrAwayFromZero)))
        if markSynthetic {
            event.setIntegerValueField(.eventSourceUserData, value: macMenderSyntheticEventMarker)
        }
    }

    private func performMiddleClickAction(_ action: MiddleClickAction, at location: CGPoint) {
        switch action {
        case .middleClick, .openBackgroundTab:
            postMiddleClick(at: location)
        case .closeTab:
            postKeyboardShortcut(keyCode: 13, flags: .maskCommand)
        case .customShortcut:
            postMiddleClick(at: location)
        }
    }

    private func postMiddleClick(at location: CGPoint) {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(mouseEventSource: source, mouseType: .otherMouseDown, mouseCursorPosition: location, mouseButton: .center),
              let up = CGEvent(mouseEventSource: source, mouseType: .otherMouseUp, mouseCursorPosition: location, mouseButton: .center) else {
            return
        }
        down.setIntegerValueField(.eventSourceUserData, value: macMenderSyntheticEventMarker)
        up.setIntegerValueField(.eventSourceUserData, value: macMenderSyntheticEventMarker)
        down.setIntegerValueField(.mouseEventButtonNumber, value: 2)
        up.setIntegerValueField(.mouseEventButtonNumber, value: 2)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private func postKeyboardShortcut(keyCode: CGKeyCode, flags: CGEventFlags) {
        guard let source = CGEventSource(stateID: .hidSystemState),
              let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }
        down.flags = flags
        up.flags = flags
        down.setIntegerValueField(.eventSourceUserData, value: macMenderSyntheticEventMarker)
        up.setIntegerValueField(.eventSourceUserData, value: macMenderSyntheticEventMarker)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }

    private func currentState() -> RuntimeEventState {
        stateLock.lock()
        defer { stateLock.unlock() }
        return state
    }

    private func publishStatus(eventTapRunning: Bool, description: String) {
        let nextStatus = RuntimeStatus(eventTapRunning: eventTapRunning, lastEventDescription: description)
        if nextStatus == lastPublishedStatus {
            return
        }
        lastPublishedStatus = nextStatus

        DispatchQueue.main.async { [weak self] in
            self?.status = nextStatus
        }
    }

    private func appRule(for event: CGEvent, in settings: ScrollSettings) -> AppScrollRule? {
        let pid = pid_t(event.getIntegerValueField(.eventTargetUnixProcessID))
        guard pid > 0,
              let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier else {
            return nil
        }
        return settings.appRules.first { $0.bundleIdentifier == bundleID }
    }

    private func bestScrollValue(event: CGEvent, pointField: CGEventField, fixedField: CGEventField, intField: CGEventField) -> Double {
        let point = event.getDoubleValueField(pointField)
        if point != 0 { return point }
        let fixed = event.getDoubleValueField(fixedField)
        if fixed != 0 { return fixed }
        return Double(event.getIntegerValueField(intField))
    }

    private func steppedScroll(original: ScrollSample, transformed: ScrollSample, settings: ScrollSettings) -> ScrollSample {
        ScrollSample(
            x: normalizedAxis(original: original.x, transformed: transformed.x, step: settings.step),
            y: normalizedAxis(original: original.y, transformed: transformed.y, step: settings.step)
        )
    }

    private func normalizedAxis(original: Double, transformed: Double, step: Double) -> Double {
        guard original != 0, abs(transformed) < step else { return transformed }
        return transformed < 0 ? -step : step
    }

    private func looksLikeTrackpadScroll(_ event: CGEvent) -> Bool {
        if event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0 { return true }
        if event.getDoubleValueField(.scrollWheelEventMomentumPhase) != 0 { return true }
        if event.getDoubleValueField(.scrollWheelEventScrollPhase) != 0 { return true }
        if event.getDoubleValueField(.scrollWheelEventScrollCount) != 0 { return true }
        return false
    }

    private func isSmoothingEnabled(settings: ScrollSettings, deviceRule: DeviceScrollRule?, appRule: AppScrollRule?, axisSample: ScrollSample) -> Bool {
        if let override = appRule?.smoothingOverride { return override }
        if let device = deviceRule { return device.smoothingEnabled }
        if abs(axisSample.y) >= abs(axisSample.x) {
            return settings.verticalSmoothingEnabled
        }
        return settings.horizontalSmoothingEnabled
    }
}

private struct RuntimeEventState {
    var profile: MacMenderProfile = .default
    var safeModeEnabled: Bool = false
    var accessibilityGranted: Bool = false
    var featureToggles: FeatureToggles = .default
}

enum SwitcherKeyboardAction: Equatable {
    case showOrCycle
    case commit
    case cancel
}

enum SwitcherKeyboardDecision: Equatable {
    case passThrough
    case consume(SwitcherKeyboardAction)
}

struct SwitcherKeyboardRouter {
    static func decision(
        type: CGEventType,
        keyCode: Int64,
        flags: CGEventFlags,
        shortcut: SwitcherShortcut,
        switcherSessionActive: Bool
    ) -> SwitcherKeyboardDecision {
        let shortcutHeld = shortcut.flags.allSatisfy { flags.contains($0) }

        if type == .keyDown, keyCode == shortcut.keyCode, shortcutHeld {
            return .consume(.showOrCycle)
        }

        if (type == .keyUp && shortcut.modifierKeyCodes.contains(CGKeyCode(keyCode))) || (type == .flagsChanged && !shortcutHeld) {
            return switcherSessionActive ? .consume(.commit) : .passThrough
        }

        if type == .keyDown, keyCode == escapeKeyCode {
            return switcherSessionActive ? .consume(.cancel) : .passThrough
        }

        return .passThrough
    }
}

struct SwitcherShortcut {
    var keyCode: Int64
    var flags: [CGEventFlags]
    var modifierKeyCodes: Set<CGKeyCode>

    init?(_ rawShortcut: String) {
        let tokens = rawShortcut
            .replacingOccurrences(of: " ", with: "")
            .split(separator: "+")
            .map { String($0).lowercased() }

        guard let keyToken = tokens.last else { return nil }

        switch keyToken {
        case "tab":
            keyCode = 48
        case "space":
            keyCode = 49
        case "escape", "esc":
            keyCode = escapeKeyCode
        default:
            return nil
        }

        var parsedFlags: [CGEventFlags] = []
        var parsedModifierKeys = Set<CGKeyCode>()

        for token in tokens.dropLast() {
            switch token {
            case "option", "alt":
                parsedFlags.append(.maskAlternate)
                parsedModifierKeys.formUnion([58, 61])
            case "control", "ctrl":
                parsedFlags.append(.maskControl)
                parsedModifierKeys.formUnion([59, 62])
            case "command", "cmd":
                parsedFlags.append(.maskCommand)
                parsedModifierKeys.formUnion([55, 54])
            case "shift":
                parsedFlags.append(.maskShift)
                parsedModifierKeys.formUnion([56, 60])
            default:
                return nil
            }
        }

        guard !parsedFlags.isEmpty else { return nil }
        flags = parsedFlags
        modifierKeyCodes = parsedModifierKeys
    }
}
