import Accessibility
import SwiftUI

struct AdvancedView: View {
    @ObservedObject var appModel: AppModel
    @State private var showingResetConfirmation = false
    @State private var showingImportConfirmation = false
    @State private var pendingImport: ConfigurationImportPreview?
    @State private var configurationStatus = "Autosave keeps current settings on disk."
    @State private var configurationStatusTone = MacMenderStatusTone.neutral

    var body: some View {
        Form {
            Section {
                AdvancedStatusRefreshRow(appModel: appModel)
            } header: {
                Label("Status", systemImage: "arrow.clockwise")
            } footer: {
                Text("Refreshes permissions, login item state, Dock values, and helper status without scanning windows or capturing thumbnails.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }

            Section {
                AdvancedActionRow(
                    title: "Save Now",
                    detail: "Write the current settings to disk.",
                    buttonTitle: "Save Now",
                    systemImage: "square.and.arrow.down"
                ) {
                    switch appModel.saveConfigurationNow() {
                    case .success(let url):
                        setConfigurationStatus("Saved current settings to \(url.lastPathComponent).", tone: .active)
                    case .failure(let error):
                        setConfigurationStatus(configurationErrorMessage(error), tone: .unavailable)
                    }
                }

                AdvancedActionRow(
                    title: "Export Configuration",
                    detail: "Save a JSON copy you can back up or move to another Mac.",
                    buttonTitle: "Export…",
                    systemImage: "square.and.arrow.up"
                ) {
                    appModel.exportConfiguration { result in
                        switch result {
                        case .success(let url):
                            setConfigurationStatus("Exported configuration to \(url.lastPathComponent).", tone: .active)
                        case .failure(let error):
                            setConfigurationStatus(configurationErrorMessage(error), tone: .unavailable)
                        }
                    }
                }

                AdvancedActionRow(
                    title: "Import Configuration",
                    detail: "Validate a macMender JSON file before replacing local settings.",
                    buttonTitle: "Import…",
                    systemImage: "tray.and.arrow.down"
                ) {
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

                AdvancedActionRow(
                    title: "Show Config in Finder",
                    detail: "Reveal the active local configuration file.",
                    buttonTitle: "Show in Finder",
                    systemImage: "folder"
                ) {
                    appModel.openConfigurationFolder()
                    setConfigurationStatus("Asked Finder to show the local configuration file.", tone: .neutral)
                }

                MacMenderCallout(
                    systemImage: configurationStatusTone.defaultSymbol,
                    tone: configurationStatusTone
                ) {
                    Text(configurationStatus)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                Label("Configuration", systemImage: "externaldrive")
            }

            Section {
                HStack(alignment: .top, spacing: MacMenderSpacing.standard) {
                    VStack(alignment: .leading, spacing: MacMenderSpacing.compact) {
                        HStack(spacing: MacMenderSpacing.small) {
                            Text("Safe Mode")
                                .font(.body.weight(.medium))
                            MacMenderStatusLabel(
                                title: appModel.store.config.safeModeEnabled ? "Enabled" : "Off",
                                tone: appModel.store.config.safeModeEnabled ? .paused : .neutral,
                                systemImage: appModel.store.config.safeModeEnabled ? "pause.circle.fill" : "circle.fill"
                            )
                        }
                        Text("Pauses active input handling, Dock previews, Window Switcher shortcuts, and Three-Finger Tap while settings remain available.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer(minLength: MacMenderSpacing.standard)

                    Button(appModel.store.config.safeModeEnabled ? "Disable Safe Mode" : "Enable Safe Mode") {
                        appModel.toggleSafeMode()
                    }
                }
                .padding(.vertical, MacMenderSpacing.small)

                AdvancedActionRow(
                    title: "Refresh Dock Values",
                    detail: appModel.dock.lastReadDescription,
                    buttonTitle: "Refresh Dock Values",
                    systemImage: "dock.rectangle"
                ) {
                    appModel.dock.refresh()
                }
            } header: {
                Label("Troubleshooting", systemImage: "wrench.and.screwdriver")
            }

            Section {
                DisclosureGroup("Local Messages") {
                    localMessages
                        .padding(.top, MacMenderSpacing.small)
                }

                DisclosureGroup("Service Status") {
                    VStack(spacing: 0) {
                        ForEach(Array(runtimeSummaries.enumerated()), id: \.offset) { index, entry in
                            AdvancedRuntimeRow(title: entry.title, summary: entry.summary)
                            if index < runtimeSummaries.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(.top, MacMenderSpacing.small)
                }

                DisclosureGroup("Technical Details") {
                    VStack(spacing: 0) {
                        AdvancedBoundaryRow(title: "Launch timing", detail: launchTimingDetail)
                        Divider()
                        AdvancedBoundaryRow(
                            title: "Dock icon hover previews",
                            detail: "Reads the Dock accessibility tree and disables itself when Accessibility is unavailable."
                        )
                        Divider()
                        AdvancedBoundaryRow(
                            title: "Three-finger global gestures",
                            detail: "Uses local multitouch callbacks where available and falls back to mouse-button triggers otherwise."
                        )
                        Divider()
                        AdvancedBoundaryRow(
                            title: "Spaces movement",
                            detail: "Only actions with a reliable local runtime path are exposed in the UI."
                        )
                    }
                    .padding(.top, MacMenderSpacing.small)
                }
            } header: {
                Label("Diagnostics", systemImage: "stethoscope")
            } footer: {
                Text("Diagnostic notes and technical details remain on this Mac.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }

            Section {
                Button("Reset macMender…", role: .destructive) {
                    showingResetConfirmation = true
                }
                .foregroundStyle(.red)
            } header: {
                Label("Reset", systemImage: "exclamationmark.triangle")
            } footer: {
                Text("Replaces all local profiles and app-wide settings with defaults, then returns to onboarding. macOS permissions and system Dock or menu bar preferences are not reset.")
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .multilineTextAlignment(.leading)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .frame(maxWidth: 780)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            ("Input event tap", eventTapSummary),
            ("Three-Finger Tap", threeFingerSummary),
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

    private var launchTimingDetail: String {
        let firstWindow = appModel.firstWindowReadyAt.map {
            "first window marked \($0.formatted(date: .omitted, time: .standard))"
        } ?? "first window not marked yet"
        let runtime = appModel.runtimeStartedAt.map {
            "runtime started \($0.formatted(date: .omitted, time: .standard))"
        } ?? "runtime not started yet"
        return "\(firstWindow); \(runtime). Heavier helpers start after the first window appears."
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
        configurationStatus = message
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
