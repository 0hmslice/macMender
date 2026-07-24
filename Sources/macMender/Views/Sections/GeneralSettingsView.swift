import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        Form {
            Section {
                Label("These settings apply to every profile.", systemImage: "info.circle")
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("Launch macMender at login", isOn: Binding(
                    get: { appModel.loginItems.launchAtLogin },
                    set: { appModel.loginItems.setLaunchAtLogin($0) }
                ))
                .disabled(!appModel.loginItems.canManageLaunchAtLogin)

                LabeledContent("Current status", value: appModel.loginItems.statusDescription)
                    .foregroundStyle(.secondary)
            } header: {
                Label("Startup", systemImage: "power")
            } footer: {
                Text("Start macMender automatically when you sign in to this Mac.")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            Section {
                Toggle("Hide Dock icon while running", isOn: Binding(
                    get: { appModel.store.config.appBehavior.hideDockIcon },
                    set: { appModel.setHideDockIcon($0) }
                ))
            } header: {
                Label("App Presence", systemImage: "dock.rectangle")
            } footer: {
                Text("When the Dock icon is hidden, use the macMender menu bar item to open the app or quit.")
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: 760)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
