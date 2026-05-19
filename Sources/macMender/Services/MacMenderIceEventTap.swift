import AppKit
@preconcurrency import CoreGraphics

// Adapted from Ice for macOS EventTap.swift (GPL-3.0).
// Source: https://github.com/jordanbaird/Ice
final class MacMenderIceEventTap: @unchecked Sendable {
    enum Location {
        case sessionEventTap
        case pid(pid_t)
    }

    struct Proxy: @unchecked Sendable {
        private let tap: MacMenderIceEventTap
        private let pointer: CGEventTapProxy

        var isEnabled: Bool {
            tap.isEnabled
        }

        fileprivate init(tap: MacMenderIceEventTap, pointer: CGEventTapProxy) {
            self.tap = tap
            self.pointer = pointer
        }

        func postEvent(_ event: CGEvent) {
            event.tapPostEvent(pointer)
        }

        func enable() {
            tap.enable()
        }

        func disable() {
            tap.disable()
        }
    }

    private let runLoop = CFRunLoopGetCurrent()
    private let mode: CFRunLoopMode = .commonModes
    private typealias Callback = @Sendable (MacMenderIceEventTap, CGEventTapProxy, CGEventType, CGEvent) -> Unmanaged<CGEvent>?
    private let callback: Callback
    private var machPort: CFMachPort?
    private var source: CFRunLoopSource?

    var isEnabled: Bool {
        guard let machPort else { return false }
        return CGEvent.tapIsEnabled(tap: machPort)
    }

    init(
        options: CGEventTapOptions,
        location: Location,
        place: CGEventTapPlacement,
        types: [CGEventType],
        callback: @Sendable @escaping (_ proxy: Proxy, _ type: CGEventType, _ event: CGEvent) -> CGEvent?
    ) {
        self.callback = { tap, pointer, type, event in
            callback(Proxy(tap: tap, pointer: pointer), type, event).map(Unmanaged.passUnretained)
        }

        let mask = types.reduce(into: CGEventMask(0)) { partial, type in
            partial |= 1 << type.rawValue
        }

        guard let machPort = Self.createMachPort(
            location: location,
            place: place,
            options: options,
            eventsOfInterest: mask,
            callback: handleMacMenderIceEvent,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ),
        let source = CFMachPortCreateRunLoopSource(nil, machPort, 0) else {
            return
        }

        self.machPort = machPort
        self.source = source
    }

    deinit {
        guard let machPort else { return }
        if let source {
            CFRunLoopRemoveSource(runLoop, source, mode)
        }
        CGEvent.tapEnable(tap: machPort, enable: false)
        CFMachPortInvalidate(machPort)
    }

    func enable() {
        guard let source, let machPort else { return }
        CFRunLoopAddSource(runLoop, source, mode)
        CGEvent.tapEnable(tap: machPort, enable: true)
    }

    func enable(timeout: Duration, onTimeout: @Sendable @escaping () -> Void) {
        enable()
        Task { [weak self] in
            try? await Task.sleep(for: timeout)
            if self?.isEnabled == true {
                onTimeout()
            }
        }
    }

    func disable() {
        guard let source, let machPort else { return }
        CFRunLoopRemoveSource(runLoop, source, mode)
        CGEvent.tapEnable(tap: machPort, enable: false)
    }

    fileprivate nonisolated static func performCallback(
        for eventTap: MacMenderIceEventTap,
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        eventTap.callback(eventTap, proxy, type, event)
    }

    private static func createMachPort(
        location: Location,
        place: CGEventTapPlacement,
        options: CGEventTapOptions,
        eventsOfInterest: CGEventMask,
        callback: CGEventTapCallBack,
        userInfo: UnsafeMutableRawPointer?
    ) -> CFMachPort? {
        switch location {
        case .pid(let pid):
            CGEvent.tapCreateForPid(
                pid: pid,
                place: place,
                options: options,
                eventsOfInterest: eventsOfInterest,
                callback: callback,
                userInfo: userInfo
            )
        case .sessionEventTap:
            CGEvent.tapCreate(
                tap: .cgSessionEventTap,
                place: place,
                options: options,
                eventsOfInterest: eventsOfInterest,
                callback: callback,
                userInfo: userInfo
            )
        }
    }
}

private func handleMacMenderIceEvent(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else {
        return Unmanaged.passRetained(event)
    }
    let eventTap = Unmanaged<MacMenderIceEventTap>.fromOpaque(refcon).takeUnretainedValue()
    return MacMenderIceEventTap.performCallback(for: eventTap, proxy: proxy, type: type, event: event)
}
