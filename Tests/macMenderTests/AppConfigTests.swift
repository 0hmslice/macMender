import Foundation
import Testing
@testable import macMender

@Suite("App Config")
struct AppConfigTests {
    @Test("decodes older config without app behavior")
    func decodesOlderConfigWithoutAppBehavior() throws {
        let json = """
        {
          "schemaVersion": 2,
          "hasCompletedOnboarding": true,
          "activeProfileID": "1BA904A0-5404-47F1-9349-A9B5F101C001",
          "safeModeEnabled": false,
          "featureToggles": {
            "scrolling": true,
            "menuBarManagement": true,
            "windowSwitcher": true,
            "dockProfiles": true
          },
          "profiles": [],
          "menuBarLayout": {
            "items": []
          },
          "automationRules": []
        }
        """

        let config = try JSONDecoder().decode(AppConfig.self, from: Data(json.utf8))

        #expect(config.appBehavior == .default)
        #expect(config.hasCompletedOnboarding)
        #expect(!config.menuBarLayout.showSectionDividers)
        #expect(config.menuBarLayout.autoRehideEnabled)
        #expect(config.menuBarLayout.itemSpacingOffset == 0)
        #expect(config.menuBarLayout.revealOnHover)
        #expect(config.menuBarLayout.revealOnEmptyMenuBarClick)
        #expect(config.menuBarLayout.revealOnScroll)
        #expect(config.menuBarLayout.hideApplicationMenusOnOverlap)
        #expect(!config.menuBarLayout.showHiddenItemsInSecondaryBar)
    }

    @Test("decodes older menu bar layout without newer hiding options")
    func decodesOlderMenuBarLayoutWithoutOptions() throws {
        let json = #"{"items":[]}"#

        let layout = try JSONDecoder().decode(MenuBarLayout.self, from: Data(json.utf8))

        #expect(layout.items.isEmpty)
        #expect(layout.itemSpacingOffset == 0)
        #expect(!layout.showSectionDividers)
        #expect(layout.autoRehideEnabled)
        #expect(layout.autoRehideDelay == 1.0)
        #expect(layout.revealOnHover)
        #expect(layout.revealOnEmptyMenuBarClick)
        #expect(layout.revealOnScroll)
        #expect(layout.hideApplicationMenusOnOverlap)
        #expect(!layout.showHiddenItemsInSecondaryBar)
    }

    @Test("decodes older profile without Dock preview settings")
    func decodesOlderProfileWithoutDockPreviewSettings() throws {
        let encoded = try JSONEncoder().encode(MacMenderProfile.default)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "dockPreviews")
        let olderData = try JSONSerialization.data(withJSONObject: object)

        let profile = try JSONDecoder().decode(MacMenderProfile.self, from: olderData)

