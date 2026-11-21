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
@Test func sidebarGlassRunsFromSolidToThinFrost() {
    #expect(SidebarGlassBackground.solidOpacity(for: 0) == 1)
    #expect(SidebarGlassBackground.frostOpacity(for: 0) == 1)
    // Mid-range: the solid layer is gone and the frost is still whole.
    #expect(SidebarGlassBackground.solidOpacity(for: SidebarGlassBackground.frostedPoint) == 0)
    #expect(SidebarGlassBackground.frostOpacity(for: SidebarGlassBackground.frostedPoint) == 1)
    #expect(SidebarGlassBackground.solidOpacity(for: 1) == 0)
    #expect(abs(SidebarGlassBackground.frostOpacity(for: 1) - SidebarGlassBackground.minimumFrost) < 0.0001)
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
