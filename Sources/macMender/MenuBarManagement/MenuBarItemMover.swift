import AppKit
import ApplicationServices
@preconcurrency import CoreGraphics
import Foundation
import MacMenderMenuBarEngine

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

private extension CGEventField {
    static let macMenderWindowID = CGEventField(rawValue: 0x33)!
}

private final class MenuBarContinuationGate: @unchecked Sendable {
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

enum MenuBarMoveDestination {
    case leftOfItem(MenuBarPhysicalItem)
    case rightOfItem(MenuBarPhysicalItem)

    var target: MenuBarPhysicalItem {
        switch self {
        case .leftOfItem(let item), .rightOfItem(let item):
            item
        }
    }
}

@MainActor
final class MenuBarItemMover {
    private enum MoveError: Error {
        case invalidEventSource
        case invalidItem
        case cursorCouldNotBeHidden
        case cursorGuardDisabled
        case eventCreation
        case eventOperationTimeout
        case frameDidNotChange
    }

    private var lastMouseMoveDate: Date?
    private var cursorHideBalance = 0
    private var cursorWatchdog: DispatchWorkItem?

    func noteMouseMoved() {
        lastMouseMoveDate = Date()
    }

    func destination(for section: MenuBarSection, in items: [MenuBarPhysicalItem]) -> MenuBarMoveDestination? {
        guard let hiddenControl = items.first(where: { $0.title == MenuBarControlIdentifier.hidden }) else { return nil }
        let visibleControl = items.first { $0.title == MenuBarControlIdentifier.visible }
        let alwaysHiddenControl = items.first { $0.title == MenuBarControlIdentifier.alwaysHidden }
        switch section {
        case .pinned:
            if let visibleControl {
                return .rightOfItem(visibleControl)
            }
            return .rightOfItem(hiddenControl)
        case .overflow:
            if let alwaysHiddenControl {
                return .rightOfItem(alwaysHiddenControl)
            }
            return .leftOfItem(hiddenControl)
        case .hidden:
            return alwaysHiddenControl.map { MenuBarMoveDestination.leftOfItem($0) } ?? .leftOfItem(hiddenControl)
        }
    }

    func destination(for section: MenuBarSection, before target: MenuBarPhysicalItem?, in items: [MenuBarPhysicalItem]) -> MenuBarMoveDestination? {
        if let target, !target.isInternalControlItem {
            return .leftOfItem(target)
        }
        return destination(for: section, in: items)
    }

    func move(item: MenuBarPhysicalItem, to destination: MenuBarMoveDestination) async throws {
        if itemHasCorrectPosition(item: item, for: destination) {
            return
        }

        await waitForNoModifiersPressed()
        await waitForMouseToStopMoving()

        guard let source = CGEventSource(stateID: .hidSystemState) else {
            throw MoveError.invalidEventSource
        }
        guard MenuBarEngineMovementPolicy.allowsScopedCursorGuard else {
            throw MoveError.cursorGuardDisabled
        }

        source.setLocalEventsFilterDuringSuppressionState(.macMenderPermitAllEvents, state: .eventSuppressionStateRemoteMouseDrag)
        source.setLocalEventsFilterDuringSuppressionState(.macMenderPermitAllEvents, state: .eventSuppressionStateSuppressionInterval)
        source.localEventsSuppressionInterval = 0

        let originalMouseLocation = CGEvent(source: nil)?.location
        guard hideCursor(watchdogTimeout: 10) else {
            throw MoveError.cursorCouldNotBeHidden
        }
        defer {
            if let originalMouseLocation {
                CGWarpMouseCursorPosition(originalMouseLocation)
            }
            showCursor()
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
                try? await Task.sleep(for: .milliseconds(80))
            }
        }
    }

