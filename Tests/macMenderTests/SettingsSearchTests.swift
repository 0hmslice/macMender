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

@MainActor
@Test func sidebarGlassRunsFromSolidToTheSystemFrost() {
    #expect(SidebarGlassBackground.solidOpacity(for: 0) == 1)
    #expect(SidebarGlassBackground.solidOpacity(for: 0.25) == 0.75)
    #expect(SidebarGlassBackground.solidOpacity(for: 1) == 0)
    #expect(SidebarGlassBackground.solidOpacity(for: 4) == 0)
}

@Test func everySectionBelongsToASidebarGroupAndIsSearchableByTitle() {
    for section in SettingsSection.allCases {
        #expect(SettingsSection.Group.allCases.contains(section.group))
        #expect(SettingsSection.matching(section.title).contains(section))
    }
    #expect(SettingsSection.matching("magnification") == [.dockSettings])
    #expect(SettingsSection.matching("peek") == [.dockPreviews])
    #expect(SettingsSection.matching("glass") == [.general])
}

@Test func sidebarGlassDecodesWithADefaultAndStaysInRange() throws {
    let legacy = try JSONDecoder().decode(AppBehavior.self, from: Data(#"{"hideDockIcon":true}"#.utf8))
    #expect(legacy.sidebarGlass == AppBehavior.defaultSidebarGlass)
    let wild = try JSONDecoder().decode(AppBehavior.self, from: Data(#"{"sidebarGlass":7}"#.utf8))
    #expect(wild.sidebarGlass == 1)
}
