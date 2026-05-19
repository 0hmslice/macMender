import Foundation

@MainActor
final class DockPreferencesService: ObservableObject {
    @Published private(set) var currentSettings = DockSettings.work
    @Published private(set) var lastReadDescription = "Not read yet"
    @Published private(set) var lastApplyDescription = "No Dock changes applied"

    private let dockDefaults = UserDefaults(suiteName: "com.apple.dock")

    func refresh() {
        guard let dockDefaults else {
            lastReadDescription = "Dock preferences unavailable"
            return
        }

        currentSettings = DockSettings(
            size: dockDefaults.object(forKey: "tilesize") as? Double ?? 52,
            magnificationEnabled: dockDefaults.object(forKey: "magnification") as? Bool ?? false,
            magnificationSize: dockDefaults.object(forKey: "largesize") as? Double ?? 64,
            position: DockPosition(rawValue: dockDefaults.string(forKey: "orientation") ?? "bottom") ?? .bottom,
            autoHide: dockDefaults.object(forKey: "autohide") as? Bool ?? false,
            autoHideDelay: dockDefaults.object(forKey: "autohide-delay") as? Double ?? 0.2,
            autoHideAnimationSpeed: dockDefaults.object(forKey: "autohide-time-modifier") as? Double ?? 0.35,
            showRecentApps: dockDefaults.object(forKey: "show-recents") as? Bool ?? true,
            showIndicators: dockDefaults.object(forKey: "show-process-indicators") as? Bool ?? true
        )
        lastReadDescription = "Read current Dock preferences"
    }

    func diff(from current: DockSettings, to target: DockSettings) -> [String] {
        var changes: [String] = []
        appendDiff(&changes, "Size", current.size, target.size)
        appendDiff(&changes, "Magnification", current.magnificationEnabled, target.magnificationEnabled)
        appendDiff(&changes, "Magnification size", current.magnificationSize, target.magnificationSize)
        appendDiff(&changes, "Position", current.position.title, target.position.title)
        appendDiff(&changes, "Auto-hide", current.autoHide, target.autoHide)
        appendDiff(&changes, "Auto-hide delay", current.autoHideDelay, target.autoHideDelay)
        appendDiff(&changes, "Animation speed", current.autoHideAnimationSpeed, target.autoHideAnimationSpeed)
        appendDiff(&changes, "Recent apps", current.showRecentApps, target.showRecentApps)
        appendDiff(&changes, "Open indicators", current.showIndicators, target.showIndicators)
        return changes
    }

    func apply(_ settings: DockSettings) {
        guard let dockDefaults else {
            lastApplyDescription = "Dock preferences unavailable"
            return
        }

        dockDefaults.set(settings.size, forKey: "tilesize")
        dockDefaults.set(settings.magnificationEnabled, forKey: "magnification")
        dockDefaults.set(settings.magnificationSize, forKey: "largesize")
        dockDefaults.set(settings.position.rawValue, forKey: "orientation")
        dockDefaults.set(settings.autoHide, forKey: "autohide")
        dockDefaults.set(settings.autoHideDelay, forKey: "autohide-delay")
        dockDefaults.set(settings.autoHideAnimationSpeed, forKey: "autohide-time-modifier")
        dockDefaults.set(settings.showRecentApps, forKey: "show-recents")
        dockDefaults.set(settings.showIndicators, forKey: "show-process-indicators")
        dockDefaults.synchronize()
        restartDock()
        currentSettings = settings
        lastApplyDescription = "Applied Dock profile and restarted Dock"
    }

    func resetToMacOSDefaults() {
        guard let dockDefaults else {
            lastApplyDescription = "Dock preferences unavailable"
            return
        }

        [
            "tilesize",
            "magnification",
            "largesize",
            "orientation",
            "autohide",
            "autohide-delay",
            "autohide-time-modifier",
            "show-recents",
            "show-process-indicators",
            "static-only"
        ].forEach { dockDefaults.removeObject(forKey: $0) }

        dockDefaults.synchronize()
        restartDock()
        refresh()
        lastApplyDescription = "Reset Dock preferences and restarted Dock"
    }

    private func restartDock() {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
        process.arguments = ["Dock"]
        try? process.run()
    }

    private func appendDiff<T: Equatable>(_ changes: inout [String], _ label: String, _ oldValue: T, _ newValue: T) {
        if oldValue != newValue {
            changes.append("\(label): \(oldValue) -> \(newValue)")
        }
    }

    private func appendDiff(_ changes: inout [String], _ label: String, _ oldValue: Double, _ newValue: Double) {
        guard abs(oldValue - newValue) >= 0.005 else { return }
        changes.append("\(label): \(format(oldValue)) -> \(format(newValue))")
    }

    private func format(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
    }
}
