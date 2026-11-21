import SwiftUI

struct PreferencesWindow: View {
    @ObservedObject var appModel: AppModel
    @State private var columnVisibility = NavigationSplitViewVisibility.all

    var body: some View {
        if appModel.store.config.hasCompletedOnboarding {
            NavigationSplitView(columnVisibility: $columnVisibility) {
                SidebarView(selection: $appModel.selectedSection)
                .navigationSplitViewColumnWidth(min: 200, ideal: 224, max: 280)
            } detail: {
                DetailRouter(appModel: appModel)
                    .safeAreaInset(edge: .bottom) {
                        if let error = appModel.store.persistenceError {
                            HStack {
                                Label(error, systemImage: "exclamationmark.triangle")
                                Spacer()
                                Button("Retry Save") { appModel.store.save() }
                            }
                            .padding()
                            .background(.regularMaterial)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(nsColor: .windowBackgroundColor))
                    // The page shows its own title, so the window's title bar stays clear and
                    // runs unbroken into the content beneath it.
                    .navigationTitle(appModel.selectedSection.title)
                    .hidingToolbarTitle()
                    .toolbarBackground(.hidden, for: .windowToolbar)
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
        case .keepAwake:
            KeepAwakeView(service: appModel.keepAwake, isPaused: appModel.store.config.safeModeEnabled)
        case .menuBarSpacing:
            MenuBarSpacingView(appModel: appModel)
        case .input:
            InputScrollingView(appModel: appModel)
        case .dockPreviews:
            DockPreviewsSettingsView(appModel: appModel)
        case .windowSwitcher:
            WindowSwitcherSettingsView(appModel: appModel)
        case .dockSettings:
            DockSettingsView(appModel: appModel)
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
                .frame(minWidth: 110, maxWidth: 200)
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

private extension View {
    /// Hides the title text in the window's toolbar while keeping it as the window's name.
    @ViewBuilder
    func hidingToolbarTitle() -> some View {
        if #available(macOS 15.0, *) {
            toolbar(removing: .title)
        } else {
            self
        }
    }
}
