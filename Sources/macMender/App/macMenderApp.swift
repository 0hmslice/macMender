import AppKit
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
                    statusItemController.install(appModel: appModel) {
                        if !appModel.focusPreferencesWindow() {
                            openWindow(id: "preferences")
                        }
                        appModel.activateApp()
                    }
                    appModel.refreshSystemState()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    appModel.refreshSystemState()
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
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        DispatchQueue.main.async {
            NSApp.windows.first?.makeKeyAndOrderFront(nil)
        }
    }
}
