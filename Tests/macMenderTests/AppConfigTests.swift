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
    }

    @Test("decodes older profile without Dock preview settings")
    func decodesOlderProfileWithoutDockPreviewSettings() throws {
        let encoded = try JSONEncoder().encode(MacMenderProfile.default)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object.removeValue(forKey: "dockPreviews")
        let legacyData = try JSONSerialization.data(withJSONObject: object)

        let profile = try JSONDecoder().decode(MacMenderProfile.self, from: legacyData)

        #expect(profile.dockPreviews == .default)
    }

    @Test("runtime middle-click actions only include implemented actions")
    func runtimeMiddleClickActionsOnlyIncludeImplementedActions() {
        #expect(MiddleClickAction.runtimeSupportedCases == [.middleClick, .openBackgroundTab, .closeTab])
        #expect(!MiddleClickAction.runtimeSupportedCases.contains(.customShortcut))
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
