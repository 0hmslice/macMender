import SwiftUI

struct PreferencesWindow: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        if appModel.store.config.hasCompletedOnboarding {
            NavigationSplitView {
                VStack(spacing: 0) {
                    MendySidebarHeader(appModel: appModel)
                    Divider()
                    SidebarView(selection: $appModel.selectedSection)
                }
                    .navigationSplitViewColumnWidth(min: 230, ideal: 260)
            } detail: {
                DetailRouter(appModel: appModel)
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
            MendyAvatarView(mood: appModel.mendyMood, size: 54)

            VStack(alignment: .leading, spacing: 3) {
                Text("Mendy")
                    .font(.headline)
                Text(headerDetail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var headerDetail: String {
        switch appModel.selectedSection {
        case .overview:
            "Watching the whole setup"
        case .input:
            "Tuning input feel"
        case .menuBar:
            "Organizing menu extras"
        case .dockWindows:
            "Watching Dock and windows"
        case .profiles:
            "Managing saved setups"
        case .privacy:
            appModel.permissions.needsAttention ? "Needs one permission" : "Privacy checks look good"
        case .advanced:
            "Ready for recovery tools"
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
