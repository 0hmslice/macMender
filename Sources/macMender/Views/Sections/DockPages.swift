import AppKit
import SwiftUI

// MARK: - Dock Previews

struct DockPreviewsSettingsView: View {
    @ObservedObject var appModel: AppModel

    private var settings: DockPreviewSettings { appModel.activeProfile.dockPreviews }
    private var hasScreenRecording: Bool { appModel.permissions.screenRecording == .granted }

    var body: some View {
        SettingsPage(section: .dockPreviews, profileName: appModel.shouldShowProfileSwitcher ? appModel.activeProfile.name : nil) {
            Section {
                Toggle("Show previews when hovering Dock icons", isOn: appModel.profileBinding(\.dockPreviews.enabled))
                LabeledContent("Status") {
                    SettingsStatusBadge(title: status.title, tone: MacMenderStatusTone(featureStatusKind: status.kind))
                }
                if !hasScreenRecording {
                    SettingsRow(
                        title: "Previews show app icons, not windows",
                        detail: "Allow Screen Recording to see each window's contents.",
                        systemImage: "rectangle.dashed",
                        tint: .orange
                    ) {
                        Button("Open Privacy") { appModel.selectedSection = .privacy }
                    }
                }
            }

            Group {
                Section("Look") {
                    SettingsSlider(
                        title: "Preview size",
                        value: appModel.profileBinding(\.dockPreviews.previewSize),
                        range: DockPreviewSettings.previewSizeRange,
                        step: 10,
                        valueLabel: "\(settings.previewSize.wholeNumberLabel) pt",
                        minimumLabel: "Small",
                        maximumLabel: "Large"
                    )
                    SettingsToggle("App name", detail: "A header with the app's name and Hide and Quit buttons.", isOn: appModel.profileBinding(\.dockPreviews.showAppHeader))
                    Toggle("Window titles", isOn: appModel.profileBinding(\.dockPreviews.showTitles))
                    SettingsToggle("Window buttons", detail: "Close, minimize, and full screen on the preview under the pointer.", isOn: appModel.profileBinding(\.dockPreviews.showWindowControls))
                }

                Section("Timing") {
                    SettingsSlider(
                        title: "Wait before showing",
                        value: appModel.profileBinding(\.dockPreviews.hoverDelay),
                        range: DockPreviewSettings.hoverDelayRange,
                        step: 0.05,
                        valueLabel: settings.hoverDelay < 0.01 ? "Instant" : "\(settings.hoverDelay.sliderValueLabel) s",
                        minimumLabel: "Instant",
                        maximumLabel: "Slow"
                    )
                    SettingsSlider(
                        title: "Stay open after the pointer leaves",
                        value: appModel.profileBinding(\.dockPreviews.dismissDelay),
                        range: DockPreviewSettings.dismissDelayRange,
                        step: 0.05,
                        valueLabel: "\(settings.dismissDelay.sliderValueLabel) s"
                    )
                    Picker("Animation", selection: appModel.profileBinding(\.dockPreviews.animationStyle)) {
                        ForEach(DockPreviewAnimationStyle.selectableCases) { style in
                            Text(style.title).tag(style)
                        }
                    }
                    if settings.animationStyle != .none {
                        SettingsSlider(
                            title: "Animation length",
                            value: appModel.profileBinding(\.dockPreviews.animationDuration),
                            range: DockPreviewSettings.animationDurationRange,
                            step: 0.01,
                            valueLabel: "\(settings.animationDuration.sliderValueLabel) s",
                            minimumLabel: "Quick",
                            maximumLabel: "Slow"
                        )
                    }
                }

                Section {
                    SettingsToggle("Live previews", detail: "Keep previews updating while they are open.", isOn: appModel.profileBinding(\.dockPreviews.livePreviews))
                        .disabled(!hasScreenRecording)
                    SettingsToggle("Peek", detail: "Rest the pointer on a preview to see that window at full size.", isOn: appModel.profileBinding(\.dockPreviews.peekOnHover))
                        .disabled(!hasScreenRecording)
                    SettingsToggle("Keyboard control", detail: "With the pointer over a preview: arrow keys select, Return opens, ⌘W closes, Escape dismisses.", isOn: appModel.profileBinding(\.dockPreviews.keyboardNavigation))
                } header: {
                    Text("Interaction")
                } footer: {
                    SettingsFooter("Always available: click a preview to switch to it, middle-click to close it, right-click to arrange it, and drag a file onto it to bring that window forward.")
                }

                Section("Windows to Include") {
                    Toggle("Minimized windows", isOn: appModel.profileBinding(\.dockPreviews.includeMinimizedWindows))
                    Toggle("Windows of hidden apps", isOn: appModel.profileBinding(\.dockPreviews.includeHiddenApps))
                    Toggle("Windows on other Spaces and in full screen", isOn: appModel.profileBinding(\.dockPreviews.includeOtherSpaces))
                }

                excludedAppsSection
            }
            .disabled(!settings.enabled)

            Section {
                HStack {
                    Button("Show a Sample Preview") {
                        appModel.dockPreview.showSamplePreview()
                    }
                    .disabled(!settings.enabled)
                    Spacer()
                    Button("Restore Defaults") {
                        var profile = appModel.activeProfile
                        profile.dockPreviews = .default
                        appModel.updateActiveProfile(profile)
                    }
                    .disabled(settings == .default)
                }
            }
        }
    }

