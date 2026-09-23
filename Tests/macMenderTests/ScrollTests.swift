import Foundation
import CoreGraphics
import Testing
@testable import macMender

struct ScrollTests {
    @Test func bypassPreservesBothAxes() {
        var settings = ScrollSettings.balanced
        settings.reverseHorizontal = true
        settings.reverseVertical = true
        let rule = AppScrollRule(bundleIdentifier: "example.game", appName: "Game", smoothingOverride: true, reverseVerticalOverride: true, bypassScrolling: true)
        let transformer = ScrollTransformer(settings: settings)
        let sample = ScrollSample(x: 12, y: -21)
        #expect(transformer.transform(sample, appRule: rule) == sample)
        #expect(!transformer.smoothsVertical(appRule: rule))
        #expect(!transformer.smoothsHorizontal(appRule: rule))
    }

    @Test func axisSwitchesAreRespectedWithDeviceRules() {
        let transformer = ScrollTransformer(settings: .subtle)
        let mouse = DeviceScrollRule.defaults.first { $0.deviceKind == .externalMouse }!
        #expect(transformer.smoothsVertical(deviceRule: mouse))
        #expect(!transformer.smoothsHorizontal(deviceRule: mouse))
        #expect(transformer.transform(ScrollSample(x: 10, y: 10), deviceRule: mouse) == ScrollSample(x: 10, y: -10.5))
    }

    @Test func explicitAppRuleOverridesDeviceAndAxis() {
        let transformer = ScrollTransformer(settings: .raw)
        let rule = AppScrollRule(bundleIdentifier: "a", appName: "A", smoothingOverride: true, reverseVerticalOverride: false)
        #expect(transformer.smoothsHorizontal(deviceRule: DeviceScrollRule.defaults[0], appRule: rule))
    }

    @Test func presetsPreservePersonalRulesAndDirection() {
        var settings = ScrollSettings.balanced
        settings.reverseVertical = true
        settings.reverseHorizontal = true
        let devices = settings.deviceRules
        let apps = settings.appRules
        for preset in SmoothingPreset.allCases {
            settings.applyPreset(preset)
            #expect(settings.preset == preset)
            #expect(settings.reverseVertical && settings.reverseHorizontal)
            #expect(settings.deviceRules == devices && settings.appRules == apps)
        }
    }

    @Test func offPresetActuallyStopsSmoothing() {
        var settings = ScrollSettings.balanced
        settings.applyPreset(.off)
        let transformer = ScrollTransformer(settings: settings)
        #expect(!transformer.smoothsVertical(deviceRule: DeviceScrollRule.defaults[1]))
        #expect(transformer.projectedSamples(from: ScrollSample(x: 0, y: 100)).count == 1)
    }

    @Test func animationConservesDistance() {
        var momentum = ScrollMomentum()
        momentum.add(ScrollSample(x: 30, y: -100), duration: 0.2)
        var sum = ScrollSample(x: 0, y: 0)
        for _ in 0..<30 {
            let next = momentum.advance(by: 0.01)
            sum.x += next.x; sum.y += next.y
        }
        #expect(abs(sum.x - 30) < 0.000001)
        #expect(abs(sum.y + 100) < 0.000001)
        #expect(!momentum.isActive)
    }

    @Test func rapidBurstsAccumulateWithoutLosingDistance() {
        var momentum = ScrollMomentum()
        var total = 0.0
        for _ in 0..<1000 {
            momentum.add(ScrollSample(x: 0, y: 10), duration: 0.16)
            total += momentum.advance(by: 0.001).y
        }
        total += momentum.advance(by: 1).y
        #expect(abs(total - 10_000) < 0.000001)
        #expect(!momentum.isActive)
    }

    @Test func reversalDropsOpposingMomentum() {
        var momentum = ScrollMomentum()
        momentum.add(ScrollSample(x: 0, y: 100), duration: 0.2)
        _ = momentum.advance(by: 0.01)
        momentum.add(ScrollSample(x: 0, y: -10), duration: 0.2)
        #expect(momentum.advance(by: 1).y == -10)
    }

    @Test func smallScrollsSurvivePixelRounding() {
        var pixels = ScrollPixelAccumulator()
        var total = ScrollSample(x: 0, y: 0)
        for _ in 0..<100 {
            let sample = pixels.consume(ScrollSample(x: 0.01, y: -0.1))
            total.x += sample.x
            total.y += sample.y
        }
        #expect(total == ScrollSample(x: 1, y: -10))
    }

    @Test func cancelPreventsLateEvents() async throws {
        let counter = LockedCounter()
        let poster = ScrollEventPoster { _ in counter.increment() }
        let template = try #require(CGEvent(source: nil))
        poster.enqueue(template: template, total: ScrollSample(x: 0, y: 500), duration: 0.5)
        try await Task.sleep(for: .milliseconds(30))
        poster.cancel()
        let atCancellation = counter.value
        #expect(atCancellation > 0)
        try await Task.sleep(for: .milliseconds(40))
        #expect(counter.value == atCancellation)
    }
}

private final class LockedCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0
    var value: Int { lock.withLock { count } }
    func increment() { lock.withLock { count += 1 } }
}
