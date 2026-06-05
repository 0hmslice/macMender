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
        #expect(config.appBehavior.menuBarSpacing == .systemDefault)
        #expect(config.hasCompletedOnboarding)
    }

    @Test("menu bar spacing presets map to defaults values")
    func menuBarSpacingPresetsMapToDefaultsValues() {
        #expect(MenuBarSpacingPreference.compact.defaultsValue == 8)
        #expect(MenuBarSpacingPreference.comfortable.defaultsValue == 16)
        #expect(MenuBarSpacingPreference.wide.defaultsValue == 24)
        #expect(MenuBarSpacingService.defaultsPlan(for: .compact).operation == .write(8))
        #expect(MenuBarSpacingService.defaultsPlan(for: .comfortable).operation == .write(16))
        #expect(MenuBarSpacingService.defaultsPlan(for: .wide).operation == .write(24))
    }

    @Test("menu bar spacing reset maps to system default")
    func menuBarSpacingResetMapsToSystemDefault() {
        #expect(MenuBarSpacingPreference.systemDefault.defaultsValue == nil)
        #expect(MenuBarSpacingService.defaultsPlan(for: .systemDefault).operation == .delete)
        #expect(MenuBarSpacingDefaultsPlan.keys == ["NSStatusItemSpacing", "NSStatusItemSelectionPadding"])
    }

    @Test("menu bar spacing custom value maps and clamps")
    func menuBarSpacingCustomValueMapsAndClamps() {
        #expect(MenuBarSpacingPreference.clampedValue(-8) == 0)
        #expect(MenuBarSpacingPreference.clampedValue(18) == 18)
        #expect(MenuBarSpacingPreference.clampedValue(48) == 32)
        #expect(MenuBarSpacingService.defaultsPlan(for: .custom, customValue: 18).operation == .write(18))
        #expect(MenuBarSpacingService.defaultsPlan(for: .custom, customValue: -4).operation == .write(0))
        #expect(MenuBarSpacingService.defaultsPlan(for: .custom, customValue: 42).operation == .write(32))
    }

    @Test("menu bar spacing values resolve matching presets")
    func menuBarSpacingValuesResolveMatchingPresets() {
        #expect(MenuBarSpacingPreference.preference(matching: 8) == .compact)
        #expect(MenuBarSpacingPreference.preference(matching: 16) == .comfortable)
        #expect(MenuBarSpacingPreference.preference(matching: 24) == .wide)
        #expect(MenuBarSpacingPreference.preference(matching: 18) == .custom)
    }

    @Test("decodes menu bar spacing custom settings")
    func decodesMenuBarSpacingCustomSettings() throws {
        let json = """
        {
          "hideDockIcon": true,
          "menuBarSpacing": "custom",
          "menuBarSpacingCustomValue": 22
        }
        """

        let behavior = try JSONDecoder().decode(AppBehavior.self, from: Data(json.utf8))

        #expect(behavior.hideDockIcon)
        #expect(behavior.menuBarSpacing == .custom)
        #expect(behavior.menuBarSpacingCustomValue == 22)
    }

    @Test("decodes unknown menu bar spacing safely")
    func decodesUnknownMenuBarSpacingSafely() throws {
        let json = """
        {
          "hideDockIcon": false,
          "menuBarSpacing": "legacyWideEnough",
          "menuBarSpacingCustomValue": 99
        }
        """

        let behavior = try JSONDecoder().decode(AppBehavior.self, from: Data(json.utf8))

        #expect(behavior.menuBarSpacing == .systemDefault)
        #expect(behavior.menuBarSpacingCustomValue == 32)
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

    @Test("legacy broken Dock preview animations map to safe styles")
    func legacyBrokenDockPreviewAnimationsMapToSafeStyles() throws {
        let glassPop = """
        {
          "enabled": true,
          "hoverDelay": 0.35,
          "previewIdleTimeout": 1.8,
          "animationStyle": "glassPop",
          "animationDuration": 0.22,
          "layout": "grid",
          "thumbnailSize": 152
        }
        """
        let genie = glassPop.replacingOccurrences(of: "glassPop", with: "genie")

        #expect(try JSONDecoder().decode(DockPreviewSettings.self, from: Data(glassPop.utf8)).animationStyle == .system)
        #expect(try JSONDecoder().decode(DockPreviewSettings.self, from: Data(genie.utf8)).animationStyle == .scale)
    }

    @Test("Dock preview animation picker exposes only polished styles")
    func dockPreviewAnimationPickerExposesOnlyPolishedStyles() {
        #expect(DockPreviewAnimationStyle.selectableCases == [.system, .fade, .scale, .slideUp, .none])
        #expect(!DockPreviewAnimationStyle.selectableCases.contains(.glassPop))
        #expect(!DockPreviewAnimationStyle.selectableCases.contains(.genie))
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
