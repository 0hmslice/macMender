import AppKit
import SwiftUI

struct InputScrollingView: View {
    @ObservedObject var appModel: AppModel
    @State private var selectedRunningAppBundleID = ""
    @State private var runningAppOptions: [RunningAppOption] = []

    var body: some View {
        MacMenderScrollablePage(maxContentWidth: 860) {
            MacMenderPageHeader(
                title: "Mouse & Trackpad",
                subtitle: "Tune scrolling and Three-Finger Tap for the active profile.",
                systemImage: SettingsSection.input.symbolName
            )

            MacMenderCallout(systemImage: SettingsSection.profiles.symbolName) {
                Text("These settings follow the **\(appModel.activeProfile.name)** profile.")
                    .foregroundStyle(.secondary)
            }

            scrollingSection
            deviceRulesSection
            appOverridesSection
            middleClickSection
        }
        .onAppear(perform: refreshRunningApps)
    }

    private var scrollingSection: some View {
        MacMenderContentSection(
            title: "Scrolling",
            subtitle: "Set direction and smoothing for each axis. Safe Mode pauses event modification.",
            systemImage: "scroll"
        ) {
            let profile = appModel.activeProfile

            VStack(alignment: .leading, spacing: MacMenderSpacing.section) {
                Picker("Preset", selection: presetBinding) {
                    ForEach(SmoothingPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.segmented)

                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 12) {
                    GridRow {
                        Text("Vertical")
                            .fontWeight(.medium)
                        Toggle("Smooth", isOn: binding(\.scroll.verticalSmoothingEnabled))
                            .accessibilityLabel("Smooth vertical scrolling")
                        Toggle("Reverse", isOn: binding(\.scroll.reverseVertical))
                            .accessibilityLabel("Reverse vertical scrolling")
                    }

                    GridRow {
                        Text("Horizontal")
                            .fontWeight(.medium)
                        Toggle("Smooth", isOn: binding(\.scroll.horizontalSmoothingEnabled))
                            .accessibilityLabel("Smooth horizontal scrolling")
                        Toggle("Reverse", isOn: binding(\.scroll.reverseHorizontal))
                            .accessibilityLabel("Reverse horizontal scrolling")
                    }
                }

                Text("Reverse changes the natural scroll direction for the selected axis.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                LabeledSlider(
                    title: "Step",
                    value: binding(\.scroll.step),
                    range: 0.25...6,
                    step: 0.25,
                    valueLabel: profile.scroll.step.sliderValueLabel
                )
                LabeledSlider(
                    title: "Gain",
                    value: binding(\.scroll.gain),
                    range: 0.5...3,
                    step: 0.05,
                    valueLabel: profile.scroll.gain.sliderValueLabel
                )
                LabeledSlider(
                    title: "Duration",
                    value: binding(\.scroll.duration),
                    range: 0...0.5,
                    step: 0.01,
                    valueLabel: "\(profile.scroll.duration.sliderValueLabel)s"
                )

                ScrollPreview(settings: profile.scroll)
            }
        }
    }