    private var status: FeatureStatusSummary {
        PermissionStatusPolicy.dockPreviewStatus(
            settings: settings,
            accessibility: appModel.permissions.accessibility,
            safeModeEnabled: appModel.store.config.safeModeEnabled,
            runtimeRunning: appModel.dockHover.isRunning
        )
    }

    private var excludedAppsSection: some View {
        let excluded = settings.excludedBundleIdentifiers
        let candidates = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .compactMap { app in app.bundleIdentifier.map { RunningAppOption(bundleIdentifier: $0, name: app.localizedName ?? $0) } }
            .uniquedByBundleIdentifier()
            .filter { !excluded.contains($0.bundleIdentifier) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return Section {
            ForEach(excluded, id: \.self) { bundleIdentifier in
                HStack(spacing: 10) {
                    ApplicationIcon(bundleIdentifier: bundleIdentifier)
                    Text(Self.applicationName(for: bundleIdentifier))
                    Spacer()
                    Button {
                        setExcludedApps(excluded.filter { $0 != bundleIdentifier })
                    } label: {
                        Image(systemName: "minus.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .help("Show previews for this app again")
                    .accessibilityLabel("Remove \(Self.applicationName(for: bundleIdentifier))")
                }
            }
            HStack {
                if excluded.isEmpty {
                    Text("Every app shows previews.").foregroundStyle(.secondary)
                }
                Spacer()
                AddApplicationMenu(candidates: candidates) { bundleIdentifier, _ in
                    guard !excluded.contains(bundleIdentifier) else { return }
                    setExcludedApps(excluded + [bundleIdentifier])
                }
            }
        } header: {
            Text("Apps Without Previews")
        }
    }

    private func setExcludedApps(_ bundleIdentifiers: [String]) {
        var profile = appModel.activeProfile
        profile.dockPreviews.excludedBundleIdentifiers = bundleIdentifiers
        appModel.updateActiveProfile(profile)
    }

    private static func applicationName(for bundleIdentifier: String) -> String {
        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier).first?.localizedName {
            return running
        }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier) {
            return FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
        }
        return bundleIdentifier
    }
}

// MARK: - Window Switcher

struct WindowSwitcherSettingsView: View {
    @ObservedObject var appModel: AppModel

    private var settings: WindowSwitcherSettings { appModel.activeProfile.windowSwitcher }

