import SwiftUI

struct PrivacyPermissionsView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: MacMenderSpacing.standard) {
                    Text("macMender does not send analytics, usage, or settings off this Mac. Permissions are used only by the local features you enable.")
                        .fixedSize(horizontal: false, vertical: true)

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: MacMenderSpacing.small) {
                            privacyStatusLabels
                        }
                        VStack(alignment: .leading, spacing: MacMenderSpacing.small) {
                            privacyStatusLabels
                        }
                    }
                }
                .padding(.vertical, MacMenderSpacing.compact)
            } header: {
                Label("Local by Design", systemImage: "hand.raised")
            }

            Section {
                accessibilityPermissionRow
                screenRecordingPermissionRow
                inputMonitoringPermissionRow

                Button {
                    appModel.permissions.refresh()
                } label: {
                    Label("Refresh Permission Status", systemImage: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh Permission Status")
            } header: {
                Label("Permissions", systemImage: "lock.shield")
            } footer: {
                Text("Accessibility is required for core window and shortcut features. Screen Recording and Input Monitoring are optional enhancements.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }

            Section {
                DisclosureGroup("Show Local Paths and Data Use") {
                    VStack(alignment: .leading, spacing: MacMenderSpacing.standard) {
                        LabeledContent("Network features", value: "None")
                        LabeledContent("Configuration") {
                            Text(appModel.store.configURL.path)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        LabeledContent("Window thumbnails", value: "Used locally for previews")
                    }
                    .padding(.top, MacMenderSpacing.small)
                }
            } header: {
                Label("Local Details", systemImage: "externaldrive")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: 780)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private var privacyStatusLabels: some View {
        MacMenderStatusLabel(title: "No analytics", tone: .active, systemImage: "chart.bar.xaxis")
        MacMenderStatusLabel(title: "No tracking", tone: .active, systemImage: "eye.slash")
        MacMenderStatusLabel(title: "Local settings", tone: .neutral, systemImage: "externaldrive")
    }

    private var accessibilityPermissionRow: some View {
        VStack(alignment: .leading, spacing: MacMenderSpacing.standard) {
            PermissionRowHeader(
                title: "Accessibility",
                purpose: "Required · Shortcuts, Dock hover, and window actions",
                systemImage: "accessibility",
                statusTitle: appModel.permissions.accessibility.title,
                statusTone: permissionTone(appModel.permissions.accessibility)
            )

            HStack {
                Spacer(minLength: 0)
                if appModel.permissions.accessibility != .granted {
                    Button("Request Access") {
                        appModel.permissions.requestAccessibility()
                    }
                    .accessibilityLabel("Request Accessibility")
                }
                Button("Open Settings") {
                    appModel.permissions.openAccessibilitySettings()
                }
                .accessibilityLabel("Open Accessibility Settings")
            }
        }
        .padding(.vertical, MacMenderSpacing.small)
    }

    private var screenRecordingPermissionRow: some View {
        let summary = PermissionStatusPolicy.screenRecordingSummary(appModel.permissions.screenRecording)

        return VStack(alignment: .leading, spacing: MacMenderSpacing.standard) {
            PermissionRowHeader(
                title: "Screen Recording",
                purpose: "Optional · Local window thumbnails",
                systemImage: "rectangle.on.rectangle",
                statusTitle: summary.title,
                statusTone: MacMenderStatusTone(featureStatusKind: summary.kind),
                statusDetail: summary.detail
            )

            HStack {
                Spacer(minLength: 0)
                if appModel.permissions.screenRecording != .granted {
                    Button("Request Access") {
                        appModel.permissions.requestScreenRecording()
                    }
                    .accessibilityLabel("Request Screen Recording")
                }
                Button("Open Settings") {
                    appModel.permissions.openScreenRecordingSettings()
                }
                .accessibilityLabel("Open Screen Recording Settings")
            }
        }
        .padding(.vertical, MacMenderSpacing.small)
    }

    private var inputMonitoringPermissionRow: some View {
        let summary = PermissionStatusPolicy.inputMonitoringSummary(appModel.permissions.inputMonitoring)

        return VStack(alignment: .leading, spacing: MacMenderSpacing.standard) {
            PermissionRowHeader(
                title: "Input Monitoring",
                purpose: "Optional · macOS listen-event permission",
                systemImage: "keyboard",
                statusTitle: summary.title,
                statusTone: MacMenderStatusTone(featureStatusKind: summary.kind),
                statusDetail: summary.detail
            )

            HStack(spacing: MacMenderSpacing.small) {
                Text("Three-Finger Tap")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                MacMenderStatusLabel(
                    title: gestureRuntimeState.title,
                    tone: gestureRuntimeState.tone,
                    systemImage: gestureRuntimeState.symbolName
                )
                Text(gestureRuntimeState.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }

            HStack(spacing: MacMenderSpacing.small) {
                Spacer(minLength: 0)
                if appModel.permissions.inputMonitoring != .granted {
                    Button("Request Access") {
                        appModel.permissions.requestInputMonitoring()
                    }
                    .accessibilityLabel("Request Input Monitoring")
                }
                Button("Open Settings") {
                    appModel.permissions.openInputMonitoringSettings()
                }
                .accessibilityLabel("Open Input Monitoring Settings")
            }
        }
        .padding(.vertical, MacMenderSpacing.small)
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
            return .paused("Paused by Safe Mode")
        }
        if appModel.multitouchMiddleClick.isRunning {
            return .active(appModel.multitouchMiddleClick.lastStatus)
        }
        return .off(appModel.multitouchMiddleClick.lastStatus)
    }

    private func permissionTone(_ state: PermissionState) -> MacMenderStatusTone {
        switch state {
        case .granted:
            .active
        case .missing:
            .attention
        case .unavailable:
            .unavailable
        }
    }
}

private struct PermissionRowHeader: View {
    var title: String
    var purpose: String
    var systemImage: String
    var statusTitle: String
    var statusTone: MacMenderStatusTone
    var statusDetail: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: MacMenderSpacing.standard) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 26)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: MacMenderSpacing.compact) {
                Text(title)
                    .font(.body.weight(.medium))
                Text(purpose)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let statusDetail {
                    Text(statusDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: MacMenderSpacing.standard)

            MacMenderStatusLabel(title: statusTitle, tone: statusTone)
        }
    }
}

private enum GestureRuntimeState {
    case active(String)
    case off(String)
    case paused(String)
    case needsPermission(String)

    var title: String {
        switch self {
        case .active:
            "Active"
        case .off:
            "Off"
        case .paused:
            "Paused"
        case .needsPermission:
            "Needs Permission"
        }
    }

    var detail: String {
        switch self {
        case let .active(detail), let .off(detail), let .paused(detail), let .needsPermission(detail):
            detail
        }
    }

    var symbolName: String {
        switch self {
        case .active:
            "checkmark.circle.fill"
        case .off, .paused:
            "pause.circle"
        case .needsPermission:
            "exclamationmark.circle"
        }
    }

    var tone: MacMenderStatusTone {
        switch self {
        case .active:
            .active
        case .off:
            .neutral
        case .paused:
            .paused
        case .needsPermission:
            .attention
        }
    }
}
