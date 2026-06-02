import AppKit
import SwiftUI

struct DockWindowsView: View {
    @ObservedObject var appModel: AppModel
    @State private var tab = DockTab.switcher
    @State private var showingApplyConfirmation = false
    @State private var showingDockResetConfirmation = false

    enum DockTab: String, CaseIterable, Identifiable {
        case switcher = "Switcher"
        case previews = "Dock Previews"
        case settings = "Dock Settings"
        case profiles = "Dock Profiles"
        var id: String { rawValue }
    }

    var body: some View {
        PreferencesScrollView {
            Picker("Dock Area", selection: $tab) {
                ForEach(DockTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            switch tab {
            case .switcher:
                switcherView
            case .previews:
                previewsView
            case .settings:
                settingsView
            case .profiles:
                profilesView
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

    private var switcherView: some View {
        SectionCard(title: "Window Switcher", subtitle: "Choose how Option+Tab shows open windows.", symbolName: "rectangle.3.group") {
            VStack(alignment: .leading, spacing: 14) {
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
                Toggle("Include minimized windows", isOn: binding(\.windowSwitcher.includeMinimizedWindows))
                Toggle("Include hidden apps", isOn: binding(\.windowSwitcher.includeHiddenApps))
                HStack {
                    CapabilityBadge(title: appModel.permissions.screenRecording == .granted ? "Thumbnails Available" : "Icon Fallback", systemImage: "rectangle.on.rectangle", tone: appModel.permissions.screenRecording == .granted ? .active : .warning)
                    CapabilityBadge(title: appModel.windowSwitcher.presentationStatus, systemImage: appModel.windowSwitcher.isShowing ? "rectangle.stack.fill" : "info.circle", tone: appModel.windowSwitcher.isShowing ? .active : .neutral)
                    Spacer()
                    Button("Refresh Discovery") {
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

    private var previewsView: some View {
        SectionCard(title: "Dock Previews", subtitle: "Preview an app's windows when you hover its Dock icon.", symbolName: "dock.arrow.up.rectangle") {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Enable Dock Previews", isOn: binding(\.dockPreviews.enabled))
                LabeledSlider(
                    title: "Hover Delay",
                    value: binding(\.dockPreviews.hoverDelay),
                    range: 0.1...1.2,
                    step: 0.05,
                    valueLabel: "\(appModel.activeProfile.dockPreviews.hoverDelay.sliderValueLabel)s"
                )
                LabeledSlider(
                    title: "Preview linger after leaving Dock",
                    value: binding(\.dockPreviews.previewIdleTimeout),
                    range: 0...10.0,
                    step: 0.1,
                    valueLabel: "\(appModel.activeProfile.dockPreviews.previewIdleTimeout.sliderValueLabel)s"
                )
                Picker("Preview animation", selection: binding(\.dockPreviews.animationStyle)) {
                    ForEach(DockPreviewAnimationStyle.allCases) { style in
                        Text(style.title).tag(style)
                    }
                }
                LabeledSlider(
                    title: "Animation duration",
                    value: binding(\.dockPreviews.animationDuration),
                    range: 0.05...0.60,
                    step: 0.01,
                    valueLabel: "\(appModel.activeProfile.dockPreviews.animationDuration.sliderValueLabel)s"
                )
                Text("How long Dock preview animations take.")
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

                HStack {
                    CapabilityBadge(
                        title: appModel.dockHover.isRunning ? "Dock previews are active" : "Dock previews are paused",
                        systemImage: appModel.dockHover.isRunning ? "checkmark.circle.fill" : "pause.circle",
                        tone: appModel.dockHover.isRunning ? .active : .warning
                    )
                    if let app = appModel.dockHover.lastHoveredApp {
                        CapabilityBadge(title: "Hovering \(app)", systemImage: "cursorarrow.motionlines", tone: .neutral)
                    }
                    Spacer()
                }

                Text("Choose when previews appear, how long they linger, and how they move.")
                    .foregroundStyle(.secondary)

                DisclosureGroup("Preview diagnostics") {
                    Text("Thumbnail status: \(appModel.windowSwitcher.lastThumbnailDiagnostic)")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .padding(.top, 4)
                }
                .font(.caption)

                HStack {
                    Button("Refresh Status") {
                        appModel.refreshSystemState(force: true)
                    }
                    Button("Test Preview Animation") {
                        testDockPreviewAnimation()
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

    private var settingsView: some View {
        SectionCard(title: "Dock Settings", subtitle: "Preview first, apply explicitly, and keep a recoverable path.", symbolName: "dock.rectangle") {
            VStack(alignment: .leading, spacing: 14) {
                DockPreview(settings: appModel.activeProfile.dock)

                LabeledSlider(title: "Size", value: binding(\.dock.size), range: 24...96, step: 1, valueLabel: appModel.activeProfile.dock.size.wholeNumberLabel)
                Toggle("Magnification", isOn: binding(\.dock.magnificationEnabled))
                LabeledSlider(title: "Magnification Size", value: binding(\.dock.magnificationSize), range: 32...128, step: 1, valueLabel: appModel.activeProfile.dock.magnificationSize.wholeNumberLabel)
                Picker("Position", selection: binding(\.dock.position)) {
                    ForEach(DockPosition.allCases) { position in
                        Text(position.title).tag(position)
                    }
                }
                Toggle("Auto-hide", isOn: binding(\.dock.autoHide))
                LabeledSlider(title: "Auto-hide Delay", value: binding(\.dock.autoHideDelay), range: 0...2, step: 0.05, valueLabel: "\(appModel.activeProfile.dock.autoHideDelay.sliderValueLabel)s")
                LabeledSlider(title: "Animation Speed", value: binding(\.dock.autoHideAnimationSpeed), range: 0...1, step: 0.05, valueLabel: "\(appModel.activeProfile.dock.autoHideAnimationSpeed.sliderValueLabel)s")
                Toggle("Show recent apps", isOn: binding(\.dock.showRecentApps))
                Toggle("Show indicators for open apps", isOn: binding(\.dock.showIndicators))

                let changes = appModel.dock.diff(from: appModel.dock.currentSettings, to: appModel.activeProfile.dock)
                if changes.isEmpty {
                    HStack(spacing: 12) {
                        MendyAvatarView(mood: .success, size: MendyAvatarSize.compact)
                        Text("Current Dock settings already match this profile.")
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack(alignment: .top, spacing: 12) {
                        MendyAvatarView(mood: .scanning, size: MendyAvatarSize.compact)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pending Changes")
                                .font(.subheadline)
                            ForEach(changes, id: \.self) { change in
                                Text(change)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

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
            }
        }
    }

    private var profilesView: some View {
        SectionCard(title: "Dock Profiles", subtitle: "Dock settings are bundled inside each macMender profile.", symbolName: "square.stack.3d.up") {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(appModel.store.config.profiles) { profile in
                    HStack {
                        Label(profile.name, systemImage: profile.symbolName)
                        Spacer()
                        Text("\(profile.dock.position.title), \(Int(profile.dock.size)) px")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
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

private struct WindowDiscoveryDiagnosticsView: View {
    var report: WindowDiscoveryReport
    var hasRunDiscovery: Bool
    var activationDiagnostic: String

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 10) {
                Text("Activation: \(activationDiagnostic)")
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)

                if !hasRunDiscovery {
                    Text("No scan yet. Run Refresh Discovery to list windows.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else if report.appReports.isEmpty {
                    Text("No switchable windows were found in the last scan.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(report.appReports.filter(shouldShowReport)) { appReport in
                        VStack(alignment: .leading, spacing: 5) {
                            Text("\(appReport.appName)  bundle=\(appReport.bundleIdentifier ?? "nil")  pid=\(appReport.processIdentifier)")
                                .font(.caption.weight(.semibold))
                                .textSelection(.enabled)
                            Text("AX windows: \(appReport.axWindowCount)  CG-only: \(appReport.cgOnlyWindowCount)  included: \(appReport.includedCount)  dropped: \(appReport.droppedCount)")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                            ForEach(Array(appReport.entries.prefix(6))) { entry in
                                WindowDiscoveryEntryLineView(entry: entry)
                            }
                            if appReport.entries.count > 6 {
                                Text("\(appReport.entries.count - 6) more windows omitted")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            if let reason = appReport.appDropReason {
                                Text("App drop reason: \(reason)")
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(.orange)
                                    .textSelection(.enabled)
                            }
                        }
                        .padding(10)
                        .liquidGlass(.row)
                    }
                }
            }
            .padding(.top, 8)
        } label: {
            Label("Discovery diagnostics: \(diagnosticsSummary)", systemImage: "list.bullet.rectangle")
                .font(.callout.weight(.semibold))
        }
        .padding(12)
        .liquidGlass(.card)
    }

    private var diagnosticsSummary: String {
        hasRunDiscovery ? report.summary : "No scan yet"
    }

    private func shouldShowReport(_ report: WindowAppDiscoveryReport) -> Bool {
        report.axWindowCount > 0 || report.cgOnlyWindowCount > 0 || report.includedCount > 0 || report.appDropReason != nil
    }

}

private struct WindowDiscoveryEntryLineView: View {
    var entry: WindowDiscoveryEntry

    var body: some View {
        Text(entryLine)
            .font(.caption2.monospaced())
            .foregroundStyle(entry.included ? Color.secondary : Color.orange)
            .textSelection(.enabled)
    }

    private var entryLine: String {
        let state = entry.included ? "included" : "dropped"
        let cgID = entry.cgWindowID.map(String.init) ?? "missing"
        let match = entry.cgMatchFound ? "found" : "missing"
        return "• \(state) title=\"\(entry.title)\" cg=\(cgID) match=\(match) reason=\(entry.reason)"
    }
}

private struct DockPreview: View {
    var settings: DockSettings

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<8, id: \.self) { index in
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(index == 2 ? .blue.opacity(0.65) : .secondary.opacity(0.22))
                    .frame(width: dockItemSize(index), height: dockItemSize(index))
                    .overlay(alignment: .bottom) {
                        if settings.showIndicators && [1, 2, 4].contains(index) {
                            Circle()
                                .fill(.primary.opacity(0.55))
                                .frame(width: 4, height: 4)
                                .offset(y: 8)
                        }
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func dockItemSize(_ index: Int) -> Double {
        guard settings.magnificationEnabled, index == 2 else { return settings.size * 0.7 }
        return settings.magnificationSize * 0.7
    }
}