    var body: some View {
        SettingsPage(section: .windowSwitcher, profileName: appModel.shouldShowProfileSwitcher ? appModel.activeProfile.name : nil) {
            Section {
                Toggle("Switch windows from the keyboard", isOn: appModel.profileBinding(\.windowSwitcher.enabled))
                LabeledContent("Status") {
                    SettingsStatusBadge(title: status.title, tone: MacMenderStatusTone(featureStatusKind: status.kind))
                }
            } footer: {
                SettingsFooter("Hold the shortcut's modifier key and press the other key to move through windows; add Shift to go backwards. While it is open, arrow keys also move, W closes the selected window, and M minimizes it. Release to switch, or press Escape to cancel.")
            }

            Group {
                Section {
                    Picker("Shortcut", selection: appModel.profileBinding(\.windowSwitcher.shortcut)) {
                        Text("⌥ Tab  (Option-Tab)").tag("Option+Tab")
                        Text("⌃ Tab  (Control-Tab)").tag("Control+Tab")
                        Text("⌥ Space  (Option-Space)").tag("Option+Space")
                        Text("⌃ Space  (Control-Space)").tag("Control+Space")
                    }
                } footer: {
                    if let conflict = shortcutConflict {
                        Label(conflict, systemImage: "exclamationmark.triangle.fill")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.multicolor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Section("Look") {
                    Picker("Layout", selection: appModel.profileBinding(\.windowSwitcher.layout)) {
                        ForEach(SwitcherLayout.allCases) { layout in
                            Text(layout.title).tag(layout)
                        }
                    }
                    .pickerStyle(.segmented)
                    SettingsSlider(
                        title: "Thumbnail size",
                        value: appModel.profileBinding(\.windowSwitcher.thumbnailSize),
                        range: 96...280,
                        step: 4,
                        valueLabel: "\(settings.thumbnailSize.wholeNumberLabel) pt",
                        minimumLabel: "Small",
                        maximumLabel: "Large"
                    )
                }

                Section("Windows to Include") {
                    Toggle("Minimized windows", isOn: appModel.profileBinding(\.windowSwitcher.includeMinimizedWindows))
                    Toggle("Windows of hidden apps", isOn: appModel.profileBinding(\.windowSwitcher.includeHiddenApps))
                    Toggle("Windows on other Spaces and in full screen", isOn: appModel.profileBinding(\.windowSwitcher.includeOtherSpaces))
                }

                Section {
                    HStack {
                        Text(appModel.permissions.screenRecording == .granted
                             ? "Shows each window's contents."
                             : "Shows app icons until Screen Recording is allowed in Privacy.")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Try It") {
                            appModel.windowSwitcher.show(settings: settings)
                        }
                    }
                }
            }
            .disabled(!settings.enabled)
        }
    }

    private var status: FeatureStatusSummary {
        PermissionStatusPolicy.windowSwitcherStatus(
            settings: settings,
            featureEnabled: appModel.store.config.featureToggles.windowSwitcher,
            accessibility: appModel.permissions.accessibility,
            safeModeEnabled: appModel.store.config.safeModeEnabled
        )
    }

    private var shortcutConflict: String? {
        switch settings.shortcut {
        case "Control+Tab": "Control-Tab normally switches tabs in browsers and other apps. macMender takes it over everywhere."
        case "Control+Space": "Control-Space normally switches keyboard input sources. macMender takes it over everywhere."
        case "Option+Space": "Option-Space normally types a non-breaking space. macMender takes it over everywhere."
        default: nil
        }
    }
}

// MARK: - Dock

struct DockSettingsView: View {
    @ObservedObject var appModel: AppModel
    @State private var showingApplyConfirmation = false
    @State private var showingDockResetConfirmation = false

    private var dock: DockSettings { appModel.activeProfile.dock }

