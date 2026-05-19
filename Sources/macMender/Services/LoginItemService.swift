import AppKit
import Foundation
import ServiceManagement

@MainActor
final class LoginItemService: ObservableObject {
    @Published private(set) var statusDescription = "Unknown"
    @Published private(set) var canManageLaunchAtLogin = true
    @Published var launchAtLogin = false

    private let fileManager: FileManager
    private let launchAgentLabel = "com.ryan.macMender.login"

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    var launchAgentURL: URL {
        fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(launchAgentLabel).plist")
    }

    func refresh() {
        let status = SMAppService.mainApp.status
        let launchAgentEnabled = isLaunchAgentEnabled
        launchAtLogin = status == .enabled || launchAgentEnabled
        canManageLaunchAtLogin = true
        statusDescription = switch status {
        case .enabled: "Enabled"
        case .notRegistered: launchAgentEnabled ? "Enabled" : "Off"
        case .requiresApproval: launchAgentEnabled ? "Enabled" : "Needs Approval"
        case .notFound: launchAgentEnabled ? "Enabled" : "Off"
        @unknown default: "Unknown"
        }
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if SMAppService.mainApp.status == .notFound {
                try setLaunchAgent(enabled)
            } else {
                if enabled {
                    try removeLaunchAgent()
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                    try removeLaunchAgent()
                }
            }
        } catch {
            NSSound.beep()
        }
        refresh()
    }

    private var isLaunchAgentEnabled: Bool {
        guard let plist = launchAgentPlist else { return false }
        let arguments = plist["ProgramArguments"] as? [String] ?? []
        return arguments.contains(Bundle.main.bundlePath)
    }

    private var launchAgentPlist: [String: Any]? {
        guard let data = try? Data(contentsOf: launchAgentURL),
              let object = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return nil
        }
        return object
    }

    private func setLaunchAgent(_ enabled: Bool) throws {
        if enabled {
            try installLaunchAgent()
        } else {
            try removeLaunchAgent()
        }
    }

    private func installLaunchAgent() throws {
        try fileManager.createDirectory(
            at: launchAgentURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try PropertyListSerialization.data(
            fromPropertyList: Self.launchAgentPlist(label: launchAgentLabel, appPath: Bundle.main.bundlePath),
            format: .xml,
            options: 0
        )
        try data.write(to: launchAgentURL, options: [.atomic])
    }

    private func removeLaunchAgent() throws {
        guard fileManager.fileExists(atPath: launchAgentURL.path) else { return }
        try fileManager.removeItem(at: launchAgentURL)
    }

    nonisolated static func launchAgentPlist(label: String, appPath: String) -> [String: Any] {
        [
            "Label": label,
            "ProgramArguments": [
                "/usr/bin/open",
                "-n",
                appPath
            ],
            "RunAtLoad": true,
            "LimitLoadToSessionType": "Aqua"
        ]
    }
}
