import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct DockWindowsView: View {
    @ObservedObject var appModel: AppModel
    @State private var selectedArea = DockArea.initial
    @State private var showingApplyConfirmation = false
    @State private var showingDockResetConfirmation = false

    private enum DockArea: String, CaseIterable, Identifiable {
        case switcher = "Window Switcher"
        case previews = "Dock Previews"
        case settings = "Dock Settings"

        var id: String { rawValue }

        static var initial: DockArea {
            #if DEBUG
            // Development aid: open straight to one area when taking screenshots.
            if let name = ProcessInfo.processInfo.environment["MACMENDER_DOCK_AREA"],
               let area = allCases.first(where: { $0.rawValue.localizedCaseInsensitiveContains(name) }) {
                return area
            }
            #endif
            return .switcher
        }
    }

    var body: some View {
        MacMenderScrollablePage(maxContentWidth: 880) {
            MacMenderPageHeader(
                title: "Dock & Windows",
                subtitle: "Choose how windows appear, tune Dock previews, and apply Dock preferences deliberately.",
                systemImage: SettingsSection.dockWindows.symbolName
            )

            MacMenderCallout(systemImage: SettingsSection.profiles.symbolName) {
                Text("These settings follow the **\(appModel.activeProfile.name)** profile.")
                    .foregroundStyle(.secondary)
            }

            Picker("Dock Area", selection: $selectedArea) {
                ForEach(DockArea.allCases) { area in
                    Text(area.rawValue).tag(area)
                }
            }
            .pickerStyle(.segmented)

            switch selectedArea {
            case .switcher:
                switcherSection
            case .previews:
                previewsSection
            case .settings:
                dockSettingsSection
            }
        }
        .confirmationDialog("Apply Dock settings?", isPresented: $showingApplyConfirmation) {
            Button("Apply and Restart Dock") {
                appModel.dock.apply(appModel.activeProfile.dock)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Dock changes are written to your user Dock preferences. macMender will restart Dock so macOS reloads them.")
        }
        .confirmationDialog("Reset Dock to macOS defaults?", isPresented: $showingDockResetConfirmation) {
            Button("Reset and Restart Dock", role: .destructive) {
                appModel.dock.resetToMacOSDefaults()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes macMender-managed Dock defaults and restarts Dock.")
        }
    }

    private var switcherSection: some View {
        MacMenderContentSection(
            title: "Window Switcher",
            subtitle: "Cycle through real application windows. Hold Shift to cycle backwards; release the shortcut modifier to switch, or press Escape to cancel.",
            systemImage: "rectangle.3.group"
        ) {
            VStack(alignment: .leading, spacing: MacMenderSpacing.section) {
                Toggle("Enable Window Switcher", isOn: binding(\.windowSwitcher.enabled))

                Picker("Shortcut", selection: binding(\.windowSwitcher.shortcut)) {
                    Text("Option+Tab").tag("Option+Tab")
                    Text("Control+Tab").tag("Control+Tab")
                    Text("Option+Space").tag("Option+Space")
                    Text("Control+Space").tag("Control+Space")
                }

                Picker("Layout", selection: binding(\.windowSwitcher.layout)) {
                    ForEach(SwitcherLayout.allCases) { layout in
                        Text(layout.title).tag(layout)
                    }
                }

                LabeledSlider(
                    title: "Thumbnail Size",
                    value: binding(\.windowSwitcher.thumbnailSize),
                    range: 96...280,
                    step: 4,
                    valueLabel: appModel.activeProfile.windowSwitcher.thumbnailSize.wholeNumberLabel
                )

                HStack(spacing: MacMenderSpacing.section) {
                    Toggle("Include minimized windows", isOn: binding(\.windowSwitcher.includeMinimizedWindows))
                    Toggle("Include hidden apps", isOn: binding(\.windowSwitcher.includeHiddenApps))
                }
                Toggle("Include windows on other Spaces and in full screen", isOn: binding(\.windowSwitcher.includeOtherSpaces))

                Divider()

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: MacMenderSpacing.small) {
                        switcherStatusLabels
                    }
                    VStack(alignment: .leading, spacing: MacMenderSpacing.small) {
                        switcherStatusLabels
                    }
                }

                HStack(spacing: MacMenderSpacing.small) {
                    Button("Refresh Windows") {
                        appModel.windowSwitcher.refreshDiscovery(settings: appModel.activeProfile.windowSwitcher)
                    }
                    Button("Test Switcher") {
                        appModel.windowSwitcher.show(settings: appModel.activeProfile.windowSwitcher)
                    }
                }

                WindowDiscoveryDiagnosticsView(
                    report: appModel.windowSwitcher.lastDiscoveryReport,
                    hasRunDiscovery: appModel.windowSwitcher.hasRunWindowDiscovery,
                    activationDiagnostic: appModel.windowSwitcher.lastActivationDiagnostic
                )
            }
        }
    }

    private var previewsSection: some View {
        MacMenderContentSection(
            title: "Dock Previews",
            subtitle: "Rest the pointer on a Dock icon to see that app's windows. Click one to bring it forward, or use its buttons to close, minimize, or go full screen.",
            systemImage: "dock.arrow.up.rectangle"
        ) {
            VStack(alignment: .leading, spacing: MacMenderSpacing.section) {
                Toggle("Enable Dock Previews", isOn: binding(\.dockPreviews.enabled))

                if appModel.permissions.screenRecording != .granted {
                    MacMenderCallout(systemImage: "rectangle.dashed", tone: .attention) {
                        Text("Without Screen Recording permission, previews show app icons instead of window contents. Grant it in **Privacy**.")
                            .foregroundStyle(.secondary)
                    }
                }

                LabeledSlider(
                    title: "Preview Size",
                    value: binding(\.dockPreviews.previewSize),
                    range: DockPreviewSettings.previewSizeRange,
                    step: 2,
                    valueLabel: appModel.activeProfile.dockPreviews.previewSize.wholeNumberLabel
                )
                LabeledSlider(
                    title: "Hover Delay",
                    value: binding(\.dockPreviews.hoverDelay),
                    range: DockPreviewSettings.hoverDelayRange,
                    step: 0.05,
                    valueLabel: "\(appModel.activeProfile.dockPreviews.hoverDelay.sliderValueLabel)s"
                )
                LabeledSlider(
                    title: "Stay Open After Leaving",
                    value: binding(\.dockPreviews.dismissDelay),
                    range: DockPreviewSettings.dismissDelayRange,
                    step: 0.05,
                    valueLabel: "\(appModel.activeProfile.dockPreviews.dismissDelay.sliderValueLabel)s"
                )

                Divider()

                VStack(alignment: .leading, spacing: MacMenderSpacing.small) {
                    Toggle("Show the app name with Hide and Quit buttons", isOn: binding(\.dockPreviews.showAppHeader))
                    Toggle("Show window titles", isOn: binding(\.dockPreviews.showTitles))
                    Toggle("Show close, minimize, and full screen buttons", isOn: binding(\.dockPreviews.showWindowControls))
                    Toggle("Keep previews live while open", isOn: binding(\.dockPreviews.livePreviews))
                    Toggle("Show the window at full size when the pointer rests on its preview", isOn: binding(\.dockPreviews.peekOnHover))
                    Toggle("Use arrow keys, Return, and Escape while the pointer is over a preview", isOn: binding(\.dockPreviews.keyboardNavigation))
                }

                VStack(alignment: .leading, spacing: MacMenderSpacing.small) {
                    Text("Include")
                        .font(.subheadline.weight(.medium))
                    Toggle("Minimized windows", isOn: binding(\.dockPreviews.includeMinimizedWindows))
                    Toggle("Windows of hidden apps", isOn: binding(\.dockPreviews.includeHiddenApps))
                    Toggle("Windows on other Spaces and in full screen", isOn: binding(\.dockPreviews.includeOtherSpaces))
                }

                excludedAppsEditor

                Divider()

                Picker("Animation", selection: binding(\.dockPreviews.animationStyle)) {
                    ForEach(DockPreviewAnimationStyle.selectableCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                LabeledSlider(
                    title: "Animation Duration",
                    value: binding(\.dockPreviews.animationDuration),
                    range: DockPreviewSettings.animationDurationRange,
                    step: 0.01,
                    valueLabel: "\(appModel.activeProfile.dockPreviews.animationDuration.sliderValueLabel)s"
                )

                Divider()

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: MacMenderSpacing.small) {
                        dockPreviewStatusLabels
                    }
                    VStack(alignment: .leading, spacing: MacMenderSpacing.small) {
                        dockPreviewStatusLabels
                    }
                }

                HStack(spacing: MacMenderSpacing.small) {
                    Button("Show a Preview") {
                        appModel.dockPreview.showSamplePreview()
                    }
                    .disabled(!appModel.activeProfile.dockPreviews.enabled)
                    Button("Reset to Defaults") {
                        var profile = appModel.activeProfile
                        profile.dockPreviews = .default
                        appModel.updateActiveProfile(profile)
                    }
                    .disabled(appModel.activeProfile.dockPreviews == .default)
                }

                Text("Middle-click a preview to close its window. Right-click to move and resize it. Drag a file onto a preview to bring that window forward. Minimized windows in the Dock show a preview too.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    /// Applications that never show a Dock preview.
    private var excludedAppsEditor: some View {
        let excluded = appModel.activeProfile.dockPreviews.excludedBundleIdentifiers
        let candidates = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .compactMap { app in app.bundleIdentifier.map { (id: $0, name: app.localizedName ?? $0) } }
            .filter { !excluded.contains($0.id) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return VStack(alignment: .leading, spacing: MacMenderSpacing.small) {
            Text("No Previews For")
                .font(.subheadline.weight(.medium))
            if excluded.isEmpty {
                Text("Every app shows previews.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(excluded, id: \.self) { bundleIdentifier in
                HStack(spacing: MacMenderSpacing.small) {
                    Text(Self.applicationName(for: bundleIdentifier))
                    Spacer()
                    Button {
                        setExcludedApps(excluded.filter { $0 != bundleIdentifier })
                    } label: {
                        Image(systemName: "minus.circle")
                    }
                    .buttonStyle(.borderless)
                    .help("Show previews for this app again")
                    .accessibilityLabel("Remove \(Self.applicationName(for: bundleIdentifier))")
                }
            }
            HStack(spacing: MacMenderSpacing.small) {
                Menu("Add Running App") {
                    ForEach(candidates, id: \.id) { candidate in
                        Button(candidate.name) { setExcludedApps(excluded + [candidate.id]) }
                    }
                }
                .disabled(candidates.isEmpty)
                .fixedSize()
                Button("Choose App…") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.application]
                    panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
                    panel.allowsMultipleSelection = false
                    guard panel.runModal() == .OK, let url = panel.url,
                          let bundleIdentifier = Bundle(url: url)?.bundleIdentifier,
                          !excluded.contains(bundleIdentifier) else {
                        return
                    }
                    setExcludedApps(excluded + [bundleIdentifier])
                }
            }
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

    @ViewBuilder
    private var switcherStatusLabels: some View {
        MacMenderStatusLabel(
            title: appModel.permissions.screenRecording == .granted ? "Thumbnails available" : "Icon fallback",
            tone: appModel.permissions.screenRecording == .granted ? .active : .attention,
            systemImage: "rectangle.on.rectangle"
        )
        MacMenderStatusLabel(
            title: appModel.windowSwitcher.presentationStatus,
            tone: appModel.windowSwitcher.isShowing ? .active : .neutral,
            systemImage: appModel.windowSwitcher.isShowing ? "rectangle.stack.fill" : "info.circle"
        )
    }

    @ViewBuilder
    private var dockPreviewStatusLabels: some View {
        MacMenderStatusLabel(
            title: appModel.dockHover.isRunning ? "Dock previews active" : "Dock previews paused",
            tone: appModel.dockHover.isRunning ? .active : .paused,
            systemImage: appModel.dockHover.isRunning ? "dot.radiowaves.left.and.right" : "pause.circle"
        )
        if let app = appModel.dockHover.lastHoveredApp {
            MacMenderStatusLabel(
                title: "Hovering \(app)",
                tone: .neutral,
                systemImage: "cursorarrow.motionlines"
            )
        }
    }

    private var dockSettingsSection: some View {
        MacMenderContentSection(
            title: "Dock Settings",
            subtitle: "Preview changes here, then apply them explicitly to the macOS Dock.",
            systemImage: "dock.rectangle"
        ) {
            VStack(alignment: .leading, spacing: MacMenderSpacing.section) {
                DockSettingsPreview(settings: appModel.activeProfile.dock)

                LabeledSlider(
                    title: "Size",
                    value: binding(\.dock.size),
                    range: 24...96,
                    step: 1,
                    valueLabel: appModel.activeProfile.dock.size.wholeNumberLabel
                )
                Toggle("Magnification", isOn: binding(\.dock.magnificationEnabled))
                LabeledSlider(
                    title: "Magnification Size",
                    value: binding(\.dock.magnificationSize),
                    range: 32...128,
                    step: 1,
                    valueLabel: appModel.activeProfile.dock.magnificationSize.wholeNumberLabel
                )
                Picker("Position", selection: binding(\.dock.position)) {
                    ForEach(DockPosition.allCases) { position in
                        Text(position.title).tag(position)
                    }
                }
                Toggle("Auto-hide", isOn: binding(\.dock.autoHide))
                LabeledSlider(
                    title: "Auto-hide Delay",
                    value: binding(\.dock.autoHideDelay),
                    range: 0...2,
                    step: 0.05,
                    valueLabel: "\(appModel.activeProfile.dock.autoHideDelay.sliderValueLabel)s"
                )
                LabeledSlider(
                    title: "Animation Speed",
                    value: binding(\.dock.autoHideAnimationSpeed),
                    range: 0...1,
                    step: 0.05,
                    valueLabel: "\(appModel.activeProfile.dock.autoHideAnimationSpeed.sliderValueLabel)s"
                )
                Toggle("Show recent apps", isOn: binding(\.dock.showRecentApps))
                Toggle("Show indicators for open apps", isOn: binding(\.dock.showIndicators))

                dockChangesSummary

                HStack {
                    Button("Read Current Dock") {
                        appModel.dock.refresh()
                    }
                    Button("Apply Profile to Dock") {
                        showingApplyConfirmation = true
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Reset Dock Defaults", role: .destructive) {
                        showingDockResetConfirmation = true
                    }
                }

                Divider()

                DockProfilesDisclosure(
                    profiles: appModel.store.config.profiles,
                    activeProfileID: appModel.activeProfile.id
                )
            }
        }
    }

    @ViewBuilder
    private var dockChangesSummary: some View {
        let changes = appModel.dock.diff(
            from: appModel.dock.currentSettings,
            to: appModel.activeProfile.dock
        )

        if changes.isEmpty {
            MacMenderCallout(systemImage: "checkmark.circle.fill", tone: .active) {
                Text("Current Dock settings already match this profile.")
                    .foregroundStyle(.secondary)
            }
        } else {
            MacMenderCallout(systemImage: "exclamationmark.circle", tone: .attention) {
                VStack(alignment: .leading, spacing: MacMenderSpacing.compact) {
                    Text("Pending Changes")
                        .fontWeight(.medium)
                    ForEach(changes, id: \.self) { change in
                        Text("• \(change)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<MacMenderProfile, Value>) -> Binding<Value> {
        Binding {
            appModel.activeProfile[keyPath: keyPath]
        } set: { newValue in
            var profile = appModel.activeProfile
            profile[keyPath: keyPath] = newValue
            appModel.updateActiveProfile(profile)
        }
    }
}
