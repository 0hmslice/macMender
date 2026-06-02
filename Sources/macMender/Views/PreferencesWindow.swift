import SwiftUI

struct PreferencesWindow: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        if appModel.store.config.hasCompletedOnboarding {
            NavigationSplitView {
                VStack(spacing: 0) {
                    MendySidebarHeader(appModel: appModel)
                        .padding(.bottom, 4)
                    SidebarView(selection: $appModel.selectedSection)
                    SidebarStatusSummary(appModel: appModel)
                }
                    .background {
                        ZStack {
                            Color(nsColor: .windowBackgroundColor).opacity(0.18)
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    Color.accentColor.opacity(0.035),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        }
                    }
                    .navigationSplitViewColumnWidth(min: 230, ideal: 260)
            } detail: {
                PreferencesDetailShell(appModel: appModel)
                    .navigationTitle(appModel.selectedSection.title)
                    .toolbar {
                        ToolbarItemGroup {
                            if appModel.store.config.profiles.count > 1 {
                                ProfilePicker(appModel: appModel)
                            }

                            Button {
                                appModel.toggleSafeMode()
                            } label: {
                                Label("Safe Mode", systemImage: appModel.store.config.safeModeEnabled ? "pause.circle.fill" : "pause.circle")
                            }
                            .help("Disable all active system modifications")

                            Button {
                                appModel.refreshSystemState(force: true)
                            } label: {
                                Label("Refresh", systemImage: "arrow.clockwise")
                            }
                        }
                    }
            }
        } else {
            OnboardingView(appModel: appModel)
        }
    }
}

private struct MendySidebarHeader: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        HStack(spacing: 12) {
            MendyAvatarView(mood: appModel.mendyMood, size: MendyAvatarSize.sidebar)

            VStack(alignment: .leading, spacing: 3) {
                Text("macMender")
                    .font(.headline)
                Text(headerDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    private var headerDetail: String {
        switch appModel.selectedSection {
        case .overview:
            "Keeping your Mac working beautifully."
        case .input:
            "Mouse and trackpad tools."
        case .menuBar:
            "Plan a cleaner menu bar."
        case .dockWindows:
            "Previews and switching."
        case .profiles:
            "Saved setups."
        case .privacy:
            appModel.permissions.needsAttention ? "Needs one permission." : "Access looks good."
        case .advanced:
            "Diagnostics and recovery."
        }
    }
}

private struct SidebarStatusSummary: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                    .shadow(color: statusColor.opacity(0.45), radius: 4)
                Text(statusTitle)
                    .font(.caption.weight(.medium))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .liquidGlass(.row, radius: 12)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
    }

    private var statusTitle: String {
        if appModel.store.config.safeModeEnabled { return "Safe Mode on" }
        if appModel.permissions.needsAttention { return "Needs attention" }
        return "All services running"
    }

    private var statusColor: Color {
        if appModel.store.config.safeModeEnabled { return .orange }
        if appModel.permissions.needsAttention { return .orange }
        return .green
    }
}

private struct PreferencesDetailShell: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        VStack(spacing: 0) {
            DetailRouter(appModel: appModel)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background {
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                    .opacity(0.22)
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.075),
                        Color.accentColor.opacity(0.055),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea()
        }
    }
}

private struct DetailRouter: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        switch appModel.selectedSection {
        case .overview:
            OverviewView(appModel: appModel)
        case .input:
            InputScrollingView(appModel: appModel)
        case .menuBar:
            MenuBarManagementView(appModel: appModel)
        case .dockWindows:
            DockWindowsView(appModel: appModel)
        case .profiles:
            ProfilesView(appModel: appModel)
        case .privacy:
            PrivacyPermissionsView(appModel: appModel)
        case .advanced:
            AdvancedView(appModel: appModel)
        }
    }
}

private struct ProfilePicker: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        Picker("Profile", selection: Binding(
            get: { appModel.store.config.activeProfileID },
            set: { appModel.setActiveProfile($0) }
        )) {
            ForEach(appModel.store.config.profiles) { profile in
                Label(profile.name, systemImage: profile.symbolName)
                    .tag(profile.id)
            }
        }
        .labelsHidden()
        .frame(width: 180)
    }
}
