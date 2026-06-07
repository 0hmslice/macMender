import AppKit
import SwiftUI

struct AdvancedView: View {
    @ObservedObject var appModel: AppModel
    @State private var showingResetConfirmation = false
    @State private var showingImportConfirmation = false
    @State private var pendingImport: ConfigurationImportPreview?
    @State private var configurationStatus = "Autosave keeps current settings on disk."

    var body: some View {
        PreferencesScrollView {
            MendySectionHeader(
                section: .advanced,
                title: "Advanced",
                subtitle: "Diagnostics, recovery, and technical status stay here when you need them."
            )

            StatusRefreshCard(appModel: appModel)

            SectionCard(title: "Local Diagnostics", subtitle: "Messages stay on this Mac.", symbolName: "stethoscope") {
                VStack(alignment: .leading, spacing: 8) {
                    if appModel.diagnostics.latestMessages.isEmpty {
                        Label("No recent diagnostics", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.secondary)
                    } else {
                        DisclosureGroup("Recent local messages") {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(appModel.diagnostics.latestMessages, id: \.self) { message in
                                    Label(message, systemImage: "info.circle")
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(.top, 6)
                        }
                    }
                }
            }

            SectionCard(title: "Configuration", subtitle: "Save, export, or restore local settings.", symbolName: "externaldrive") {
                VStack(alignment: .leading, spacing: 10) {
                    ConfigurationActionRow(
                        title: "Save Now",
                        detail: "Write the current settings to disk.",
                        buttonTitle: "Save Now",
                        symbolName: "square.and.arrow.down"
                    ) {
                        switch appModel.saveConfigurationNow() {
                        case .success(let url):
                            configurationStatus = "Saved current settings to \(url.lastPathComponent)."
                        case .failure(let error):
                            configurationStatus = configurationErrorMessage(error)
                        }
                    }

                    ConfigurationActionRow(
                        title: "Export Config",
                        detail: "Save a copy you can back up or move to another Mac.",
                        buttonTitle: "Export Config",
                        symbolName: "square.and.arrow.up"
                    ) {
                        appModel.exportConfiguration { result in
                            switch result {
                            case .success(let url):
                                configurationStatus = "Exported configuration to \(url.lastPathComponent)."
                            case .failure(let error):
                                configurationStatus = configurationErrorMessage(error)
                            }
                        }
                    }

                    ConfigurationActionRow(
                        title: "Import Config",
                        detail: "Restore settings from a macMender config file.",
                        buttonTitle: "Import Config",
                        symbolName: "tray.and.arrow.down"
                    ) {
                        appModel.chooseConfigurationImport { result in
                            switch result {
                            case .success(let preview):
                                pendingImport = preview
                                showingImportConfirmation = true
                            case .failure(let error):
                                configurationStatus = configurationErrorMessage(error)
                            }
                        }
                    }

                    ConfigurationActionRow(
                        title: "Open Config Folder",
                        detail: "Reveal the local configuration folder in Finder.",
                        buttonTitle: "Open Folder",
                        symbolName: "folder"
                    ) {
                        appModel.openConfigurationFolder()
                        configurationStatus = "Opened the local configuration folder."
                    }

                    Label(configurationStatus, systemImage: "info.circle")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            SectionCard(title: "Recovery Tools", subtitle: "Safe, reversible actions for troubleshooting.", symbolName: "arrow.counterclockwise") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Safe Mode")
                                .font(.callout.weight(.semibold))
                            Text("Pauses active input monitoring, Dock previews, Window Switcher shortcuts, and experimental input features. App settings and this window stay available.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 12)

                        Button(appModel.store.config.safeModeEnabled ? "Disable Safe Mode" : "Enable Safe Mode") {
                            appModel.toggleSafeMode()
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .liquidGlass(.row)

                    HStack {
                        Button("Read Dock Defaults") {
                            appModel.dock.refresh()
                        }
                        Spacer()
                        Button("Reset to Onboarding", role: .destructive) {
                            showingResetConfirmation = true
                        }
                    }
                }
            }

            SectionCard(title: "Technical Status", subtitle: "Detailed boundaries are available when you need them.", symbolName: "lock.trianglebadge.exclamationmark") {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Only verified controls are shown as available.", systemImage: "checkmark.shield")
                        .foregroundStyle(.secondary)

                    DisclosureGroup("Services") {
                        VStack(alignment: .leading, spacing: 10) {
                            RuntimeRow(
                                title: "Input event tap",
                                detail: appModel.systemEvents.status.eventTapRunning ? "Ready for shortcuts and input adjustments" : "Waiting for permission or setup",
                                running: appModel.systemEvents.status.eventTapRunning
                            )
                            RuntimeRow(
                                title: "Three-finger tap",
                                detail: appModel.multitouchMiddleClick.isRunning ? appModel.multitouchMiddleClick.lastStatus : middleClickServiceDetail,
                                running: appModel.multitouchMiddleClick.isRunning
                            )
                            RuntimeRow(
                                title: "Dock previews",
                                detail: appModel.dockHover.isRunning ? (appModel.dockHover.lastHoveredApp ?? "Watching Dock item hover") : "Paused until enabled and Accessibility is granted",
                                running: appModel.dockHover.isRunning
                            )
                            RuntimeRow(
                                title: "Window Switcher",
                                detail: appModel.windowSwitcher.presentationStatus,
                                running: appModel.store.config.featureToggles.windowSwitcher && appModel.permissions.accessibility == .granted && !appModel.store.config.safeModeEnabled
                            )
                        }
                        .padding(.top, 6)
                    }

                    DisclosureGroup("Technical boundaries") {
                        VStack(alignment: .leading, spacing: 8) {
                            BoundaryRow(title: "Launch timing", detail: launchTimingDetail)
                            BoundaryRow(title: "Dock icon hover previews", detail: "Reads the Dock accessibility tree and disables itself when Accessibility is unavailable.")
                            BoundaryRow(title: "Three-finger global gestures", detail: "Uses local multitouch callbacks where available and falls back to mouse-button triggers otherwise.")
                            BoundaryRow(title: "Spaces movement", detail: "Only actions with a reliable local runtime path are exposed in the UI.")
                        }
                        .padding(.top, 6)
                    }
                }
            }
        }
        .confirmationDialog("Reset macMender?", isPresented: $showingResetConfirmation) {
            Button("Reset to Onboarding", role: .destructive) {
                appModel.resetToOnboarding()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears local settings and shows onboarding again.")
        }
        .confirmationDialog("Import Configuration?", isPresented: $showingImportConfirmation) {
            Button("Import Config", role: .destructive) {
                guard let pendingImport else { return }
                switch appModel.importConfiguration(pendingImport) {
                case .success(let backupURL):
                    if let backupURL {
                        configurationStatus = "Imported \(pendingImport.sourceURL.lastPathComponent). Backup saved as \(backupURL.lastPathComponent)."
                    } else {
                        configurationStatus = "Imported \(pendingImport.sourceURL.lastPathComponent)."
                    }
                case .failure(let error):
                    configurationStatus = configurationErrorMessage(error)
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

    private var launchTimingDetail: String {
        let firstWindow = appModel.firstWindowReadyAt.map { "first window marked \($0.formatted(date: .omitted, time: .standard))" } ?? "first window not marked yet"
        let runtime = appModel.runtimeStartedAt.map { "runtime started \($0.formatted(date: .omitted, time: .standard))" } ?? "runtime not started yet"
        return "\(firstWindow); \(runtime). Heavier helpers start after the first window appears."
    }

    private var middleClickServiceDetail: String {
        let settings = appModel.activeProfile.middleClick
        if !settings.enabled || settings.trigger != .experimentalThreeFinger {
            return "Off in the active profile"
        }
        if appModel.permissions.accessibility != .granted {
            return "Waiting for Accessibility"
        }
        if appModel.store.config.safeModeEnabled {
            return "Paused by Safe Mode"
        }
        return appModel.multitouchMiddleClick.lastStatus
    }

    private var importConfirmationMessage: String {
        guard let pendingImport else {
            return "This will replace your current profiles and app settings. macOS permissions are not imported."
        }

        let onboarding = pendingImport.includesCompletedOnboarding ? "Onboarding is marked complete." : "Onboarding is marked incomplete."
        return "This will replace your current profiles and app settings with \(pendingImport.profileCount) profile(s). The selected profile will be \(pendingImport.selectedProfileName). \(onboarding) Menu Bar Spacing will be stored as \(pendingImport.menuBarSpacingTitle), but system spacing will not be applied until you press Apply. macOS permissions are not imported. A backup of your current config will be saved first."
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

private struct ConfigurationActionRow: View {
    var title: String
    var detail: String
    var buttonTitle: String
    var symbolName: String
    var action: () -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Label(title, systemImage: symbolName)
                .font(.callout.weight(.semibold))

            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 12)

            Button(buttonTitle, action: action)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .liquidGlass(.row)
    }
}

private struct StatusRefreshCard: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        SectionCard(
            title: "Status Refresh",
            subtitle: "Updates permissions, login item state, Dock defaults, and helper status without scanning windows or capturing thumbnails.",
            symbolName: "arrow.clockwise"
        ) {
            HStack(spacing: 14) {
                if appModel.isRefreshingStatus {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(appModel.isRefreshingStatus ? "Updating status..." : lastUpdatedTitle)
                        .font(.callout.weight(.semibold))
                    Text(appModel.lastStatusRefreshSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Button {
                    appModel.refreshStatus()
                } label: {
                    Label(appModel.isRefreshingStatus ? "Refreshing" : "Refresh Status", systemImage: "arrow.clockwise")
                }
                .disabled(appModel.isRefreshingStatus)
            }
        }
    }

    private var lastUpdatedTitle: String {
        guard let last = appModel.lastStatusRefresh else {
            return "Not refreshed yet"
        }
        if Date().timeIntervalSince(last) < 60 {
            return "Updated just now"
        }
        return "Updated at \(last.formatted(date: .omitted, time: .shortened))"
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

private struct BoundaryRow: View {
    var title: String
    var detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.callout.weight(.medium))
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(.row)
    }
}
