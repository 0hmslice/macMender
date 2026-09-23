import AppKit
import SwiftUI

struct DockWindowsView: View {
    @ObservedObject var appModel: AppModel
    @State private var selectedArea = DockArea.switcher
    @State private var showingApplyConfirmation = false
    @State private var showingDockResetConfirmation = false

    private enum DockArea: String, CaseIterable, Identifiable {
        case switcher = "Window Switcher"
        case previews = "Dock Previews"
        case settings = "Dock Settings"

        var id: String { rawValue }
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
            subtitle: "Show a window preview after hovering over an application in the Dock.",
            systemImage: "dock.arrow.up.rectangle"
        ) {
            VStack(alignment: .leading, spacing: MacMenderSpacing.section) {
                Toggle("Enable Dock Previews", isOn: binding(\.dockPreviews.enabled))

                LabeledSlider(
                    title: "Hover Delay",
                    value: binding(\.dockPreviews.hoverDelay),
                    range: 0.1...1.2,
                    step: 0.05,
                    valueLabel: "\(appModel.activeProfile.dockPreviews.hoverDelay.sliderValueLabel)s"
                )
                LabeledSlider(
                    title: "Preview Linger",
                    value: binding(\.dockPreviews.previewIdleTimeout),
                    range: 0...10.0,
                    step: 0.1,
                    valueLabel: "\(appModel.activeProfile.dockPreviews.previewIdleTimeout.sliderValueLabel)s"
                )
                Picker("Preview Animation", selection: binding(\.dockPreviews.animationStyle)) {
                    ForEach(DockPreviewAnimationStyle.selectableCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                LabeledSlider(
                    title: "Animation Duration",
                    value: binding(\.dockPreviews.animationDuration),
                    range: 0.05...0.60,
                    step: 0.01,
                    valueLabel: "\(appModel.activeProfile.dockPreviews.animationDuration.sliderValueLabel)s"
                )
                Text("Controls how quickly preview windows appear and disappear.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Picker("Preview Layout", selection: binding(\.dockPreviews.layout)) {
                    ForEach(SwitcherLayout.allCases) { layout in
                        Text(layout.title).tag(layout)
                    }
                }
                LabeledSlider(
                    title: "Preview Size",
                    value: binding(\.dockPreviews.thumbnailSize),
                    range: 96...280,
                    step: 4,
                    valueLabel: appModel.activeProfile.dockPreviews.thumbnailSize.wholeNumberLabel
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
                    Button("Refresh Status") {
                        appModel.refreshSystemState(force: true)
                    }
                    Button("Test Preview Animation") {
                        testDockPreviewAnimation()
                    }
                }

                DisclosureGroup("Preview Diagnostics") {
                    Text("Thumbnail status: \(appModel.windowSwitcher.lastThumbnailDiagnostic)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.top, MacMenderSpacing.small)
                }
                .font(.caption)
            }
        }
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

    private func testDockPreviewAnimation() {
        let screenFrame = NSApp.keyWindow?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let anchor = CGRect(x: screenFrame.midX - 30, y: screenFrame.minY + 8, width: 60, height: 60)
        appModel.windowSwitcher.showDockPreviewAnimationSample(
            settings: appModel.activeProfile.dockPreviews.overlaySettings(using: appModel.activeProfile.windowSwitcher),
            anchorFrame: anchor
        )
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
