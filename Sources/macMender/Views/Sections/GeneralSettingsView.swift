import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var appModel: AppModel
    @State private var pendingMenuBarSpacing: MenuBarSpacingPreference?

    var body: some View {
        PreferencesScrollView {
            MendySectionHeader(
                section: .general,
                title: "General",
                subtitle: "Startup and app-window behavior live here, separate from privacy permissions."
            )

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

            SectionCard(
                title: "Menu Bar Spacing",
                subtitle: "Adjust the spacing between menu bar icons.",
                symbolName: "menubar.rectangle"
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Spacing", selection: spacingSelection) {
                        ForEach(MenuBarSpacingPreference.allCases) { preference in
                            Text(preference.title).tag(preference)
                        }
                    }
                    .pickerStyle(.segmented)
                    .disabled(appModel.menuBarSpacing.isApplying)

                    Text("This changes the system spacing preference for menu bar items. It does not move, hide, reorder, reveal, or manage individual icons.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack {
                        Button {
                            appModel.applyMenuBarSpacing(spacingSelection.wrappedValue)
                        } label: {
                            Label("Apply", systemImage: "checkmark.circle")
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(appModel.menuBarSpacing.isApplying)

                        Button {
                            pendingMenuBarSpacing = .systemDefault
                            appModel.applyMenuBarSpacing(.systemDefault)
                        } label: {
                            Label("Reset to Default", systemImage: "arrow.counterclockwise")
                        }
                        .buttonStyle(.bordered)
                        .disabled(appModel.menuBarSpacing.isApplying)

                        Spacer(minLength: 0)
                    }

                    Text(appModel.menuBarSpacing.statusDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text("Some menu bar apps may need to relaunch, or you may need to log out, before spacing fully updates.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            pendingMenuBarSpacing = appModel.store.config.appBehavior.menuBarSpacing
        }
    }

    private var spacingSelection: Binding<MenuBarSpacingPreference> {
        Binding(
            get: { pendingMenuBarSpacing ?? appModel.store.config.appBehavior.menuBarSpacing },
            set: { pendingMenuBarSpacing = $0 }
        )
    }
}
