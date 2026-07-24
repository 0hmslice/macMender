import Testing
@testable import macMender

@Suite("Design System")
struct DesignSystemTests {
    @Test("feature states map to semantic visual tones")
    func featureStatesMapToSemanticVisualTones() {
        #expect(MacMenderStatusTone(featureStatusKind: .active) == .active)
        #expect(MacMenderStatusTone(featureStatusKind: .ready) == .active)
        #expect(MacMenderStatusTone(featureStatusKind: .paused) == .paused)
        #expect(MacMenderStatusTone(featureStatusKind: .needsAttention) == .attention)
        #expect(MacMenderStatusTone(featureStatusKind: .off) == .neutral)
        #expect(MacMenderStatusTone(featureStatusKind: .optional) == .neutral)
    }

    @Test("menu bar compatibility results map to honest visual tones")
    func menuBarCompatibilityResultsMapToVisualTones() {
        #expect(MacMenderStatusTone(menuBarSpacingResultKind: .applied) == .active)
        #expect(MacMenderStatusTone(menuBarSpacingResultKind: .appliedSomeAppsMayNeedRelaunch) == .attention)
        #expect(MacMenderStatusTone(menuBarSpacingResultKind: .couldNotConfirmSystemItemUpdate) == .attention)
        #expect(MacMenderStatusTone(menuBarSpacingResultKind: .unsupportedOnThisBeta) == .attention)
        #expect(MacMenderStatusTone(menuBarSpacingResultKind: .failed) == .unavailable)
        #expect(MacMenderStatusTone(menuBarSpacingResultKind: nil) == .neutral)
    }
}
