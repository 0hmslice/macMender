import SwiftUI

struct PrivacyPermissionsView: View {
    @ObservedObject var appModel: AppModel
    @State private var showingResetConfirmation = false

    var body: some View {
        PreferencesScrollView {
            SectionCard(title: "Privacy Promise", subtitle: "macMender is designed to run without analytics, tracking, or remote APIs.", symbolName: "hand.raised") {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                    PrivacyPromiseRow(title: "Analytics", value: "None")
                    PrivacyPromiseRow(title: "Tracking", value: "None")
                    PrivacyPromiseRow(title: "Remote APIs", value: "None by default")
                    PrivacyPromiseRow(title: "Configuration", value: appModel.store.configURL.path)
                }
            }

            PermissionCard(
                title: "Accessibility",
                subtitle: "Required for event taps, middle-click posting, global shortcuts, and window actions.",
                symbolName: "accessibility",
                state: appModel.permissions.accessibility,
                primaryActionTitle: "Request Access",
                secondaryActionTitle: "Open Settings",
                primaryAction: { appModel.permissions.requestAccessibility() },
                secondaryAction: { appModel.permissions.openAccessibilitySettings() }
            )

            PermissionCard(
                title: "Screen Recording",
                subtitle: "Optional. Used only to show live window thumbnails in switcher previews.",
                symbolName: "rectangle.on.rectangle",
                state: appModel.permissions.screenRecording,
                primaryActionTitle: "Request Access",
                secondaryActionTitle: "Open Settings",
                primaryAction: { appModel.permissions.requestScreenRecording() },
                secondaryAction: { appModel.permissions.openScreenRecordingSettings() }
            )

            SectionCard(title: "Launch at Login", subtitle: "Starts macMender automatically using the best available per-user macOS login mechanism.", symbolName: "power") {
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
            HStack(spacing: 12) {
                MendyAvatarView(mood: state == .granted ? .success : .alert, size: 46)
                CapabilityBadge(
                    title: state.title,
                    systemImage: state == .granted ? "checkmark.circle.fill" : "exclamationmark.circle",
                    tone: state == .granted ? .active : .warning
                )
                Spacer()
                Button(primaryActionTitle, action: primaryAction)
                Button(secondaryActionTitle, action: secondaryAction)
            }
        }
    }
}
