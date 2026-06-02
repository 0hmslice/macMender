import SwiftUI

struct PrivacyPermissionsView: View {
    @ObservedObject var appModel: AppModel
    @State private var showingResetConfirmation = false

    var body: some View {
        PreferencesScrollView {
            SectionCard(title: "Privacy Promise", subtitle: "macMender runs locally and only asks for access a feature needs.", symbolName: "hand.raised") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        CapabilityBadge(title: "No analytics", systemImage: "chart.bar.xaxis", tone: .active)
                        CapabilityBadge(title: "No tracking", systemImage: "eye.slash", tone: .active)
                        CapabilityBadge(title: "Local settings", systemImage: "externaldrive", tone: .neutral)
                        Spacer()
                    }

                    DisclosureGroup("Local details") {
                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                            PrivacyPromiseRow(title: "Remote APIs", value: "None by default")
                            PrivacyPromiseRow(title: "Configuration", value: appModel.store.configURL.path)
                        }
                        .padding(.top, 6)
                    }
                    .font(.callout)
                }
            }

            PermissionCard(
                title: "Accessibility",
                subtitle: "Required for global shortcuts, input handling, and selecting windows.",
                symbolName: "accessibility",
                state: appModel.permissions.accessibility,
                primaryActionTitle: "Request Access",
                secondaryActionTitle: "Open System Settings",
                primaryAction: { appModel.permissions.requestAccessibility() },
                secondaryAction: { appModel.permissions.openAccessibilitySettings() }
            )

            PermissionCard(
                title: "Screen Recording",
                subtitle: "Optional. Used only for live window thumbnails in previews.",
                symbolName: "rectangle.on.rectangle",
                state: appModel.permissions.screenRecording,
                primaryActionTitle: "Request Access",
                secondaryActionTitle: "Open System Settings",
                primaryAction: { appModel.permissions.requestScreenRecording() },
                secondaryAction: { appModel.permissions.openScreenRecordingSettings() }
            )

            SectionCard(
                title: "Input Monitoring",
                subtitle: "Open this only if macOS asks for it.",
                symbolName: "keyboard"
            ) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        CapabilityBadge(title: "Open Settings if prompted", systemImage: "keyboard.badge.eye", tone: .neutral)
                        Text("If macMender is missing, add it with + or drag in the app when macOS allows it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    Button("Open Input Monitoring") {
                        appModel.permissions.openInputMonitoringSettings()
                    }
                }
            }

            SectionCard(title: "Launch at Login", subtitle: "Start macMender automatically.", symbolName: "power") {
                Toggle("Launch macMender at login", isOn: Binding(
                    get: { appModel.loginItems.launchAtLogin },
                    set: { appModel.loginItems.setLaunchAtLogin($0) }
                ))
                .disabled(!appModel.loginItems.canManageLaunchAtLogin)
                Text(appModel.loginItems.statusDescription)
                    .foregroundStyle(.secondary)
            }

            SectionCard(title: "Dock Icon", subtitle: "Keep macMender out of the Dock while it continues running from the menu bar.", symbolName: "dock.rectangle") {
                Toggle("Hide Dock icon while running", isOn: Binding(
                    get: { appModel.store.config.appBehavior.hideDockIcon },
                    set: { appModel.setHideDockIcon($0) }
                ))
                Text("When hidden, use the macMender menu bar icon to open Settings or quit the app.")
                    .foregroundStyle(.secondary)
            }

            SectionCard(title: "Start Over", subtitle: "Reset local settings and show onboarding again on next launch.", symbolName: "arrow.counterclockwise") {
                HStack {
                    Text("This clears macMender's local configuration and returns to the first-run setup flow.")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Reset to Onboarding", role: .destructive) {
                        showingResetConfirmation = true
                    }
                }
            }
        }
        .confirmationDialog("Reset macMender?", isPresented: $showingResetConfirmation) {
            Button("Reset to Onboarding", role: .destructive) {
                appModel.resetToOnboarding()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This resets local macMender settings and returns the app to onboarding.")
        }
    }
}

private struct PrivacyPromiseRow: View {
    var title: String
    var value: String

    var body: some View {
        GridRow {
            Text(title)
            Text(value)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}

private struct PermissionCard: View {
    var title: String
    var subtitle: String
    var symbolName: String
    var state: PermissionState
    var primaryActionTitle: String
    var secondaryActionTitle: String
    var primaryAction: () -> Void
    var secondaryAction: () -> Void

    var body: some View {
        SectionCard(title: title, subtitle: subtitle, symbolName: symbolName) {
            HStack(alignment: .center, spacing: 12) {
                CapabilityBadge(
                    title: state.title,
                    systemImage: state == .granted ? "checkmark.circle.fill" : "exclamationmark.circle",
                    tone: state == .granted ? .active : .warning
                )
                Spacer()
                HStack(spacing: 8) {
                    if state != .granted {
                        Button(primaryActionTitle, action: primaryAction)
                    }
                    Button(secondaryActionTitle, action: secondaryAction)
                }
            }
            .padding(10)
            .liquidGlass(.row)
        }
    }
}
