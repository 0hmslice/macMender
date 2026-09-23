import Foundation
import Testing
@testable import macMender

struct ConfigurationTests {
    @Test func oldAppRulesDefaultToEnabledCustomization() throws {
        let data = Data("""
        {"id":"1BA904A0-5404-47F1-9349-A9B5F101C001","bundleIdentifier":"com.apple.Terminal","appName":"Terminal","smoothingOverride":false}
        """.utf8)
        let rule = try JSONDecoder().decode(AppScrollRule.self, from: data)
        #expect(!rule.bypassScrolling)
        #expect(rule.smoothingOverride == false)
        #expect(rule.reverseHorizontalOverride == nil)
    }

    @Test func schemaFiveRoundTripsWithoutLosingRules() throws {
        var config = AppConfig.default
        config.schemaVersion = 5
        config.profiles[0].scroll.appRules[0].bypassScrolling = true
        let result = try ConfigurationFileService.decodeImportedConfig(from: ConfigurationFileService.exportData(for: config))
        #expect(result.schemaVersion == 6)
        #expect(result.activeProfile.scroll.appRules[0].bypassScrolling)
        #expect(result.activeProfileID == config.activeProfileID)
    }

    @Test func importedNumericValuesAreBounded() {
        var settings = ScrollSettings.balanced
        settings.duration = 1e90
        settings.gain = -1e90
        settings.step = .infinity
        settings.normalize()
        #expect(settings.duration == 0.5)
        #expect(settings.gain == 0.5)
        #expect(settings.step == 1)
    }

    @Test func futureSchemaIsRejected() throws {
        var config = AppConfig.default
        config.schemaVersion = 100
        let data = try ConfigurationFileService.exportData(for: config)
        #expect(throws: ConfigurationFileError.unsupportedSchema(100)) {
            try ConfigurationFileService.decodeImportedConfig(from: data)
        }
    }
}

@MainActor
struct ProfilePersistenceTests {
    @Test func rapidEditsDebounceWithoutSavingCancelledTasks() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProfileStore(supportDirectory: directory)
        for index in 0..<30 { store.config.profiles[0].name = "Edit \(index)" }
        try await Task.sleep(for: .milliseconds(60))
        #expect(!FileManager.default.fileExists(atPath: store.configURL.path))
        try await Task.sleep(for: .milliseconds(500))
        let saved = try ConfigurationFileService.decodeImportedConfig(from: Data(contentsOf: store.configURL))
        #expect(saved.activeProfile.name == "Edit 29")
        #expect(store.persistenceError == nil)
    }

    @Test func backupIncludesPendingEdits() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = ProfileStore(supportDirectory: directory)
        store.save()
        store.config.profiles[0].name = "Unsaved edit"
        let backup = try store.backupCurrentConfig()
        let saved = try ConfigurationFileService.decodeImportedConfig(from: Data(contentsOf: backup))
        #expect(saved.activeProfile.name == "Unsaved edit")
        store.save()
    }

    @Test func failedImportPreservesInMemoryConfiguration() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        // A regular file cannot be the store's parent directory.
        try Data().write(to: directory)
        let store = ProfileStore(supportDirectory: directory)
        let original = store.config
        var replacement = original
        replacement.profiles[0].name = "Replacement"
        let preview = ConfigurationImportPreview(sourceURL: directory, config: replacement)
        #expect(throws: ConfigurationFileError.unwritableFile) {
            try store.importConfig(preview, createBackup: false)
        }
        #expect(store.config == original)
        store.save()
        #expect(store.persistenceError != nil)
    }
}