    private func moveItemOnce(
        item: MenuBarPhysicalItem,
        to destination: MenuBarMoveDestination,
        source: CGEventSource
    ) async throws {
        let points = try targetPoints(for: destination)
        let start = points.start
        let end = points.end
        let target = destination.target

        guard let down = menuBarItemEvent(type: .leftMouseDown, location: start, item: item, pid: item.eventTargetPID, source: source, moving: true),
              let up = menuBarItemEvent(type: .leftMouseUp, location: end, item: target, pid: item.eventTargetPID, source: source, moving: false) else {
            throw MoveError.eventCreation
        }

        let frameBeforeDown = currentFrame(for: item) ?? item.frame
        do {
            try await scrombleEvent(down, from: .pid(item.eventTargetPID), to: .sessionEventTap)
            try await waitForFrameChange(windowID: item.windowID, initialFrame: frameBeforeDown, timeout: .milliseconds(500))
            let frameBeforeUp = currentFrame(for: item) ?? frameBeforeDown
            try await scrombleEvent(up, from: .pid(item.eventTargetPID), to: .sessionEventTap)
            // Thaw repeats mouse-up events for menu bar item moves to avoid
            // invalid intermediate item state on modern status-item hosts.
            try? await scrombleEvent(up, from: .pid(item.eventTargetPID), to: .sessionEventTap)
            try await waitForFrameChange(windowID: item.windowID, initialFrame: frameBeforeUp, timeout: .milliseconds(500))
        } catch {
            throw error
        }
    }

    private func targetPoints(for destination: MenuBarMoveDestination) throws -> (start: CGPoint, end: CGPoint) {
        guard let targetFrame = currentFrame(for: destination.target) else {
            throw MoveError.invalidItem
        }

        switch destination {
        case .leftOfItem:
            let point = CGPoint(x: targetFrame.minX, y: targetFrame.minY)
            return (point, point)
        case .rightOfItem:
            let point = CGPoint(x: targetFrame.maxX, y: targetFrame.minY)
            return (point, point)
        }
    }

    private func currentFrame(for item: MenuBarPhysicalItem) -> CGRect? {
        MenuBarPrivateBridge.frame(for: item.windowID) ?? (item.isInternalControlItem ? item.frame : nil)
    }

    private func itemHasCorrectPosition(item: MenuBarPhysicalItem, for destination: MenuBarMoveDestination) -> Bool {
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

    private func menuBarItemEvent(
        type: CGEventType,
        location: CGPoint,
        item: MenuBarPhysicalItem,
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
        event.setIntegerValueField(.macMenderWindowID, value: Int64(item.windowID))
        return event
    }

    // Adapted from Ice/Thaw's MenuBarItemManager.scrombleEvent.
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
            let gate = MenuBarContinuationGate()
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
            secondTap.enable(timeout: .milliseconds(500)) {
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
            .macMenderWindowID
        ].allSatisfy {
            lhs.getIntegerValueField($0) == rhs.getIntegerValueField($0)
        }
    }

    private func hideCursor(watchdogTimeout: TimeInterval) -> Bool {
        cursorHideBalance += 1
        guard cursorHideBalance == 1 else { return true }
        let result = CGDisplayHideCursor(CGMainDisplayID())
        guard result == .success else {
            cursorHideBalance = max(0, cursorHideBalance - 1)
            return false
        }
        let watchdog = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                self?.forceShowCursor()
            }
        }
        cursorWatchdog?.cancel()
        cursorWatchdog = watchdog
        DispatchQueue.main.asyncAfter(deadline: .now() + watchdogTimeout, execute: watchdog)
        return true
    }

    private func showCursor() {
        guard cursorHideBalance > 0 else { return }
        cursorHideBalance -= 1
        guard cursorHideBalance == 0 else { return }
        cursorWatchdog?.cancel()
        cursorWatchdog = nil
        CGDisplayShowCursor(CGMainDisplayID())
    }

    private func forceShowCursor() {
        guard cursorHideBalance > 0 else { return }
        cursorHideBalance = 0
        cursorWatchdog?.cancel()
        cursorWatchdog = nil
        CGDisplayShowCursor(CGMainDisplayID())
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
}
