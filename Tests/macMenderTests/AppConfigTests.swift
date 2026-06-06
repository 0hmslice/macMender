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
        #expect(config.profiles == [MacMenderProfile.default])
        #expect(config.activeProfile.id == MacMenderProfile.default.id)
        #expect(config.hasCompletedOnboarding)
    }

    @Test("profile selection repairs invalid state")
    func profileSelectionRepairsInvalidState() {
        var config = AppConfig.default
        let customProfile = MacMenderProfile.customCopy(from: .default, name: "Work")
        config.profiles = [customProfile]
        config.activeProfileID = UUID()

        config.ensureValidProfileSelection()

        #expect(config.activeProfileID == customProfile.id)
        #expect(config.activeProfile == customProfile)
    }

    @Test("profile switcher visibility follows live profile count")
    func profileSwitcherVisibilityFollowsLiveProfileCount() {
        var config = AppConfig.default

        #expect(!config.shouldShowProfileSwitcher)

        config.createProfile(named: "Work")
        let workProfileID = config.activeProfileID

        #expect(config.shouldShowProfileSwitcher)
        #expect(config.activeProfile.name == "Work")

        config.deleteProfile(workProfileID)

        #expect(!config.shouldShowProfileSwitcher)
        #expect(config.activeProfile.id == MacMenderProfile.default.id)
    }

    @Test("profile-specific settings do not leak between profiles")
    func profileSpecificSettingsDoNotLeakBetweenProfiles() {
        let defaultProfile = MacMenderProfile.default
        var profileA = MacMenderProfile.customCopy(from: defaultProfile, name: "Profile A")
        profileA.dockPreviews.animationStyle = .fade
        profileA.dockPreviews.animationDuration = 0.18
        profileA.middleClick.enabled = false

        var profileB = MacMenderProfile.customCopy(from: defaultProfile, name: "Profile B")
        profileB.dockPreviews.animationStyle = .scale
        profileB.dockPreviews.animationDuration = 0.32
        profileB.middleClick.enabled = true

        var config = AppConfig.default
        config.profiles = [defaultProfile, profileA, profileB]
        config.activeProfileID = profileA.id

        #expect(config.activeProfile.dockPreviews.animationStyle == .fade)
        #expect(config.activeProfile.dockPreviews.animationDuration == 0.18)
        #expect(!config.activeProfile.middleClick.enabled)

        config.setActiveProfile(profileB.id)

        #expect(config.activeProfile.dockPreviews.animationStyle == .scale)
        #expect(config.activeProfile.dockPreviews.animationDuration == 0.32)
        #expect(config.activeProfile.middleClick.enabled)

        var editedProfileB = config.activeProfile
        editedProfileB.dockPreviews.animationStyle = .slideUp
        editedProfileB.middleClick.enabled = false
        config.updateActiveProfile(editedProfileB)

        config.setActiveProfile(profileA.id)

        #expect(config.activeProfile.dockPreviews.animationStyle == .fade)
        #expect(config.activeProfile.dockPreviews.animationDuration == 0.18)
        #expect(!config.activeProfile.middleClick.enabled)
    }

    @Test("menu bar spacing remains app-wide when switching profiles")
    func menuBarSpacingRemainsAppWideWhenSwitchingProfiles() {
        let defaultProfile = MacMenderProfile.default
        let customProfile = MacMenderProfile.customCopy(from: defaultProfile, name: "Work")
        var config = AppConfig.default
        config.profiles = [defaultProfile, customProfile]
        config.activeProfileID = defaultProfile.id
        config.appBehavior.menuBarSpacing = .custom
        config.appBehavior.menuBarSpacingCustomValue = 19

        config.setActiveProfile(customProfile.id)

        #expect(config.activeProfile.id == customProfile.id)
        #expect(config.appBehavior.menuBarSpacing == .custom)
        #expect(config.appBehavior.menuBarSpacingCustomValue == 19)
    }

    @Test("exported config decodes back into app config")
    func exportedConfigDecodesBackIntoAppConfig() throws {
        var config = AppConfig.default
        config.hasCompletedOnboarding = true
        config.appBehavior.menuBarSpacing = .custom
        config.appBehavior.menuBarSpacingCustomValue = 21
        config.createProfile(named: "Studio")

        let data = try ConfigurationFileService.exportData(for: config)
        let imported = try ConfigurationFileService.decodeImportedConfig(from: data)

        #expect(imported == AppConfig.normalizedForStorage(config))
        #expect(imported.profiles.count == 2)
        #expect(imported.appBehavior.menuBarSpacing == .custom)
        #expect(imported.appBehavior.menuBarSpacingCustomValue == 21)
    }

    @Test("import rejects invalid JSON")
    func importRejectsInvalidJSON() {
        do {
            _ = try ConfigurationFileService.decodeImportedConfig(from: Data("{ nope".utf8))
            Issue.record("Invalid JSON should not decode.")
        } catch let error as ConfigurationFileError {
            #expect(error == .invalidJSON)
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("import rejects newer schema")
    func importRejectsNewerSchema() throws {
        let encoded = try JSONEncoder().encode(AppConfig.default)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["schemaVersion"] = AppConfig.default.schemaVersion + 100
        let futureData = try JSONSerialization.data(withJSONObject: object)

        do {
            _ = try ConfigurationFileService.decodeImportedConfig(from: futureData)
            Issue.record("Future schema should not import.")
        } catch let error as ConfigurationFileError {
            #expect(error == .unsupportedSchema(AppConfig.default.schemaVersion + 100))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test("import repairs missing selected profile")
    func importRepairsMissingSelectedProfile() throws {
        let customProfile = MacMenderProfile.customCopy(from: .default, name: "Travel")
        var config = AppConfig.default
        config.profiles = [customProfile]
        config.activeProfileID = UUID()
        let data = try JSONEncoder().encode(config)

        let imported = try ConfigurationFileService.decodeImportedConfig(from: data)

        #expect(imported.profiles == [customProfile])
        #expect(imported.activeProfileID == customProfile.id)
        #expect(imported.activeProfile == customProfile)
    }

    @Test("import ignores permission-shaped JSON")
    func importIgnoresPermissionShapedJSON() throws {
        let encoded = try JSONEncoder().encode(AppConfig.default)
        var object = try #require(JSONSerialization.jsonObject(with: encoded) as? [String: Any])
        object["permissions"] = [
            "accessibility": "granted",
            "screenRecording": "granted",
            "inputMonitoring": "granted"
        ]
        let data = try JSONSerialization.data(withJSONObject: object)

        let imported = try ConfigurationFileService.decodeImportedConfig(from: data)

        #expect(imported == AppConfig.default)
    }

    @Test("menu bar spacing import stores preference without resolving system defaults")
    func menuBarSpacingImportStoresPreferenceWithoutResolvingSystemDefaults() throws {
        var config = AppConfig.default
        config.appBehavior.menuBarSpacing = .wide
        config.appBehavior.menuBarSpacingCustomValue = 27

        let data = try ConfigurationFileService.exportData(for: config)
        let imported = try ConfigurationFileService.decodeImportedConfig(from: data)

        #expect(imported.appBehavior.menuBarSpacing == .wide)
        #expect(imported.appBehavior.menuBarSpacingCustomValue == 27)
        #expect(imported.appBehavior.menuBarSpacing.resolvedDefaultsValue(customValue: imported.appBehavior.menuBarSpacingCustomValue) == 24)
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

    @Test("default menu bar spacing does not write a value")
    func defaultMenuBarSpacingDoesNotWriteValue() {
        let behavior = AppBehavior.default

        #expect(behavior.menuBarSpacing == .systemDefault)
        #expect(behavior.menuBarSpacingCustomValue == MenuBarSpacingPreference.systemDefaultNumericValue)
        #expect(behavior.menuBarSpacing.resolvedDefaultsValue(customValue: behavior.menuBarSpacingCustomValue) == nil)
        #expect(MenuBarSpacingService.defaultsPlan(for: behavior.menuBarSpacing, customValue: behavior.menuBarSpacingCustomValue).operation == .delete)
    }

    @Test("fresh app config starts at system default spacing")
    func freshAppConfigStartsAtSystemDefaultSpacing() {
        let config = AppConfig.default

        #expect(config.appBehavior.menuBarSpacing == .systemDefault)
        #expect(config.appBehavior.menuBarSpacing.resolvedDefaultsValue(customValue: config.appBehavior.menuBarSpacingCustomValue) == nil)
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
