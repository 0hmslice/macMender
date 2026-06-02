import SwiftUI

struct PrivacyPermissionsView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        PreferencesScrollView {
            SectionCard(title: "macMender runs locally.", subtitle: "No analytics. No tracking. No remote APIs by default.", symbolName: "hand.raised") {
                HStack(alignment: .top, spacing: 16) {
                    MendyAvatarView(
                        mood: appModel.permissions.needsAttention ? .thinking : .success,
                        size: MendyAvatarSize.panel
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Permissions are only used for the features you enable. Window thumbnails stay on your Mac and configuration stays local.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack {
                            CapabilityBadge(title: "No analytics", systemImage: "chart.bar.xaxis", tone: .active)
                            CapabilityBadge(title: "No tracking", systemImage: "eye.slash", tone: .active)
                            CapabilityBadge(title: "Local settings", systemImage: "externaldrive", tone: .neutral)
                            Spacer()
                        }
                    }

                    Spacer(minLength: 0)
                }
            }

            SectionCard(title: "Local Details", subtitle: "Technical privacy details are here when you need them.", symbolName: "externaldrive") {
                DisclosureGroup("Show local paths and data use") {
                    Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                        PrivacyPromiseRow(title: "Remote APIs", value: "None by default")
                        PrivacyPromiseRow(title: "Configuration", value: appModel.store.configURL.path)
                        PrivacyPromiseRow(title: "Window thumbnails", value: "Used locally for Dock previews")
                    }
                    .padding(.top, 6)
                }
                .font(.callout)
            }

            PreferencesSectionGrid(minimumColumnWidth: 280) {
                PermissionCard(
                    title: "Accessibility",
                    subtitle: "Shortcuts and window actions",
                    symbolName: "accessibility",
                    state: appModel.permissions.accessibility,
                    primaryActionTitle: "Request Access",
                    secondaryActionTitle: "Open Settings",
                    primaryAction: { appModel.permissions.requestAccessibility() },
                    secondaryAction: { appModel.permissions.openAccessibilitySettings() }
                )

                PermissionCard(
                    title: "Screen Recording",
                    subtitle: "Window thumbnails",
                    symbolName: "rectangle.on.rectangle",
                    state: appModel.permissions.screenRecording,
                    primaryActionTitle: "Request Access",
                    secondaryActionTitle: "Open Settings",
                    primaryAction: { appModel.permissions.requestScreenRecording() },
                    secondaryAction: { appModel.permissions.openScreenRecordingSettings() }
                )

                InputMonitoringCard {
                    appModel.permissions.openInputMonitoringSettings()
                }
            }
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
        SoftStatusCard(
            title: title,
            subtitle: subtitle,
            systemImage: symbolName,
            tone: state == .granted ? .active : .warning
        ) {
            HStack(spacing: 8) {
                CapabilityBadge(
                    title: state.title,
                    systemImage: state == .granted ? "checkmark.circle.fill" : "exclamationmark.circle",
                    tone: state == .granted ? .active : .warning
                )
                Spacer()
                if state != .granted {
                    Button(primaryActionTitle, action: primaryAction)
                } else {
                    Button(secondaryActionTitle, action: secondaryAction)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct InputMonitoringCard: View {
    var openSettings: () -> Void

    var body: some View {
        SoftStatusCard(
            title: "Input Monitoring",
            subtitle: "Only if macOS asks",
            systemImage: "keyboard",
            tone: .neutral
        ) {
            HStack(spacing: 8) {
                CapabilityBadge(title: "Guided setup", systemImage: "keyboard.badge.eye", tone: .neutral)
                Spacer()
                Button("Open Settings", action: openSettings)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
