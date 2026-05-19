import Foundation
import Testing
@testable import macMender

@Suite("Scroll Transformer")
struct ScrollTransformerTests {
    @Test("reverse vertical flips y")
    func reverseVertical() {
        var settings = ScrollSettings.raw
        settings.reverseVertical = true
        let output = ScrollTransformer(settings: settings).transform(ScrollSample(x: 4, y: 10))
        #expect(output.x == 4)
        #expect(output.y == -10)
    }

    @Test("device rule overrides direction and smoothing")
    func deviceRuleOverrides() {
        let rule = DeviceScrollRule(
            id: UUID(),
            deviceKind: .externalMouse,
            displayName: "Mouse",
            reverseVertical: true,
            reverseHorizontal: true,
            smoothingEnabled: true,
            isPhysicalDeviceSpecific: true
        )
        var settings = ScrollSettings.raw
        settings.gain = 2

        let output = ScrollTransformer(settings: settings).transform(
            ScrollSample(x: 3, y: 5),
            deviceRule: rule
        )

        #expect(output.x == -6)
        #expect(output.y == -10)
    }

    @Test("app rule overrides smoothing and direction")
    func appRuleOverrides() {
        let deviceRule = DeviceScrollRule(
            id: UUID(),
            deviceKind: .externalMouse,
            displayName: "Mouse",
            reverseVertical: false,
            reverseHorizontal: false,
            smoothingEnabled: true,
            isPhysicalDeviceSpecific: false
        )
        let appRule = AppScrollRule(
            bundleIdentifier: "com.example.TestApp",
            appName: "TestApp",
            smoothingOverride: false,
            reverseVerticalOverride: true,
            reverseHorizontalOverride: true
        )
        var settings = ScrollSettings.balanced
        settings.gain = 2

        let output = ScrollTransformer(settings: settings).transform(
            ScrollSample(x: 3, y: 5),
            deviceRule: deviceRule,
            appRule: appRule
        )

        #expect(output.x == -3)
        #expect(output.y == -5)
    }

    @Test("projected samples preserve transformed total")
    func projectedSamplesPreserveTotal() {
        var settings = ScrollSettings.balanced
        settings.gain = 1.5
        settings.duration = 0.2

        let samples = ScrollTransformer(settings: settings).projectedSamples(
            from: ScrollSample(x: 2, y: 10),
            count: 10
        )
        let total = samples.reduce(ScrollSample(x: 0, y: 0)) { partial, sample in
            ScrollSample(x: partial.x + sample.x, y: partial.y + sample.y)
        }

        #expect(abs(total.x - 3) < 0.0001)
        #expect(abs(total.y - 15) < 0.0001)
    }
}
