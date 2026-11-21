import Foundation
import Testing
@testable import macMender

@Test func settingsSearchMatchesWordsAndSynonyms() {
    #expect(SettingsSection.matching("  ") == SettingsSection.allCases)
    #expect(SettingsSection.matching("NATIVE scrolling") == [.input])
    #expect(SettingsSection.matching("caffeine") == [.keepAwake])
    #expect(SettingsSection.matching("screen recording") == [.privacy])
    #expect(SettingsSection.matching("does-not-exist").isEmpty)
}

@Test func everySectionBelongsToASidebarGroupAndIsSearchableByTitle() {
    for section in SettingsSection.allCases {
        #expect(SettingsSection.Group.allCases.contains(section.group))
        #expect(SettingsSection.matching(section.title).contains(section))
    }
    #expect(SettingsSection.matching("magnification") == [.dockSettings])
    #expect(SettingsSection.matching("peek") == [.dockPreviews])
    #expect(SettingsSection.matching("login") == [.general])
}

@Test func onboardingStepsRunInOrderAndStopAtEachEnd() {
    #expect(OnboardingStep.welcome.previous == nil)
    #expect(OnboardingStep.welcome.next == .features)
    #expect(OnboardingStep.features.next == .permissions)
    #expect(OnboardingStep.permissions.next == .finish)
    #expect(OnboardingStep.finish.next == nil)
    #expect(OnboardingStep.finish.previous == .permissions)
}

@Test func quickControlTurnsThreeFingerTapOnWhateverTriggerWasChosen() {
    var profile = MacMenderProfile.default
    profile.middleClick.trigger = .modifierClick
    profile.middleClick.enabled = false
    profile.setThreeFingerTapEnabled(true)
    #expect(profile.isThreeFingerTapEnabled)
}