    var body: some View {
        SettingsPage(section: .dockSettings, profileName: appModel.shouldShowProfileSwitcher ? appModel.activeProfile.name : nil) {
            Section {
                DockSettingsPreview(settings: dock)
            }

            Section("Size") {
                SettingsSlider(
                    title: "Icon size",
                    value: sizeBinding,
                    range: 24...96,
                    step: 1,
                    valueLabel: "\(dock.size.wholeNumberLabel) pt",
                    minimumLabel: "Small",
                    maximumLabel: "Large"
                )
                Toggle("Magnify icons under the pointer", isOn: appModel.profileBinding(\.dock.magnificationEnabled))
                if dock.magnificationEnabled {
                    SettingsSlider(
                        title: "Magnified size",
                        value: appModel.profileBinding(\.dock.magnificationSize),
                        range: max(32, dock.size)...128,
                        step: 1,
                        valueLabel: "\(dock.magnificationSize.wholeNumberLabel) pt"
                    )
                }
            }

            Section("Position and Hiding") {
                Picker("Position on screen", selection: appModel.profileBinding(\.dock.position)) {
                    ForEach(DockPosition.allCases) { position in
                        Text(position.title).tag(position)
                    }
                }
                .pickerStyle(.segmented)
                Toggle("Hide the Dock until the pointer reaches the edge", isOn: appModel.profileBinding(\.dock.autoHide))
                if dock.autoHide {
                    SettingsSlider(
                        title: "Wait before appearing",
                        value: appModel.profileBinding(\.dock.autoHideDelay),
                        range: 0...1,
                        step: 0.05,
                        valueLabel: dock.autoHideDelay < 0.01 ? "Instant" : "\(dock.autoHideDelay.sliderValueLabel) s"
                    )
                    SettingsSlider(
                        title: "Slide animation",
                        value: appModel.profileBinding(\.dock.autoHideAnimationSpeed),
                        range: 0...1,
                        step: 0.05,
                        valueLabel: dock.autoHideAnimationSpeed < 0.01 ? "None" : "\(dock.autoHideAnimationSpeed.sliderValueLabel) s",
                        minimumLabel: "Fast",
                        maximumLabel: "Slow"
                    )
                }
            }

            Section("Contents") {
                Toggle("Show recent apps", isOn: appModel.profileBinding(\.dock.showRecentApps))
                Toggle("Show a dot under open apps", isOn: appModel.profileBinding(\.dock.showIndicators))
            }

            Section {
                dockChangesSummary
                HStack {
                    Button("Restore macOS Defaults…", role: .destructive) {
                        showingDockResetConfirmation = true
                    }
                    Spacer()
                    Button("Copy from the Dock") {
                        appModel.dock.refresh()
                        var profile = appModel.activeProfile
                        profile.dock = appModel.dock.currentSettings
                        appModel.updateActiveProfile(profile)
                    }
                    .help("Replace the values on this page with the Dock's current settings")
                    Button("Apply to the Dock…") {
                        showingApplyConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(pendingChanges.isEmpty)
                }
            } header: {
                Text("Apply")
            } footer: {
                SettingsFooter("These are staged here and only reach the real Dock when you apply them. Applying restarts the Dock, which takes a moment.")
            }

            if appModel.store.config.profiles.count > 1 {
                Section {
                    DockProfilesDisclosure(
                        profiles: appModel.store.config.profiles,
                        activeProfileID: appModel.activeProfile.id
                    )
                }
            }
        }
        .onAppear { appModel.dock.refresh() }
        .confirmationDialog("Apply these settings to the Dock?", isPresented: $showingApplyConfirmation) {
            Button("Apply and Restart the Dock") {
                appModel.dock.apply(appModel.activeProfile.dock)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("macMender writes these to your Dock preferences and restarts the Dock so they take effect.")
        }
        .confirmationDialog("Restore the Dock to macOS defaults?", isPresented: $showingDockResetConfirmation) {
            Button("Restore and Restart the Dock", role: .destructive) {
                appModel.dock.resetToMacOSDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes the Dock settings macMender has written and restarts the Dock.")
        }
    }

    /// Growing the icons past the magnified size would make them shrink under the pointer.
    private var sizeBinding: Binding<Double> {
        Binding {
            dock.size
        } set: { newValue in
            var profile = appModel.activeProfile
            profile.dock.size = newValue
            profile.dock.magnificationSize = max(profile.dock.magnificationSize, newValue)
            appModel.updateActiveProfile(profile)
        }
    }

    private var pendingChanges: [String] {
        appModel.dock.diff(from: appModel.dock.currentSettings, to: appModel.activeProfile.dock)
    }

    @ViewBuilder
    private var dockChangesSummary: some View {
        let changes = pendingChanges
        if changes.isEmpty {
            Label("The Dock already matches these settings.", systemImage: "checkmark.circle.fill")
                .symbolRenderingMode(.multicolor)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Text(changes.count == 1 ? "1 change to apply" : "\(changes.count) changes to apply")
                    .fontWeight(.medium)
                ForEach(changes, id: \.self) { change in
                    Text("• \(change)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