    private var deviceRulesSection: some View {
        MacMenderContentSection(
            title: "Device Behavior",
            subtitle: "Trackpads and mice can use different direction and smoothing rules.",
            systemImage: "sensor"
        ) {
            VStack(spacing: 0) {
                ForEach(Array(appModel.activeProfile.scroll.deviceRules.enumerated()), id: \.element.id) { index, rule in
                    DeviceRuleRow(
                        rule: rule,
                        smoothing: deviceRuleBinding(rule.id, \.smoothingEnabled),
                        reverseVertical: deviceRuleBinding(rule.id, \.reverseVertical),
                        reverseHorizontal: deviceRuleBinding(rule.id, \.reverseHorizontal)
                    )

                    if index < appModel.activeProfile.scroll.deviceRules.count - 1 {
                        Divider()
                    }
                }
            }

            Text("Physical-device matching is best-effort with public macOS APIs.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var appOverridesSection: some View {
        MacMenderContentSection(
            title: "App Overrides",
            subtitle: "Choose different scroll behavior for a specific application.",
            systemImage: "app.connected.to.app.below.fill"
        ) {
            VStack(alignment: .leading, spacing: MacMenderSpacing.standard) {
                HStack {
                    Picker("Running App", selection: selectedRunningAppBinding) {
                        if runningAppOptions.isEmpty {
                            Text("No running apps").tag("")
                        } else {
                            ForEach(runningAppOptions) { option in
                                Text(option.name).tag(option.bundleIdentifier)
                            }
                        }
                    }
                    .frame(maxWidth: 340)

                    Button("Add Override") {
                        addSelectedRunningAppRule()
                    }
                    .disabled(selectedRunningAppBinding.wrappedValue.isEmpty || selectedRunningAppAlreadyExists)

                    Button {
                        refreshRunningApps()
                    } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .help("Refresh running applications")
                }

                if appModel.activeProfile.scroll.appRules.isEmpty {
                    MacMenderEmptyState(
                        title: "No App Overrides",
                        message: "Applications inherit this profile until you add an override.",
                        systemImage: "square.stack.3d.up.slash"
                    )
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(appModel.activeProfile.scroll.appRules.enumerated()), id: \.element.id) { index, rule in
                            AppOverrideRow(
                                rule: rule,
                                smoothing: appRuleBinding(rule.id, \.smoothingOverride),
                                reverseVertical: appRuleBinding(rule.id, \.reverseVerticalOverride),
                                reverseHorizontal: appRuleBinding(rule.id, \.reverseHorizontalOverride),
                                deleteAction: { deleteAppRule(rule.id) }
                            )

                            if index < appModel.activeProfile.scroll.appRules.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private var middleClickSection: some View {
        MacMenderContentSection(
            title: "Three-Finger Tap",
            subtitle: middleClickSubtitle,
            systemImage: "hand.tap"
        ) {
            VStack(alignment: .leading, spacing: MacMenderSpacing.standard) {
                Toggle("Enable Three-Finger Tap", isOn: binding(\.middleClick.enabled))

                Picker("Trigger", selection: binding(\.middleClick.trigger)) {
                    ForEach(MiddleClickTrigger.runtimeSupportedCases) { trigger in
                        Text(trigger.title).tag(trigger)
                    }
                }

                Picker("Action", selection: binding(\.middleClick.action)) {
                    ForEach(MiddleClickAction.runtimeSupportedCases) { action in
                        Text(action.title).tag(action)
                    }
                }

                HStack {
                    MacMenderStatusLabel(
                        title: appModel.permissions.accessibility == .granted ? "Accessibility granted" : "Needs Accessibility",
                        tone: appModel.permissions.accessibility == .granted ? .active : .attention,
                        systemImage: "lock.shield"
                    )
                    MacMenderStatusLabel(
                        title: middleClickRuntimeTitle,
                        tone: middleClickRuntimeTone,
                        systemImage: middleClickRuntimeSymbol
                    )
                }
            }
        }
    }

    private var middleClickSubtitle: String {
        let settings = appModel.activeProfile.middleClick
        guard settings.enabled else {
            return "Use a three-finger tap as middle click when this is enabled."
        }
        guard appModel.permissions.accessibility == .granted else {
            return "Waiting for Accessibility before middle-click actions can run."
        }
        guard !appModel.store.config.safeModeEnabled else {
            return "Paused by Safe Mode."
        }
        if settings.trigger == .experimentalThreeFinger {
            return "Open links in new tabs, close tabs, and use middle-click actions without a mouse wheel."
        }
        return "Middle-click actions are set up for the selected trigger."
    }

    private var middleClickRuntimeTitle: String {
        let settings = appModel.activeProfile.middleClick
        guard settings.enabled else { return "Off" }
        guard appModel.permissions.accessibility == .granted else { return "Waiting for Accessibility" }
        guard !appModel.store.config.safeModeEnabled else { return "Paused by Safe Mode" }

        if settings.trigger == .experimentalThreeFinger {
            return appModel.multitouchMiddleClick.lastStatus
        }

        return appModel.systemEvents.status.eventTapRunning ? "Handled by event tap" : "Starting event tap"
    }

    private var middleClickRuntimeSymbol: String {
        let settings = appModel.activeProfile.middleClick
        guard settings.enabled else { return "pause.circle" }
        if settings.trigger == .experimentalThreeFinger {
            return appModel.multitouchMiddleClick.isRunning ? "hand.tap.fill" : "hand.tap"
        }
        return appModel.systemEvents.status.eventTapRunning ? "dot.radiowaves.left.and.right" : "circle.dashed"
    }

    private var middleClickRuntimeTone: MacMenderStatusTone {
        let settings = appModel.activeProfile.middleClick
        guard settings.enabled else { return .neutral }
        guard appModel.permissions.accessibility == .granted else { return .attention }
        guard !appModel.store.config.safeModeEnabled else { return .paused }

        if settings.trigger == .experimentalThreeFinger {
            return appModel.multitouchMiddleClick.isRunning ? .active : .attention
        }

        return appModel.systemEvents.status.eventTapRunning ? .active : .attention
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

    private var presetBinding: Binding<SmoothingPreset> {
        Binding {
            appModel.activeProfile.scroll.preset
        } set: { preset in
            var profile = appModel.activeProfile
            let existingDeviceRules = profile.scroll.deviceRules
            let existingAppRules = profile.scroll.appRules

            switch preset {
            case .off:
                profile.scroll = .raw
            case .subtle:
                profile.scroll = .subtle
            case .balanced:
                profile.scroll = .balanced
            case .smooth:
                profile.scroll = ScrollSettings(
                    preset: .smooth,
                    verticalSmoothingEnabled: true,
                    horizontalSmoothingEnabled: true,
                    reverseVertical: profile.scroll.reverseVertical,
                    reverseHorizontal: profile.scroll.reverseHorizontal,
                    step: 1.25,
                    gain: 1.35,
                    duration: 0.24,
                    deviceRules: existingDeviceRules,
                    appRules: existingAppRules
                )
            case .custom:
                profile.scroll.preset = .custom
            }

            if preset != .custom {
                profile.scroll.deviceRules = existingDeviceRules
                profile.scroll.appRules = existingAppRules
            }
            appModel.updateActiveProfile(profile)
        }
    }

    private func deviceRuleBinding<Value>(
        _ ruleID: UUID,
        _ keyPath: WritableKeyPath<DeviceScrollRule, Value>
    ) -> Binding<Value> {
        Binding {
            guard let rule = appModel.activeProfile.scroll.deviceRules.first(where: { $0.id == ruleID }) else {
                return DeviceScrollRule.defaults[0][keyPath: keyPath]
            }
            return rule[keyPath: keyPath]
        } set: { newValue in
            var profile = appModel.activeProfile
            guard let index = profile.scroll.deviceRules.firstIndex(where: { $0.id == ruleID }) else { return }
            profile.scroll.deviceRules[index][keyPath: keyPath] = newValue
            profile.scroll.preset = .custom
            appModel.updateActiveProfile(profile)
        }
    }

    private var selectedRunningAppBinding: Binding<String> {
        Binding {
            if selectedRunningAppBundleID.isEmpty ||
                !runningAppOptions.contains(where: { $0.bundleIdentifier == selectedRunningAppBundleID }) {
                return runningAppOptions.first?.bundleIdentifier ?? ""
            }
            return selectedRunningAppBundleID
        } set: { newValue in
            selectedRunningAppBundleID = newValue
        }
    }

    private var selectedRunningAppAlreadyExists: Bool {
        appModel.activeProfile.scroll.appRules.contains {
            $0.bundleIdentifier == selectedRunningAppBinding.wrappedValue
        }
    }

    private func refreshRunningApps() {
        runningAppOptions = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .compactMap { app -> RunningAppOption? in
                guard let bundleIdentifier = app.bundleIdentifier else { return nil }
                return RunningAppOption(
                    bundleIdentifier: bundleIdentifier,
                    name: app.localizedName ?? bundleIdentifier
                )
            }
            .uniquedByBundleIdentifier()
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        if !runningAppOptions.contains(where: { $0.bundleIdentifier == selectedRunningAppBundleID }) {
            selectedRunningAppBundleID = runningAppOptions.first?.bundleIdentifier ?? ""
        }
    }

    private func addSelectedRunningAppRule() {
        let bundleID = selectedRunningAppBinding.wrappedValue
        guard !bundleID.isEmpty,
              !appModel.activeProfile.scroll.appRules.contains(where: { $0.bundleIdentifier == bundleID }),
              let option = runningAppOptions.first(where: { $0.bundleIdentifier == bundleID }) else {
            return
        }

        var profile = appModel.activeProfile
        profile.scroll.appRules.append(
            AppScrollRule(
                bundleIdentifier: option.bundleIdentifier,
                appName: option.name,
                smoothingOverride: nil,
                reverseVerticalOverride: nil,
                reverseHorizontalOverride: nil
            )
        )
        appModel.updateActiveProfile(profile)
    }

    private func deleteAppRule(_ ruleID: UUID) {
        var profile = appModel.activeProfile
        profile.scroll.appRules.removeAll { $0.id == ruleID }
        appModel.updateActiveProfile(profile)
    }

    private func appRuleBinding<Value>(
        _ ruleID: UUID,
        _ keyPath: WritableKeyPath<AppScrollRule, Value>
    ) -> Binding<Value> {
        Binding {
            guard let rule = appModel.activeProfile.scroll.appRules.first(where: { $0.id == ruleID }) else {
                return AppScrollRule(
                    bundleIdentifier: "",
                    appName: "",
                    smoothingOverride: nil,
                    reverseVerticalOverride: nil
                )[keyPath: keyPath]
            }
            return rule[keyPath: keyPath]
        } set: { newValue in
            var profile = appModel.activeProfile
            guard let index = profile.scroll.appRules.firstIndex(where: { $0.id == ruleID }) else { return }
            profile.scroll.appRules[index][keyPath: keyPath] = newValue
            appModel.updateActiveProfile(profile)
        }
    }
}
