import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        SettingsPage(section: .general) {
            Section("Startup") {
                SettingsToggle(
                    "Open at login",
                    detail: "Start macMender automatically when you sign in to this Mac.",
                    isOn: Binding(
                        get: { appModel.loginItems.launchAtLogin },
                        set: { appModel.loginItems.setLaunchAtLogin($0) }
                    )
                )
                .disabled(!appModel.loginItems.canManageLaunchAtLogin)

                if showsLoginItemStatus {
                    LabeledContent("Status") {
                        Text(appModel.loginItems.statusDescription)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section {
                SettingsToggle(
                    "Show macMender in the Dock",
                    detail: "When off, macMender lives in the menu bar. Open it there, or launch it again to see this window.",
                    isOn: Binding(
                        get: { !appModel.store.config.appBehavior.hideDockIcon },
                        set: { appModel.setHideDockIcon(!$0) }
                    )
                )

                SettingsSlider(
                    title: "Sidebar glass",
                    detail: "How much of what is behind this window shows through its sidebar.",
                    value: Binding(
                        get: { appModel.store.config.appBehavior.sidebarGlass },
                        set: { appModel.setSidebarGlass($0) }
                    ),
                    range: 0...1,
                    step: 0.05,
                    valueLabel: glassLabel,
                    minimumLabel: "Solid",
                    maximumLabel: "Glass"
                )
            } header: {
                Text("Appearance")
            } footer: {
                SettingsFooter("These settings apply to every profile.")
            }

            Section("About") {
                LabeledContent("Version", value: Self.versionDescription)
                Link(destination: URL(string: "https://github.com/0hmslice/macMender/releases")!) {
                    Label("Release notes", systemImage: "arrow.up.forward.square")
                }
                Link(destination: URL(string: "https://github.com/0hmslice/macMender/issues")!) {
                    Label("Report a problem", systemImage: "arrow.up.forward.square")
                }
            }
        }
    }

    /// The login item's state is only worth a row when it disagrees with the switch.
    private var showsLoginItemStatus: Bool {
        let status = appModel.loginItems.statusDescription
        return !["Enabled", "On", "Off", "Disabled", "Not Registered", "Unknown"].contains(status)
            || !appModel.loginItems.canManageLaunchAtLogin
    }

    private var glassLabel: String {
        let amount = appModel.store.config.appBehavior.sidebarGlass
        if amount <= 0.001 { return "Solid" }
        return "\(Int((amount * 100).rounded()))%"
    }

    private static var versionDescription: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "Development build"
        guard let build = info?["CFBundleVersion"] as? String, build != "1" else { return version }
        return "\(version) (\(build))"
    }
}
