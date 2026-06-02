import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        PreferencesScrollView {
            SectionCard(
                title: "App Startup",
                subtitle: "Choose how macMender appears when you sign in.",
                symbolName: "power"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Launch macMender at login", isOn: Binding(
                        get: { appModel.loginItems.launchAtLogin },
                        set: { appModel.loginItems.setLaunchAtLogin($0) }
                    ))
                    .disabled(!appModel.loginItems.canManageLaunchAtLogin)

                    Text(appModel.loginItems.statusDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            SectionCard(
                title: "Dock Icon",
                subtitle: "The menu bar control center remains available either way.",
                symbolName: "dock.rectangle"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle("Hide Dock icon while running", isOn: Binding(
                        get: { appModel.store.config.appBehavior.hideDockIcon },
                        set: { appModel.setHideDockIcon($0) }
                    ))

                    Text("When hidden, use the macMender menu bar icon to open Settings or quit the app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