        #expect(profile.dockPreviews == .default)
    }

    @Test("decodes older Dock preview settings without idle timeout")
    func decodesOlderDockPreviewSettingsWithoutIdleTimeout() throws {
        let encoded = try JSONEncoder().encode(DockPreviewSettings.default)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "previewIdleTimeout")
        let olderData = try JSONSerialization.data(withJSONObject: object)

        let settings = try JSONDecoder().decode(DockPreviewSettings.self, from: olderData)

        #expect(settings.previewIdleTimeout == DockPreviewSettings.default.previewIdleTimeout)
    }

    @Test("runtime middle-click actions only include implemented actions")
    func runtimeMiddleClickActionsOnlyIncludeImplementedActions() {
        #expect(MiddleClickAction.runtimeSupportedCases == [.middleClick, .openBackgroundTab, .closeTab])
        #expect(!MiddleClickAction.runtimeSupportedCases.contains(.customShortcut))
    }

    @Test("menu bar layout preserves known item order across section moves")
    func menuBarLayoutPreservesKnownItemOrder() {
        var layout = MenuBarLayout.default
        layout.rememberMenuBarItem(itemKey: "stats", title: "Stats", section: .pinned)
        layout.rememberMenuBarItem(itemKey: "wifi", title: "Wi-Fi", section: .pinned)
        layout.rememberMenuBarItem(itemKey: "codex", title: "Codex", section: .pinned)

        layout.setMenuBarItemSection(itemKey: "stats", title: "Stats", section: .overflow)
        layout.setMenuBarItemSection(itemKey: "wifi", title: "Wi-Fi", section: .overflow)
        layout.setMenuBarItemSection(itemKey: "wifi", title: "Wi-Fi", section: .pinned)
        layout.setMenuBarItemSection(itemKey: "stats", title: "Stats", section: .pinned, before: "codex")

        #expect(layout.orderedItemKeys(in: .pinned) == ["wifi", "stats", "codex"])
        #expect(layout.orderedItemKeys(in: .overflow).isEmpty)
        #expect(layout.orderedItemKeys(in: .hidden).isEmpty)
    }

    @Test("menu bar layout appends moved items to target section without reshuffling unrelated items")
    func menuBarLayoutAppendsMovesWithoutReshuffling() {
        var layout = MenuBarLayout.default
        layout.rememberMenuBarItem(itemKey: "wifi", title: "Wi-Fi", section: .pinned)
        layout.rememberMenuBarItem(itemKey: "sound", title: "Sound", section: .pinned)
        layout.rememberMenuBarItem(itemKey: "stats", title: "Stats", section: .pinned)
        layout.rememberMenuBarItem(itemKey: "codex", title: "Codex", section: .pinned)

        layout.setMenuBarItemSection(itemKey: "stats", title: "Stats", section: .overflow)
        layout.setMenuBarItemSection(itemKey: "wifi", title: "Wi-Fi", section: .overflow)
        layout.setMenuBarItemSection(itemKey: "stats", title: "Stats", section: .hidden)

        #expect(layout.orderedItemKeys(in: .pinned) == ["sound", "codex"])
        #expect(layout.orderedItemKeys(in: .overflow) == ["wifi"])
        #expect(layout.orderedItemKeys(in: .hidden) == ["stats"])
    }

    @Test("menu bar layout syncs live WindowServer order for detected items")
    func menuBarLayoutSyncsLiveWindowServerOrder() {
        var layout = MenuBarLayout.default
        layout.rememberMenuBarItem(itemKey: "stats", title: "Stats", section: .pinned)
        layout.rememberMenuBarItem(itemKey: "wifi", title: "Wi-Fi", section: .pinned)
        layout.rememberMenuBarItem(itemKey: "codex", title: "Codex", section: .pinned)

        layout.syncLiveMenuBarItems([
            MenuBarLiveOrderItem(key: "codex", title: "Codex", section: .pinned),
            MenuBarLiveOrderItem(key: "stats", title: "Stats", section: .pinned),
            MenuBarLiveOrderItem(key: "wifi", title: "Wi-Fi", section: .pinned)
        ])

        #expect(layout.orderedItemKeys(in: .pinned) == ["codex", "stats", "wifi"])
    }

    @Test("menu bar layout keeps closed hidden selections while syncing live order")
    func menuBarLayoutKeepsClosedHiddenSelectionsDuringLiveSync() {
        var layout = MenuBarLayout.default
        layout.rememberMenuBarItem(itemKey: "stats", title: "Stats", section: .pinned)
        layout.rememberMenuBarItem(itemKey: "closed", title: "Closed Utility", section: .overflow)
        layout.rememberMenuBarItem(itemKey: "wifi", title: "Wi-Fi", section: .pinned)

        layout.syncLiveMenuBarItems([
            MenuBarLiveOrderItem(key: "wifi", title: "Wi-Fi", section: .pinned),
            MenuBarLiveOrderItem(key: "stats", title: "Stats", section: .pinned)
        ])

        #expect(layout.orderedItemKeys(in: .pinned) == ["wifi", "stats"])
        #expect(layout.orderedItemKeys(in: .overflow) == ["closed"])
    }

    @Test("menu bar layout resolves hidden visible conflicts without corrupting visible sections")
    func menuBarLayoutResolvesHiddenVisibleConflictsWithoutCorruptingVisibleSections() {
        var layout = MenuBarLayout.default
        layout.rememberMenuBarItem(itemKey: "stats", title: "Stats", section: .pinned)
        layout.rememberMenuBarItem(itemKey: "wifi", title: "Wi-Fi", section: .overflow)

        let statsSection = layout.resolvedSectionForLiveSync(
            itemKey: "stats",
            actualSection: .overflow,
            resolvesVisibleConflicts: true
        )
        let wifiSection = layout.resolvedSectionForLiveSync(
            itemKey: "wifi",
            actualSection: .pinned,
            resolvesVisibleConflicts: true
        )

        layout.syncLiveMenuBarItems([
            MenuBarLiveOrderItem(key: "wifi", title: "Wi-Fi", section: wifiSection),
            MenuBarLiveOrderItem(key: "stats", title: "Stats", section: statsSection)
        ])

        #expect(layout.orderedItemKeys(in: .pinned) == ["wifi", "stats"])
        #expect(layout.orderedItemKeys(in: .overflow).isEmpty)
    }

    @Test("profiles section uses simplified product language")
    func profilesSectionUsesSimplifiedProductLanguage() {
        #expect(SettingsSection.profiles.title == "Profiles")
        #expect(SettingsSection.profiles.subtitle == "Saved setups")
    }

    @Test("launch agent plist opens the app bundle")
    func launchAgentPlistOpensAppBundle() throws {
        let plist = LoginItemService.launchAgentPlist(
            label: "com.ryan.macMender.login",
            appPath: "/Applications/macMender.app"
        )

        let arguments = try #require(plist["ProgramArguments"] as? [String])
        #expect(plist["Label"] as? String == "com.ryan.macMender.login")
        #expect(arguments == ["/usr/bin/open", "-n", "/Applications/macMender.app"])
        #expect(plist["RunAtLoad"] as? Bool == true)
        #expect(plist["LimitLoadToSessionType"] as? String == "Aqua")
    }
}
