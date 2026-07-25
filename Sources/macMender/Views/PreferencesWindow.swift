import SwiftUI

struct PreferencesWindow: View {
    @ObservedObject var appModel: AppModel
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        if appModel.store.config.hasCompletedOnboarding {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(selection: $appModel.selectedSection)
                    .navigationTitle("macMender")
                    .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 260)
            } detail: {
                DetailRouter(appModel: appModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .navigationTitle(appModel.selectedSection.title)
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            ProfilePicker(appModel: appModel)
                        }
                    }
            }
            .navigationSplitViewStyle(.balanced)
            .onChange(of: appModel.navigationPresentationID) {
                columnVisibility = .all
            }
        } else {
            OnboardingView(appModel: appModel)
        }
    }
}

private struct DetailRouter: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        switch appModel.selectedSection {
        case .overview:
            OverviewView(appModel: appModel)
        case .general:
            GeneralSettingsView(appModel: appModel)
        case .menuBarSpacing:
            MenuBarSpacingView(appModel: appModel)
        case .input:
            InputScrollingView(appModel: appModel)
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
        Group {
            if appModel.shouldShowProfileSwitcher {
                Picker("Profile", selection: activeProfileSelection) {
                    ForEach(appModel.store.config.profiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
                .pickerStyle(.menu)
                .controlSize(.regular)
                .frame(width: 172)
                .help("Switch profile")
                .accessibilityLabel("Profile")
                .accessibilityValue(appModel.activeProfile.name)
                .id(appModel.profileSwitcherIdentity)
            }
        }
    }

    private var activeProfileSelection: Binding<UUID> {
        Binding(
            get: { appModel.store.config.activeProfileID },
            set: { appModel.setActiveProfile($0) }
        )
    }
}
