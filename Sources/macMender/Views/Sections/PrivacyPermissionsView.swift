import SwiftUI

struct PrivacyPermissionsView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        SettingsPage(section: .privacy) {
            Section {
                permissionRow(
                    title: "Accessibility",
                    detail: "Required. Lets macMender see Dock icons, switch and arrange windows, and respond to shortcuts and scrolling.",
                    systemImage: "accessibility",
                    tint: .blue,
                    state: appModel.permissions.accessibility,
                    request: appModel.permissions.requestAccessibility,
                    openSettings: appModel.permissions.openAccessibilitySettings
                )
                permissionRow(
                    title: "Screen Recording",
                    detail: "Optional. Shows each window's contents in previews, peek, and the switcher. Without it you see app icons.",
                    systemImage: "rectangle.on.rectangle",
                    tint: .purple,
                    state: appModel.permissions.screenRecording,
                    request: appModel.permissions.requestScreenRecording,
                    openSettings: appModel.permissions.openScreenRecordingSettings
                )
            } header: {
                Text("Permissions")
            } footer: {
                HStack {
                    Text("macOS may ask you to quit and reopen macMender after you change one.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Check Again") { appModel.permissions.refresh() }
                        .controlSize(.small)
                }
            }

            Section("Your Data") {
                SettingsRow(
                    title: "Nothing leaves this Mac",
                    detail: "No analytics, no tracking, no account, and no network features. Window pictures are used on the spot and never saved.",
                    systemImage: "lock.fill",
                    tint: .green
                ) { EmptyView() }

                LabeledContent("Settings file") {
                    HStack(spacing: 8) {
                        Text(appModel.store.configURL.path.replacingOccurrences(of: NSHomeDirectory(), with: "~"))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Button("Show") { appModel.openConfigurationFolder() }
                            .controlSize(.small)
                    }
                }
            }
        }
    }

    private func permissionRow(
        title: String,
        detail: String,
        systemImage: String,
        tint: Color,
        state: PermissionState,
        request: @escaping () -> Void,
        openSettings: @escaping () -> Void
    ) -> some View {
        SettingsRow(title: title, detail: detail, systemImage: systemImage, tint: tint) {
            if state == .granted {
                SettingsStatusBadge(title: "Allowed", tone: .active)
                Button("Open Settings", action: openSettings)
                    .controlSize(.small)
                    .accessibilityLabel("Open \(title) settings")
            } else {
                SettingsStatusBadge(title: state == .missing ? "Not allowed" : "Unavailable", tone: permissionTone(state))
                Button("Allow…", action: request)
                Button("Open Settings", action: openSettings)
                    .controlSize(.small)
                .accessibilityLabel("Allow \(title)")
            }
        }
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
