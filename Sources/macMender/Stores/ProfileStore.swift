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
        config.profiles.first(where: { $0.id == config.activeProfileID }) ?? MacMenderProfile.default
    }

    var applicationSupportDirectory: URL {
        let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("macMender", isDirectory: true)
    }

    var configURL: URL {
        applicationSupportDirectory.appendingPathComponent("config.json")
    }

    func setActiveProfile(_ profileID: UUID) {
        guard config.profiles.contains(where: { $0.id == profileID }) else { return }
        config.activeProfileID = profileID
        save()
    }

    func updateActiveProfile(_ profile: MacMenderProfile) {
        guard let index = config.profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        guard config.profiles[index] != profile else { return }
        config.profiles[index] = profile
    }

    func setMenuBarSection(itemKey: String, title: String, section: MenuBarSection, before beforeKey: String? = nil) {
        config.menuBarLayout.setMenuBarItemSection(itemKey: itemKey, title: title, section: section, before: beforeKey)
        save()
    }

    func rememberMenuBarItems(_ items: [DetectedMenuBarItem], resolvesVisibleConflicts: Bool) {
        let previousLayout = config.menuBarLayout
        let liveOrderItems = items
            .filter(\.isHideCandidate)
            .map { item in
                MenuBarLiveOrderItem(
                    key: item.sectionKey,
                    title: item.displayTitle,
                    section: config.menuBarLayout.resolvedSectionForLiveSync(
                        itemKey: item.sectionKey,
                        actualSection: item.actualSection,
                        resolvesVisibleConflicts: resolvesVisibleConflicts
                    )
                )
            }
        config.menuBarLayout.syncLiveMenuBarItems(liveOrderItems)

        if config.menuBarLayout != previousLayout {
            save()
        }
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
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        let profile = MacMenderProfile.customCopy(from: activeProfile, name: trimmedName)
        config.profiles.append(profile)
        config.activeProfileID = profile.id
        save()
    }

    func deleteProfile(_ profileID: UUID) {
        guard config.profiles.count > 1,
              profileID != MacMenderProfile.default.id,
              let index = config.profiles.firstIndex(where: { $0.id == profileID }) else {
            return
        }

        config.profiles.remove(at: index)
        if config.activeProfileID == profileID {
            config.activeProfileID = MacMenderProfile.default.id
        }

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
        if loaded.schemaVersion < 4 {
            migrated.menuBarLayout.showSectionDividers = false
        }
        migrated.schemaVersion = AppConfig.default.schemaVersion
        return migrated
    }

    private func sanitize(_ loaded: AppConfig) -> AppConfig {
        var sanitized = loaded
        sanitized.menuBarLayout.items.removeAll {
            $0.bundleIdentifier == "com.example.utility" || $0.title == "Example Utility"
        }
        sanitized.profiles = sanitized.profiles.map { profile in
            var profile = profile
            if profile.middleClick.action == .customShortcut {
                profile.middleClick.action = .middleClick
            }
            profile.dockPreviews.previewIdleTimeout = DockPreviewSettings.clampedPreviewIdleTimeout(profile.dockPreviews.previewIdleTimeout)
            profile.dockPreviews.animationDuration = DockPreviewSettings.clampedAnimationDuration(profile.dockPreviews.animationDuration)
            return profile
        }
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
