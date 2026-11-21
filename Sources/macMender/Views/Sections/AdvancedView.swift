import Accessibility
import SwiftUI

struct AdvancedView: View {
    @ObservedObject var appModel: AppModel
    @State private var showingResetConfirmation = false
    @State private var showingImportConfirmation = false
    @State private var pendingImport: ConfigurationImportPreview?
    @State private var configurationMessage: String?
    @State private var configurationStatusTone = MacMenderStatusTone.neutral

    var body: some View {
        SettingsPage(section: .advanced) {
            Section {
                SettingsToggle(
                    "Pause macMender",
                    detail: "Stops Dock previews, the window switcher, scrolling changes, and middle click until you turn this off. Your settings are kept.",
                    isOn: Binding(
                        get: { appModel.store.config.safeModeEnabled },
                        set: { if $0 != appModel.store.config.safeModeEnabled { appModel.toggleSafeMode() } }
                    )
                )
            } footer: {
                SettingsFooter("Useful when something on your Mac misbehaves and you want to rule macMender out.")
            }

            Section {
                SettingsRow(title: "Export settings", detail: "Save a copy to back up or move to another Mac.") {
                    Button("Export…") {
                        appModel.exportConfiguration { result in
                            switch result {
                            case .success(let url):
                                setConfigurationStatus("Exported to \(url.lastPathComponent).", tone: .active)
                            case .failure(let error):
                                setConfigurationStatus(configurationErrorMessage(error), tone: .unavailable)
                            }
                        }
                    }
                }
                SettingsRow(title: "Import settings", detail: "Replace everything here with a saved copy. Your current settings are backed up first.") {
                    Button("Import…") {
                        appModel.chooseConfigurationImport { result in
                            switch result {
                            case .success(let preview):
                                pendingImport = preview
                                showingImportConfirmation = true
                            case .failure(let error):
                                setConfigurationStatus(configurationErrorMessage(error), tone: .unavailable)
                            }
                        }
                    }
                }
                SettingsRow(title: "Settings file", detail: "Saved automatically as you make changes.") {
                    Button("Show in Finder") { appModel.openConfigurationFolder() }
                }
            } header: {
                Text("Backup")
            } footer: {
                if let configurationMessage {
                    Label(configurationMessage, systemImage: configurationStatusTone.defaultSymbol)
                        .font(.callout)
                        .foregroundStyle(configurationStatusTone == .unavailable ? Color.red : Color.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Section("Diagnostics") {
                AdvancedStatusRefreshRow(appModel: appModel)

                DisclosureGroup("What is running") {
                    ForEach(Array(runtimeSummaries.enumerated()), id: \.offset) { _, entry in
                        AdvancedRuntimeRow(title: entry.title, summary: entry.summary)
                    }
                }

                DisclosureGroup("Window list") {
                    HStack {
                        Text("Scan for the windows the switcher and previews can see.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Scan") {
                            appModel.windowSwitcher.refreshDiscovery(settings: appModel.activeProfile.windowSwitcher)
                        }
                    }
                    WindowDiscoveryDiagnosticsView(
                        report: appModel.windowSwitcher.lastDiscoveryReport,
                        hasRunDiscovery: appModel.windowSwitcher.hasRunWindowDiscovery,
                        activationDiagnostic: appModel.windowSwitcher.lastActivationDiagnostic
                    )
                }

                DisclosureGroup("Messages") {
                    localMessages
                }

                LabeledContent("macOS") {
                    Text(systemDescription)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }

            Section {
                HStack {
                    Spacer()
                    Button("Reset macMender…", role: .destructive) {
                        showingResetConfirmation = true
                    }
                }
            } footer: {
                SettingsFooter("Removes every profile and setting and shows the welcome screens again. macOS permissions, the Dock, and the menu bar are left as they are.")
            }
        }
        .confirmationDialog("Reset macMender?", isPresented: $showingResetConfirmation) {
            Button("Reset to Onboarding", role: .destructive) {
                appModel.resetToOnboarding()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This replaces local profiles and app settings with defaults and shows onboarding again. It does not reset macOS permissions or system Dock and menu bar preferences.")
        }
        .confirmationDialog("Import Configuration?", isPresented: $showingImportConfirmation) {
            Button("Import Config", role: .destructive) {
                guard let pendingImport else { return }
                switch appModel.importConfiguration(pendingImport) {
                case .success(let backupURL):
                    if let backupURL {
                        setConfigurationStatus(
                            "Imported \(pendingImport.sourceURL.lastPathComponent). Backup saved as \(backupURL.lastPathComponent).",
                            tone: .active
                        )
                    } else {
                        setConfigurationStatus("Imported \(pendingImport.sourceURL.lastPathComponent).", tone: .active)
                    }
                case .failure(let error):
                    setConfigurationStatus(configurationErrorMessage(error), tone: .unavailable)
                }
                self.pendingImport = nil
            }
            Button("Cancel", role: .cancel) {
                pendingImport = nil
            }
        } message: {
            Text(importConfirmationMessage)
        }
    }

    @ViewBuilder
    private var localMessages: some View {
        if appModel.diagnostics.latestMessages.isEmpty {
            Label("No local messages", systemImage: "tray")
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: MacMenderSpacing.small) {
                ForEach(Array(appModel.diagnostics.latestMessages.enumerated()), id: \.offset) { _, message in
                    Label(message, systemImage: "info.circle")
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var runtimeSummaries: [(title: String, summary: FeatureStatusSummary)] {
        let eventTapSummary = FeatureStatusSummary(
            title: appModel.systemEvents.status.eventTapRunning ? "Active" : eventTapInactiveTitle,
            detail: appModel.systemEvents.status.lastEventDescription,
            kind: appModel.systemEvents.status.eventTapRunning ? .active : eventTapInactiveKind
        )
        let threeFingerSummary = PermissionStatusPolicy.threeFingerTapStatus(
            settings: appModel.activeProfile.middleClick,
            accessibility: appModel.permissions.accessibility,
            safeModeEnabled: appModel.store.config.safeModeEnabled,
            runtimeRunning: appModel.multitouchMiddleClick.isRunning
        )
        let dockPreviewSummary = PermissionStatusPolicy.dockPreviewStatus(
            settings: appModel.activeProfile.dockPreviews,
            accessibility: appModel.permissions.accessibility,
            safeModeEnabled: appModel.store.config.safeModeEnabled,
            runtimeRunning: appModel.dockHover.isRunning
        )
        let windowSwitcherSummary = PermissionStatusPolicy.windowSwitcherStatus(
            settings: appModel.activeProfile.windowSwitcher,
            featureEnabled: appModel.store.config.featureToggles.windowSwitcher,
            accessibility: appModel.permissions.accessibility,
            safeModeEnabled: appModel.store.config.safeModeEnabled
        )

        return [
            ("Scrolling and middle click", eventTapSummary),
            ("Three-finger tap", threeFingerSummary),
            ("Dock Previews", dockPreviewSummary),
            ("Window Switcher", windowSwitcherSummary)
        ]
    }

    private var eventTapInactiveTitle: String {
        if appModel.store.config.safeModeEnabled {
            return "Paused"
        }
        if appModel.permissions.accessibility != .granted {
            return "Needs Accessibility"
        }
        return "Waiting"
    }

    private var eventTapInactiveKind: FeatureStatusKind {
        if appModel.store.config.safeModeEnabled {
            return .paused
        }
        if appModel.permissions.accessibility != .granted {
            return .needsAttention
        }
        return .off
    }

    private var systemDescription: String {
        let system = appModel.menuBarSpacing.systemContext
        return "\(system.majorVersion).\(system.minorVersion).\(system.patchVersion) (\(system.buildVersion))"
    }

    private var importConfirmationMessage: String {
        guard let pendingImport else {
            return "This will replace your current profiles and app settings. macOS permissions are not imported."
        }

        let onboarding = pendingImport.includesCompletedOnboarding ?
            "Onboarding is marked complete." :
            "Onboarding is marked incomplete."
        return "This will replace your current profiles and app settings with \(pendingImport.profileCount) profile(s). The selected profile will be \(pendingImport.selectedProfileName). \(onboarding) Menu Bar Spacing will be stored as \(pendingImport.menuBarSpacingTitle), but system spacing will not be applied until you press Apply. macOS permissions are not imported. A backup of your current config will be saved first."
    }

    private func setConfigurationStatus(_ message: String, tone: MacMenderStatusTone) {
        configurationMessage = message
        configurationStatusTone = tone
        AccessibilityNotification.Announcement(message).post()
    }

    private func configurationErrorMessage(_ error: Error) -> String {
        if let localizedError = error as? LocalizedError {
            let description = localizedError.errorDescription ?? "Configuration action failed."
            if let recoverySuggestion = localizedError.recoverySuggestion {
                return "\(description) \(recoverySuggestion)"
            }
            return description
        }
        return "Configuration action failed: \(error.localizedDescription)"
    }
}
