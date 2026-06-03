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
          "automationRules": []
        }
        """

        let config = try JSONDecoder().decode(AppConfig.self, from: Data(json.utf8))

        #expect(config.appBehavior == .default)
        #expect(config.hasCompletedOnboarding)
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
        object.removeValue(forKey: "animationStyle")
        object.removeValue(forKey: "animationDuration")
        let olderData = try JSONSerialization.data(withJSONObject: object)

        let settings = try JSONDecoder().decode(DockPreviewSettings.self, from: olderData)

        #expect(settings.previewIdleTimeout == DockPreviewSettings.default.previewIdleTimeout)
        #expect(settings.animationStyle == DockPreviewSettings.default.animationStyle)
        #expect(settings.animationDuration == DockPreviewSettings.default.animationDuration)
    }

    @Test("decodes legacy Dock preview animation speed as duration")
    func decodesLegacyDockPreviewAnimationSpeedAsDuration() throws {
        let json = """
        {
          "enabled": true,
          "hoverDelay": 0.35,
          "previewIdleTimeout": 1.8,
          "animationStyle": "scale",
          "animationSpeed": "smooth",
          "layout": "grid",
          "thumbnailSize": 152
        }
        """

        let settings = try JSONDecoder().decode(DockPreviewSettings.self, from: Data(json.utf8))

        #expect(settings.animationStyle == .scale)
        #expect(settings.animationDuration == DockPreviewAnimationSpeed.smooth.duration)
    }

    @Test("runtime middle-click actions only include implemented actions")
    func runtimeMiddleClickActionsOnlyIncludeImplementedActions() {
        #expect(MiddleClickAction.runtimeSupportedCases == [.middleClick, .openBackgroundTab, .closeTab])
        #expect(!MiddleClickAction.runtimeSupportedCases.contains(.customShortcut))
    }

    @Test("default profile uses three-finger tap middle click")
    func defaultProfileUsesThreeFingerTapMiddleClick() {
        #expect(MacMenderProfile.default.middleClick.enabled)
        #expect(MacMenderProfile.default.middleClick.trigger == .experimentalThreeFinger)
        #expect(MacMenderProfile.default.middleClick.action == .middleClick)
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
