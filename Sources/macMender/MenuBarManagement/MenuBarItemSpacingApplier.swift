import AppKit
import Foundation

/// Applies Ice-style menu bar item spacing by writing the private global
/// defaults and relaunching status-item owners so AppKit reads the new values.
@MainActor
final class MenuBarItemSpacingApplier {
    struct Result: Equatable {
        var didWriteDefaults: Bool
        var relaunchedAppCount: Int
        var failedAppNames: [String]

        var description: String {
            if !didWriteDefaults {
                return "Spacing already matches this value"
            }
            let relaunchPart = relaunchedAppCount == 1 ? "relaunched 1 app" : "relaunched \(relaunchedAppCount) apps"
            if failedAppNames.isEmpty {
                return "Spacing applied; \(relaunchPart)"
            }
            return "Spacing applied; \(relaunchPart), \(failedAppNames.count) app(s) may need relaunch"
        }
    }

    private enum Key: String {
        case spacing = "NSStatusItemSpacing"
        case padding = "NSStatusItemSelectionPadding"

        var defaultValue: Int { 16 }
    }

    private let discovery = MenuBarItemDiscovery()
    private let forceTerminateDelay: Duration = .seconds(1)

    func apply(offset rawOffset: Int) async -> Result {
        let offset = max(-16, min(16, rawOffset))
        let didWrite = (currentlyAppliedValue(for: .spacing) != Key.spacing.defaultValue + offset) ||
            (currentlyAppliedValue(for: .padding) != Key.padding.defaultValue + offset)

        do {
            if offset == 0 {
                try await removeValue(for: .spacing)
                try await removeValue(for: .padding)
            } else {
                try await setOffset(offset, for: .spacing)
                try await setOffset(offset, for: .padding)
            }
        } catch {
            return Result(didWriteDefaults: false, relaunchedAppCount: 0, failedAppNames: ["defaults"])
        }

        guard didWrite else {
            return Result(didWriteDefaults: false, relaunchedAppCount: 0, failedAppNames: [])
        }

        try? await Task.sleep(for: .milliseconds(100))
        let pids = Set(discovery.items(onScreenOnly: false, activeSpaceOnly: true).map(\.ownerPID))
        var relaunched = 0
        var failed = [String]()

        for pid in pids {
            guard let app = NSRunningApplication(processIdentifier: pid),
                  app != .current else {
                continue
            }
            if app.bundleIdentifier == "com.apple.controlcenter" {
                continue
            }
            do {
                try await relaunchApp(app)
                relaunched += 1
            } catch {
                failed.append(displayName(for: app))
            }
        }

        if let controlCenter = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.controlcenter").first {
            do {
                try await signalAppToQuit(controlCenter)
                relaunched += 1
            } catch {
                failed.append(displayName(for: controlCenter))
            }
        }

        return Result(didWriteDefaults: true, relaunchedAppCount: relaunched, failedAppNames: failed)
    }

    private func currentlyAppliedValue(for key: Key) -> Int {
        let value = CFPreferencesCopyValue(
            key.rawValue as CFString,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        ) as? Int
        return value ?? key.defaultValue
    }

    private func removeValue(for key: Key) async throws {
        try await runDefaults(["-currentHost", "delete", "-globalDomain", key.rawValue])
    }

    private func setOffset(_ offset: Int, for key: Key) async throws {
        try await runDefaults(["-currentHost", "write", "-globalDomain", key.rawValue, "-int", "\(key.defaultValue + offset)"])
    }

    private nonisolated func runDefaults(_ arguments: [String]) async throws {
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            process.arguments = arguments
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 {
                throw CocoaError(.fileWriteUnknown)
            }
        }.value
    }

    private func relaunchApp(_ app: NSRunningApplication) async throws {
        struct RelaunchError: Error {}
        guard let url = app.bundleURL,
              let bundleIdentifier = app.bundleIdentifier else {
            throw RelaunchError()
        }
        try await signalAppToQuit(app)
        if app.isTerminated {
            try await launchApp(at: url, bundleIdentifier: bundleIdentifier)
        } else {
            throw RelaunchError()
        }
    }

    private func signalAppToQuit(_ app: NSRunningApplication) async throws {
        if app.isTerminated { return }
        app.terminate()
        let deadline = ContinuousClock.now.advanced(by: forceTerminateDelay)
        while !app.isTerminated, ContinuousClock.now < deadline {
            try await Task.sleep(for: .milliseconds(50))
        }
        if !app.isTerminated {
            app.forceTerminate()
            try await Task.sleep(for: .milliseconds(300))
        }
        if !app.isTerminated {
            throw CocoaError(.userCancelled)
        }
    }

    private func launchApp(at url: URL, bundleIdentifier: String) async throws {
        if NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).contains(where: { !$0.isTerminated }) {
            return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = false
        configuration.addsToRecentItems = false
        configuration.createsNewApplicationInstance = false
        configuration.promptsUserIfNeeded = false
        try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    private func displayName(for app: NSRunningApplication) -> String {
        app.localizedName ?? app.bundleIdentifier ?? "Unknown"
    }
}
