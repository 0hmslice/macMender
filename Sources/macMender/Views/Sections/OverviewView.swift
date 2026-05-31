import SwiftUI

struct OverviewView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        PreferencesScrollView {
            SectionCard(
                title: "Current Profile",
                subtitle: appModel.activeProfile.summary,
                symbolName: appModel.activeProfile.symbolName
            ) {
                HStack(spacing: 16) {
                    MendyAvatarView(mood: appModel.mendyMood, size: MendyAvatarSize.prominent)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(appModel.activeProfile.name)
                            .font(.system(size: 34, weight: .semibold))
                        Text("Mendy is watching for permission, Dock, input, and menu bar changes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()
                    CapabilityBadge(
                        title: appModel.store.config.safeModeEnabled ? "Safe Mode" : "Active",
                        systemImage: appModel.store.config.safeModeEnabled ? "pause.circle.fill" : "checkmark.circle.fill",
                        tone: appModel.store.config.safeModeEnabled ? .warning : .active
                    )
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                FeatureTile(title: "Scrolling", symbol: "computermouse", enabled: appModel.store.config.featureToggles.scrolling)
                FeatureTile(title: "Menu Bar", symbol: "menubar.rectangle", enabled: appModel.store.config.featureToggles.menuBarManagement)
                FeatureTile(title: "Window Switcher", symbol: "rectangle.3.group", enabled: appModel.store.config.featureToggles.windowSwitcher)
                FeatureTile(title: "Dock Profiles", symbol: "dock.rectangle", enabled: appModel.store.config.featureToggles.dockProfiles)
            }

            SectionCard(title: "Runtime", subtitle: "Live local controllers that are currently attached to macOS.", symbolName: "dot.radiowaves.left.and.right") {
                VStack(alignment: .leading, spacing: 10) {
                    RuntimeRow(title: "Input Event Tap", detail: appModel.systemEvents.status.lastEventDescription, running: appModel.systemEvents.status.eventTapRunning)
                    RuntimeRow(
                        title: "Dock Hover Monitor",
                        detail: appModel.dockHover.isRunning ? (appModel.dockHover.lastHoveredApp ?? "Watching Dock item hover") : "Paused until Accessibility is granted",
                        running: appModel.dockHover.isRunning
                    )
                    RuntimeRow(
                        title: "Menu Bar Scanner",
                        detail: menuBarRuntimeDetail,
                        running: appModel.menuBarScanner.shelfEnabled
                    )
                }
            }

            SectionCard(title: "System Access", subtitle: "macMender only asks for access when a feature needs it.", symbolName: "lock.shield") {
                VStack(alignment: .leading, spacing: 10) {
                    PermissionRow(title: "Accessibility", detail: "Input tuning, middle-click posting, and window actions", state: appModel.permissions.accessibility)
                    PermissionRow(title: "Screen Recording", detail: "Optional window thumbnails for switcher previews", state: appModel.permissions.screenRecording)
                    HStack {
                        Text("Launch at Login")
                        Spacer()
                        Text(appModel.loginItems.statusDescription)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            SectionCard(title: "Quick Actions", subtitle: "High-confidence recovery actions stay one click away.", symbolName: "bolt") {
                HStack {
                    Button(appModel.store.config.safeModeEnabled ? "Disable Safe Mode" : "Enable Safe Mode") {
                        appModel.toggleSafeMode()
                    }
                    Button("Refresh Permissions") {
                        appModel.refreshSystemState(force: true)
                    }
                    Button("Export Configuration") {
                        appModel.exportConfiguration()
                    }
                }
            }
        }
    }

    private var menuBarRuntimeDetail: String {
        guard appModel.menuBarScanner.shelfEnabled else { return "Paused" }
        if appModel.hiddenMenuBarItemCount == 0 { return "No icons selected to hide" }
        return appModel.menuBarScanner.overflowStatusDescription
    }
}

private struct RuntimeRow: View {
    var title: String
    var detail: String
    var running: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Label(title, systemImage: running ? "checkmark.circle.fill" : "pause.circle")
                .font(.callout.weight(.medium))
                .foregroundStyle(running ? .green : .orange)
            Spacer()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .liquidGlass(.row)
    }
}

private struct FeatureTile: View {
    var title: String
    var symbol: String
    var enabled: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: symbol)
                .font(.title2)
                .foregroundStyle(enabled ? .green : .secondary)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(enabled ? "Enabled" : "Paused")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .liquidGlass(.row)
    }
}

private struct PermissionRow: View {
    var title: String
    var detail: String
    var state: PermissionState

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.medium))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(state.title)
                .foregroundStyle(state == .granted ? .green : .orange)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .liquidGlass(.row)
    }
}
