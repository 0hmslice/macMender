@preconcurrency import CoreGraphics
import Foundation

/// A bounded animation: wheel bursts share one remaining distance and one timer.
struct ScrollMomentum {
    private(set) var remaining = ScrollSample(x: 0, y: 0)
    private var timeRemaining: Double = 0
    var isActive: Bool { timeRemaining > 0 }

    mutating func add(_ sample: ScrollSample, duration: Double) {
        if sample.x * remaining.x < 0 { remaining.x = 0 }
        if sample.y * remaining.y < 0 { remaining.y = 0 }
        remaining.x += sample.x
        remaining.y += sample.y
        timeRemaining = min(0.5, max(0.001, duration))
    }

    mutating func advance(by elapsed: Double) -> ScrollSample {
        guard isActive, elapsed > 0 else { return ScrollSample(x: 0, y: 0) }
        let progress = min(1, elapsed / timeRemaining)
        let weight = 1 - pow(1 - progress, 3)
        let sample = ScrollSample(x: remaining.x * weight, y: remaining.y * weight)
        remaining.x -= sample.x
        remaining.y -= sample.y
        timeRemaining = max(0, timeRemaining - elapsed)
        return sample
    }
}

enum ScrollEventValues {
    static let syntheticMarker: Int64 = 0x6D61634D656E6465

    static func apply(to event: CGEvent, sample: ScrollSample, synthetic: Bool = false) {
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis1, value: sample.y)
        event.setDoubleValueField(.scrollWheelEventPointDeltaAxis2, value: sample.x)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis1, value: sample.y)
        event.setDoubleValueField(.scrollWheelEventFixedPtDeltaAxis2, value: sample.x)
        event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: Int64(sample.y.rounded()))
        event.setIntegerValueField(.scrollWheelEventDeltaAxis2, value: Int64(sample.x.rounded()))
        if synthetic { event.setIntegerValueField(.eventSourceUserData, value: syntheticMarker) }
    }
}

/// CGEvent point deltas are integral. Carry subpixel distance across frames.
struct ScrollPixelAccumulator {
    private var remainder = ScrollSample(x: 0, y: 0)

    mutating func consume(_ sample: ScrollSample) -> ScrollSample {
        remainder.x += sample.x
        remainder.y += sample.y
        let pixels = ScrollSample(x: remainder.x.rounded(), y: remainder.y.rounded())
        remainder.x -= pixels.x
        remainder.y -= pixels.y
        return pixels
    }
}

/// Mutable state is confined to `queue`; cancel is synchronous so no tail survives a pause.
final class ScrollEventPoster: @unchecked Sendable {
    private let queue = DispatchQueue(label: "macMender.scroll.animation", qos: .userInteractive)
    private var timer: DispatchSourceTimer?
    private var momentum = ScrollMomentum()
    private var pixels = ScrollPixelAccumulator()
    private var template: CGEvent?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private let postEvent: @Sendable (CGEvent) -> Void

    init(postEvent: @escaping @Sendable (CGEvent) -> Void = { $0.post(tap: .cghidEventTap) }) {
        self.postEvent = postEvent
    }

    func enqueue(template: CGEvent, total: ScrollSample, duration: Double) {
        queue.async { [self] in
            if let previous = self.template,
               previous.getIntegerValueField(.eventTargetUnixProcessID) != template.getIntegerValueField(.eventTargetUnixProcessID) ||
                previous.flags != template.flags {
                momentum = ScrollMomentum()
                pixels = ScrollPixelAccumulator()
            }
            self.template = template
            momentum.add(total, duration: duration)
            guard timer == nil else { return }
            lastTick = ProcessInfo.processInfo.systemUptime
            let timer = DispatchSource.makeTimerSource(queue: queue)
            timer.schedule(deadline: .now(), repeating: .milliseconds(8), leeway: .milliseconds(1))
            timer.setEventHandler { [weak self] in self?.tick() }
            self.timer = timer
            timer.resume()
        }
    }

    func cancel() {
        queue.sync { finish() }
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let sample = pixels.consume(momentum.advance(by: now - lastTick))
        lastTick = now
        if let event = template?.copy(), sample.x != 0 || sample.y != 0 {
            ScrollEventValues.apply(to: event, sample: sample, synthetic: true)
            event.setIntegerValueField(.scrollWheelEventIsContinuous, value: 1)
            postEvent(event)
        }
        if !momentum.isActive { finish() }
    }

    private func finish() {
        timer?.cancel()
        timer = nil
        template = nil
        momentum = ScrollMomentum()
        pixels = ScrollPixelAccumulator()
    }
}
