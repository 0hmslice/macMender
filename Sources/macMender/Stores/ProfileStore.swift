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
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var autosaveTask: Task<Void, Never>?

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        self.decoder = JSONDecoder()
        self.config = .default
        self.config = loadConfig()
    }

    var activeProfile: MacMenderProfile {
        config.activeProfile
    }

    var applicationSupportDirectory: URL {
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
            try fileManager.createDirectory(at: applicationSupportDirectory, withIntermediateDirectories: true)
            let data = try encoder.encode(config)
            try data.write(to: configURL, options: [.atomic])
        } catch {
            assertionFailure("Failed to save macMender config: \(error)")
        }
    }

    func export(to url: URL) {
        do {
            let data = try encoder.encode(config)
            try data.write(to: url, options: [.atomic])
        } catch {
            NSSound.beep()
        }
    }

    func importConfig(from url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let imported = try decoder.decode(AppConfig.self, from: data)
            config = sanitize(migrate(imported))
            save()
        } catch {
            NSSound.beep()
        }
    }

    private func loadConfig() -> AppConfig {
        do {
            let data = try Data(contentsOf: configURL)
            let loaded = try decoder.decode(AppConfig.self, from: data)
            return sanitize(migrate(loaded))
        } catch {
            return .default
        }
    }

    private func migrate(_ loaded: AppConfig) -> AppConfig {
        var migrated = loaded
        if loaded.schemaVersion < 3 {
            migrated.profiles = migrated.profiles.map { profile in
                var profile = profile
                profile.windowSwitcher.layout = .grid
                profile.dockPreviews.layout = .grid
                profile.dockPreviews.thumbnailSize = min(profile.dockPreviews.thumbnailSize, DockPreviewSettings.default.thumbnailSize)
                return profile
            }
        }
        migrated.schemaVersion = AppConfig.default.schemaVersion
        return migrated
    }

    private func sanitize(_ loaded: AppConfig) -> AppConfig {
        var sanitized = loaded
        sanitized.profiles = sanitized.profiles.map { profile in
            var profile = profile
            if profile.middleClick.action == .customShortcut {
                profile.middleClick.action = .middleClick
            }
            profile.dockPreviews.previewIdleTimeout = DockPreviewSettings.clampedPreviewIdleTimeout(profile.dockPreviews.previewIdleTimeout)
            profile.dockPreviews.animationDuration = DockPreviewSettings.clampedAnimationDuration(profile.dockPreviews.animationDuration)
            return profile
        }
        sanitized.ensureValidProfileSelection()
        return sanitized
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(400))
            await MainActor.run {
                self?.save()
            }
        }
    }
}
