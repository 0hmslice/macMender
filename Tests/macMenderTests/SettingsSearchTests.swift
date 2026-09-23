import Testing
@testable import macMender

@Test func settingsSearchMatchesWordsAndSynonyms() {
    #expect(SettingsSection.matching("  ") == SettingsSection.allCases)
    #expect(SettingsSection.matching("NATIVE scrolling") == [.input])
    #expect(SettingsSection.matching("caffeine") == [.keepAwake])
    #expect(SettingsSection.matching("screen recording") == [.privacy])
    #expect(SettingsSection.matching("does-not-exist").isEmpty)
}
