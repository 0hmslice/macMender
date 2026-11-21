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
                .frame(minWidth: 860, minHeight: 600)
                .onAppear {
                    appModel.markFirstWindowReady()
                    let showSettings = {
                        if !appModel.focusPreferencesWindow() {
                            openWindow(id: "preferences")
                        }
                        appModel.activateApp()
                    }
                    statusItemController.install(appModel: appModel, openPreferences: showSettings)
                    appDelegate.showSettings = showSettings
                    #if DEBUG
                    appModel.debugShowPopover = { statusItemController.showPopover() }
                    #endif
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
                Button("Quick Controls") {
                    statusItemController.showPopover()
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])

                Divider()

                Button(appModel.store.config.safeModeEnabled ? "Resume macMender" : "Pause macMender") {
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

    /// Shows the settings window; set once the first window has appeared.
    @MainActor var showSettings: (() -> Void)?

    /// Opening the app again while it runs (Spotlight, Finder, Launchpad) shows its settings.
    /// Without this, a second launch does nothing visible when the Dock icon is hidden.
    @MainActor
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        guard let showSettings else { return true }
        showSettings()
        return false
    }

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
        logger.info("Launch identity bundleIdentifier=\(bundle.bundleIdentifier ?? "nil", privacy: .private) bundlePath=\(bundlePath, privacy: .private) isAppBundle=\(isAppBundle, privacy: .public)")
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
            menuBarSpacing: MenuBarSpacingPreference(rawValue: appBehavior["menuBarSpacing"] as? String ?? "") ?? .systemDefault,
            menuBarSpacingCustomValue: appBehavior["menuBarSpacingCustomValue"] as? Int ??
                AppBehavior.default.menuBarSpacingCustomValue
        )
    }
}
