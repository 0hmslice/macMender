import AppKit
import Foundation

@MainActor
final class ProfileStore: ObservableObject {
    @Published var config: AppConfig {
        didSet {
            if config != oldValue {
                scheduleAutosave()
            }
        }
    }

    private let fileManager: FileManager
    private let supportDirectoryOverride: URL?
    private var autosaveTask: Task<Void, Never>?
    @Published private(set) var persistenceError: String?

    init(fileManager: FileManager = .default, supportDirectory: URL? = nil) {
        self.fileManager = fileManager
        self.supportDirectoryOverride = supportDirectory
        self.config = .default
        self.config = loadConfig()
    }

    var activeProfile: MacMenderProfile {
        config.activeProfile
    }

    var applicationSupportDirectory: URL {
        if let supportDirectoryOverride { return supportDirectoryOverride }
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("macMender", isDirectory: true)
    }

    var configURL: URL {
        applicationSupportDirectory.appendingPathComponent("config.json")
    }

    func setActiveProfile(_ profileID: UUID) {
        let previousID = config.activeProfileID
        config.setActiveProfile(profileID)
        guard config.activeProfileID != previousID else { return }
        save()
    }

    func updateActiveProfile(_ profile: MacMenderProfile) {
        guard config.activeProfile != profile else { return }
        config.updateActiveProfile(profile)
    }

    func completeOnboarding() {
        config.hasCompletedOnboarding = true
        save()
    }

    func resetToOnboarding() {
        config = .default
        save()
    }

    func createProfile(named name: String) {
        let previousConfig = config
        config.createProfile(named: name)
        guard config != previousConfig else { return }
        save()
    }

    func deleteProfile(_ profileID: UUID) {
        let previousConfig = config
        config.deleteProfile(profileID)
        guard config != previousConfig else { return }
        save()
    }

    func save() {
        autosaveTask?.cancel()
        do {
            try saveToDisk()
        } catch {
            persistenceError = error.localizedDescription
        }
    }

    func saveToDisk() throws {
        try writeConfiguration(config)
    }

    private func writeConfiguration(_ configuration: AppConfig) throws {
        do {
            try fileManager.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
            let data = try ConfigurationFileService.exportData(for: configuration)
            try data.write(to: configURL, options: [.atomic])
            persistenceError = nil
        } catch let error as ConfigurationFileError {
            throw error
        } catch {
            throw ConfigurationFileError.unwritableFile
        }
    }

    func export(to url: URL) throws {
        do {
            let data = try ConfigurationFileService.exportData(for: config)
            try data.write(to: url, options: [.atomic])
        } catch let error as ConfigurationFileError {
            throw error
        } catch {
            throw ConfigurationFileError.unwritableFile
        }
    }

    func previewImport(from url: URL) throws -> ConfigurationImportPreview {
        do {
            let data = try Data(contentsOf: url)
            let imported = try ConfigurationFileService.decodeImportedConfig(from: data)
            return ConfigurationImportPreview(sourceURL: url, config: imported)
        } catch let error as ConfigurationFileError {
            throw error
        } catch {
            throw ConfigurationFileError.unreadableFile
        }
    }

    @discardableResult
    func importConfig(_ preview: ConfigurationImportPreview, createBackup: Bool = true) throws -> URL? {
        let backupURL: URL?
        if createBackup {
            backupURL = try backupCurrentConfig()
        } else {
            backupURL = nil
        }

        let imported = AppConfig.normalizedForStorage(preview.config)
        try writeConfiguration(imported)
        config = imported
        autosaveTask?.cancel()
        return backupURL
    }

    func importConfig(from url: URL) {
        do {
            let preview = try previewImport(from: url)
            try importConfig(preview)
        } catch {
            NSSound.beep()
        }
    }

    func backupCurrentConfig() throws -> URL {
        do {
            try fileManager.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
            let timestamp = Self.backupTimestampFormatter.string(from: Date())
            let backupURL = applicationSupportDirectory
                .appendingPathComponent("config-backup-\(timestamp)-\(UUID().uuidString.prefix(8)).json")
            let data = try ConfigurationFileService.exportData(for: config)
            try data.write(to: backupURL, options: [.atomic])
            return backupURL
        } catch let error as ConfigurationFileError {
            throw error
        } catch {
            throw ConfigurationFileError.backupFailed
        }
    }

    private func loadConfig() -> AppConfig {
        do {
            let data = try Data(contentsOf: configURL)
            let loaded = try ConfigurationFileService.decodeImportedConfig(from: data)
            return loaded
        } catch {
            return .default
        }
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(400))
                try Task.checkCancellation()
                self?.save()
            } catch { /* A newer edit superseded this save. */ }
        }
    }

    private static let backupTimestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}
