import AppKit
import ApplicationServices
@preconcurrency import CoreGraphics
import Foundation

private let macMenderSyntheticEventMarker = ScrollEventValues.syntheticMarker

struct RuntimeStatus: Equatable {
    var eventTapRunning: Bool = false
    var lastEventDescription: String = "Waiting for permissions"
}

final class SystemEventService: ObservableObject, @unchecked Sendable {
    @Published private(set) var status = RuntimeStatus()

    var onShowSwitcher: ((Bool) -> Void)?
    var onCycleSwitcher: ((Bool) -> Void)?
    var onCommitSwitcher: (() -> Void)?
    var onCancelSwitcher: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let stateLock = NSLock()
    private var state = RuntimeEventState()
    private var switcherSessionActive = false
    private let scrollPoster = ScrollEventPoster()
    private var consumedMouseButtons = Set<Int64>()
    private var appIdentityCache: [pid_t: (bundleID: String, timestamp: TimeInterval)] = [:]
    private var lastPublishedStatus = RuntimeStatus()

    deinit {
        stop()
    }

    func update(profile: MacMenderProfile, safeModeEnabled: Bool, accessibilityGranted: Bool, featureToggles: FeatureToggles) {
        scrollPoster.cancel()
        if switcherSessionActive {
            switcherSessionActive = false
            onCancelSwitcher?()
        }
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
            CGEventMask(1 << CGEventType.leftMouseUp.rawValue) |
            CGEventMask(1 << CGEventType.otherMouseDown.rawValue) |
            CGEventMask(1 << CGEventType.otherMouseUp.rawValue) |
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
        scrollPoster.cancel()
        switcherSessionActive = false
        consumedMouseButtons.removeAll()
        appIdentityCache.removeAll()
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

        if type == .leftMouseUp || type == .otherMouseUp {
            let button = event.getIntegerValueField(.mouseEventButtonNumber)
            return consumedMouseButtons.remove(button) != nil ? nil : Unmanaged.passUnretained(event)
        }
        if type == .leftMouseDown || type == .otherMouseDown || type == .keyDown || type == .flagsChanged {
            scrollPoster.cancel()
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
        guard appRule?.bypassScrolling != true else {
            scrollPoster.cancel()
            return Unmanaged.passUnretained(event)
        }

        let original = ScrollSample(
            x: bestScrollValue(event: event, pointField: .scrollWheelEventPointDeltaAxis2, fixedField: .scrollWheelEventFixedPtDeltaAxis2, intField: .scrollWheelEventDeltaAxis2),
            y: bestScrollValue(event: event, pointField: .scrollWheelEventPointDeltaAxis1, fixedField: .scrollWheelEventFixedPtDeltaAxis1, intField: .scrollWheelEventDeltaAxis1)
        )
        guard original.x != 0 || original.y != 0 else {
            return Unmanaged.passUnretained(event)
        }

        if isTrackpad {
            scrollPoster.cancel()
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
        let smoothX = transformer.smoothsHorizontal(deviceRule: deviceRule, appRule: appRule)
        let smoothY = transformer.smoothsVertical(deviceRule: deviceRule, appRule: appRule)
        let smoothingEnabled = (smoothX && original.x != 0) || (smoothY && original.y != 0)
        if smoothingEnabled, snapshot.profile.scroll.duration > 0.02, let template = event.copy() {
            let stepped = steppedScroll(original: original, transformed: transformed, settings: snapshot.profile.scroll)
            scrollPoster.enqueue(
                template: template,
                total: ScrollSample(x: smoothX ? stepped.x : 0, y: smoothY ? stepped.y : 0),
                duration: snapshot.profile.scroll.duration
            )
            let immediate = ScrollSample(x: smoothX ? 0 : transformed.x, y: smoothY ? 0 : transformed.y)
            if immediate.x != 0 || immediate.y != 0 {
                applyScrollValues(to: event, sample: immediate, markSynthetic: false)
                return Unmanaged.passUnretained(event)
            }
            publishStatus(eventTapRunning: true, description: "Smoothed mouse scroll")
            return nil
        }

        scrollPoster.cancel()
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

        consumedMouseButtons.insert(event.getIntegerValueField(.mouseEventButtonNumber))
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
        case .consume(.showOrCycle(let backwards)):
            // Change the session synchronously before the modifier-up event arrives.
            let wasActive = switcherSessionActive
            switcherSessionActive = true
            DispatchQueue.main.async { [weak self] in
                if wasActive { self?.onCycleSwitcher?(backwards) } else { self?.onShowSwitcher?(backwards) }
            }
            publishStatus(eventTapRunning: true, description: "Window switcher opened")
            return nil
        case .consume(.ignore):
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

    private func applyScrollValues(to event: CGEvent, sample: ScrollSample, markSynthetic: Bool) {
        ScrollEventValues.apply(to: event, sample: sample, synthetic: markSynthetic)
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
        guard !settings.appRules.isEmpty else { return nil }
        let targetPID = pid_t(event.getIntegerValueField(.eventTargetUnixProcessID))
        let pid = targetPID > 0 ? targetPID : (NSWorkspace.shared.frontmostApplication?.processIdentifier ?? 0)
        guard pid > 0 else { return nil }
        let now = ProcessInfo.processInfo.systemUptime
        let bundleID: String
        if let cached = appIdentityCache[pid], now - cached.timestamp < 1 {
            bundleID = cached.bundleID
        } else {
            guard let resolved = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier else { return nil }
            if appIdentityCache.count >= 64 { appIdentityCache.removeAll(keepingCapacity: true) }
            appIdentityCache[pid] = (resolved, now)
            bundleID = resolved
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
        return false
    }


}

private struct RuntimeEventState {
    var profile: MacMenderProfile = .default
    var safeModeEnabled: Bool = false
    var accessibilityGranted: Bool = false
    var featureToggles: FeatureToggles = .default
}
