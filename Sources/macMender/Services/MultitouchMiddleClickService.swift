import AppKit
import CoreGraphics
import Foundation
import MultitouchSupport

@MainActor
final class MultitouchMiddleClickService: ObservableObject {
    @Published private(set) var isRunning = false
    @Published private(set) var lastStatus = "Not running"

    private var devices: [MTDevice] = []
    private var touchStartTime: Date?
    private var initialCentroid = CGPoint.zero
    private var latestCentroid = CGPoint.zero
    private var maybeTap = false
    private var lastEmulatedClick: Date?

    private let requiredFingers = 3
    private let maxTapDuration: TimeInterval = 0.30
    private let maxMovement: CGFloat = 0.05

    func start() {
        guard !isRunning else { return }
        let list = MTDeviceCreateList() as NSArray
        devices = list.map { $0 as! MTDevice }
        guard !devices.isEmpty else {
            lastStatus = "No multitouch devices found"
            return
        }

        MultitouchMiddleClickBridge.shared.service = self
        for device in devices {
            MTRegisterContactFrameCallback(device, MultitouchMiddleClickBridge.callback)
            MTDeviceStart(device, 0)
        }
        isRunning = true
        lastStatus = "Watching three-finger taps"
    }

    func stop() {
        guard isRunning else { return }
        for device in devices {
            MTUnregisterContactFrameCallback(device, MultitouchMiddleClickBridge.callback)
            MTDeviceStop(device)
        }
        devices.removeAll()
        isRunning = false
        lastStatus = "Stopped"
        resetGesture()
    }

    fileprivate func handleTouchPoints(_ points: [CGPoint]) {
        if points.isEmpty {
            finishGesture()
            return
        }

        guard points.count == requiredFingers else {
            if points.count > requiredFingers {
                resetGesture()
            }
            return
        }

        let centroid = centroid(for: points)
        if touchStartTime == nil {
            touchStartTime = Date()
            initialCentroid = centroid
            latestCentroid = centroid
            maybeTap = true
        } else {
            latestCentroid = centroid
            if let touchStartTime, Date().timeIntervalSince(touchStartTime) > maxTapDuration {
                maybeTap = false
            }
        }
    }

    private func finishGesture() {
        defer { resetGesture() }
        guard maybeTap,
              let touchStartTime,
              Date().timeIntervalSince(touchStartTime) <= maxTapDuration,
              movement(from: initialCentroid, to: latestCentroid) <= maxMovement else {
            return
        }

        if let lastEmulatedClick, Date().timeIntervalSince(lastEmulatedClick) < 0.10 {
            return
        }
        lastEmulatedClick = Date()
        postMiddleClick()
        lastStatus = "Posted three-finger middle click"
    }

    private func resetGesture() {
        touchStartTime = nil
        initialCentroid = .zero
        latestCentroid = .zero
        maybeTap = false
    }

    private func centroid(for points: [CGPoint]) -> CGPoint {
        var x: CGFloat = 0
        var y: CGFloat = 0
        for point in points {
            x += point.x
            y += point.y
        }
        return CGPoint(x: x / CGFloat(points.count), y: y / CGFloat(points.count))
    }

    private func movement(from start: CGPoint, to end: CGPoint) -> CGFloat {
        abs(start.x - end.x) + abs(start.y - end.y)
    }

    private func postMiddleClick() {
        let location = CGEvent(source: nil)?.location ?? .zero
        guard let down = CGEvent(mouseEventSource: nil, mouseType: .otherMouseDown, mouseCursorPosition: location, mouseButton: .center),
              let up = CGEvent(mouseEventSource: nil, mouseType: .otherMouseUp, mouseCursorPosition: location, mouseButton: .center) else {
            return
        }
        down.setIntegerValueField(.mouseEventButtonNumber, value: 2)
        up.setIntegerValueField(.mouseEventButtonNumber, value: 2)
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
    }
}

private final class MultitouchMiddleClickBridge: @unchecked Sendable {
    static let shared = MultitouchMiddleClickBridge()
    weak var service: MultitouchMiddleClickService?

    static let callback: MTFrameCallbackFunction = { _, touches, count, _, _ in
        let points: [CGPoint]
        if let touches, count > 0 {
            points = (0..<Int(count)).map { index in
                CGPoint(
                    x: CGFloat(touches[index].normalizedVector.position.x),
                    y: CGFloat(touches[index].normalizedVector.position.y)
                )
            }
        } else {
            points = []
        }
        Task { @MainActor in
            MultitouchMiddleClickBridge.shared.service?.handleTouchPoints(points)
        }
    }
}
