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
}
