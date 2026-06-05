import AppKit
import os
import SwiftUI

@main
struct MacMenderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @Environment(\.openWindow) private var openWindow
    @StateObject private var appModel = AppModel()
    @State private var statusItemController = MacMenderStatusItemController()

    var body: some Scene {
        WindowGroup("macMender", id: "preferences") {
            PreferencesWindow(appModel: appModel)
                .frame(minWidth: 980, minHeight: 680)
                .onAppear {
                    appModel.markFirstWindowReady()
                    statusItemController.install(appModel: appModel) {
                        if !appModel.focusPreferencesWindow() {
                            openWindow(id: "preferences")
                        }
                        appModel.activateApp()
                    }
                    Task { @MainActor in
                        try? await Task.sleep(for: .milliseconds(250))
                        appModel.startRuntimeIfNeeded()
                    }
                }
        }
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    if !appModel.focusPreferencesWindow() {
                        openWindow(id: "preferences")
                    }
                    appModel.activateApp()
                }
                .keyboardShortcut(",", modifiers: .command)
            }

            CommandMenu("macMender") {
                Button(appModel.store.config.safeModeEnabled ? "Disable Safe Mode" : "Enable Safe Mode") {
                    appModel.toggleSafeMode()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Divider()

                Button("Export Configuration...") {
                    appModel.exportConfiguration()
                }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.ryan.macMender", category: "Startup")

    func applicationDidFinishLaunching(_ notification: Notification) {
        logLaunchIdentity()
        let launchBehavior = MacMenderLaunchBehavior.load()
        NSApp.setActivationPolicy(launchBehavior.hideDockIcon ? .accessory : .regular)
        guard !launchBehavior.hideDockIcon else { return }

        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }

    private func logLaunchIdentity() {
        let bundle = Bundle.main
        let bundlePath = bundle.bundlePath
        let isAppBundle = bundlePath.hasSuffix(".app")
        logger.info("Launch identity bundleIdentifier=\(bundle.bundleIdentifier ?? "nil", privacy: .public) bundlePath=\(bundlePath, privacy: .public) isAppBundle=\(isAppBundle, privacy: .public)")
    }
}

private enum MacMenderLaunchBehavior {
    static func load(fileManager: FileManager = .default) -> AppBehavior {
        guard let supportDirectory = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return .default
        }

        let configURL = supportDirectory
            .appendingPathComponent("macMender", isDirectory: true)
            .appendingPathComponent("config.json")

        guard let data = try? Data(contentsOf: configURL),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let appBehavior = object["appBehavior"] as? [String: Any] else {
            return .default
        }

        return AppBehavior(
            hideDockIcon: appBehavior["hideDockIcon"] as? Bool ?? AppBehavior.default.hideDockIcon,
            menuBarSpacing: MenuBarSpacingPreference(rawValue: appBehavior["menuBarSpacing"] as? String ?? "") ?? .systemDefault
        )
    }
}
