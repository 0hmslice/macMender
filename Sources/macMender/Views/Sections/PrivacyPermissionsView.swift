import SwiftUI

struct PrivacyPermissionsView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        PreferencesScrollView {
            SectionCard(title: "macMender runs locally.", subtitle: "No analytics. No tracking. No remote APIs by default.", symbolName: "hand.raised") {
                HStack(alignment: .top, spacing: 16) {
                    MendySectionImageView(section: .privacy, size: MendyAvatarSize.panel)

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

                InputMonitoringCard(
                    permissionState: appModel.permissions.inputMonitoring,
                    gestureRuntimeState: gestureRuntimeState,
                    requestAccess: { appModel.permissions.requestInputMonitoring() },
                    openSettings: { appModel.permissions.openInputMonitoringSettings() }
                )
            }
        }
    }

    private var gestureRuntimeState: GestureRuntimeState {
        let settings = appModel.activeProfile.middleClick
        guard settings.enabled, settings.trigger == .experimentalThreeFinger else {
            return .off("Off in the active profile")
        }
        guard appModel.permissions.accessibility == .granted else {
            return .needsPermission("Needs Accessibility")
        }
        guard !appModel.store.config.safeModeEnabled else {
            return .off("Paused by Safe Mode")
        }
        if appModel.multitouchMiddleClick.isRunning {
            return .active(appModel.multitouchMiddleClick.lastStatus)
        }
        return .off(appModel.multitouchMiddleClick.lastStatus)
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
    var permissionState: PermissionState
    var gestureRuntimeState: GestureRuntimeState
    var requestAccess: () -> Void
    var openSettings: () -> Void

    var body: some View {
        SoftStatusCard(
            title: "Input Monitoring",
            subtitle: "Listen-event permission",
            systemImage: "keyboard",
            tone: permissionState == .granted ? .active : .warning
        ) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    CapabilityBadge(
                        title: "Permission: \(permissionState.title)",
                        systemImage: permissionState == .granted ? "checkmark.circle.fill" : "exclamationmark.circle",
                        tone: permissionState == .granted ? .active : .warning
                    )
                    CapabilityBadge(
                        title: "Gesture: \(gestureRuntimeState.title)",
                        systemImage: gestureRuntimeState.symbolName,
                        tone: gestureRuntimeState.tone
                    )
                }

                Text(gestureRuntimeState.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack {
                    if permissionState != .granted {
                        Button("Request Access", action: requestAccess)
                    }
                    Spacer()
                    Button("Open Settings", action: openSettings)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private enum GestureRuntimeState {
    case active(String)
    case off(String)
    case needsPermission(String)

    var title: String {
        switch self {
        case .active:
            "Active"
        case .off:
            "Off"
        case .needsPermission:
            "Needs Permission"
        }
    }

    var detail: String {
        switch self {
        case let .active(detail), let .off(detail), let .needsPermission(detail):
            detail
        }
    }

    var symbolName: String {
        switch self {
        case .active:
            "checkmark.circle.fill"
        case .off:
            "pause.circle"
        case .needsPermission:
            "exclamationmark.circle"
        }
    }

    var tone: CapabilityBadge.Tone {
        switch self {
        case .active:
            .active
        case .off:
            .neutral
        case .needsPermission:
            .warning
        }
    }
}
