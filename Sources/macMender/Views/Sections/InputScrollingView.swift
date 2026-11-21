import AppKit
import SwiftUI

struct InputScrollingView: View {
    @ObservedObject var appModel: AppModel
    @State private var runningAppOptions: [RunningAppOption] = []
    @State private var appSelectionError: String?

    var body: some View {
        SettingsPage(section: .input, profileName: appModel.shouldShowProfileSwitcher ? appModel.activeProfile.name : nil) {
            smoothingSection
            ForEach(visibleDeviceRules) { rule in
                deviceSection(rule)
            }
            appOverridesSection
            middleClickSection
        }
        .onAppear(perform: refreshRunningApps)
    }

    private var isSmoothing: Bool {
        let scroll = appModel.activeProfile.scroll
        return scroll.verticalSmoothingEnabled || scroll.horizontalSmoothingEnabled
    }

    private var smoothingSection: some View {
        let scroll = appModel.activeProfile.scroll

        return Section {
            Picker("Feel", selection: presetBinding) {
                ForEach(SmoothingPreset.allCases.filter { $0 != .custom }) { preset in
                    Text(preset.title).tag(preset)
                }
                if scroll.preset == .custom {
                    Text("Custom").tag(SmoothingPreset.custom)
                }
            }

            Toggle("Smooth vertical scrolling", isOn: binding(\.scroll.verticalSmoothingEnabled))
            Toggle("Smooth horizontal scrolling", isOn: binding(\.scroll.horizontalSmoothingEnabled))

            Group {
                SettingsSlider(
                    title: "Speed",
                    value: binding(\.scroll.gain),
                    range: 0.5...3,
                    step: 0.05,
                    valueLabel: "\(scroll.gain.sliderValueLabel)×",
                    minimumLabel: "Slower",
                    maximumLabel: "Faster"
                )
                SettingsSlider(
                    title: "Glide",
                    detail: "How long each turn of the wheel keeps the page moving.",
                    value: binding(\.scroll.duration),
                    range: 0.04...0.5,
                    step: 0.02,
                    valueLabel: "\(scroll.duration.sliderValueLabel) s",
                    minimumLabel: "Short",
                    maximumLabel: "Long"
                )
                SettingsSlider(
                    title: "Smallest movement",
                    detail: "The least a single notch of the wheel moves the page.",
                    value: binding(\.scroll.step),
                    range: 0.25...6,
                    step: 0.25,
                    valueLabel: "\(scroll.step.sliderValueLabel) pt"
                )
                ScrollPreview(settings: scroll)
            }
            .disabled(!isSmoothing)
        } header: {
            Text("Mouse Wheel Smoothing")
        } footer: {
            SettingsFooter("Smoothing applies to mouse wheels. Trackpads and Magic Mouse keep the momentum macOS gives them.")
        }
    }

    private var visibleDeviceRules: [DeviceScrollRule] {
        appModel.activeProfile.scroll.deviceRules.filter { $0.deviceKind == .builtInTrackpad || $0.deviceKind == .externalMouse }
    }

    private func deviceSection(_ rule: DeviceScrollRule) -> some View {
        let isTrackpad = rule.deviceKind == .builtInTrackpad
        return Section {
            if !isTrackpad {
                SettingsToggle(
                    "Smooth this device",
                    detail: "Uses the smoothing settings above.",
                    isOn: deviceRuleBinding(rule.id, \.smoothingEnabled)
                )
            }
            Toggle("Reverse vertical scrolling", isOn: deviceRuleBinding(rule.id, \.reverseVertical))
            Toggle("Reverse horizontal scrolling", isOn: deviceRuleBinding(rule.id, \.reverseHorizontal))
        } header: {
            Label(
                isTrackpad ? "Trackpads & Magic Mouse" : "Mouse Wheels",
                systemImage: isTrackpad ? "rectangle.and.hand.point.up.left" : "computermouse"
            )
        } footer: {
            if !isTrackpad {
                SettingsFooter("Reversing flips whatever direction macOS is set to, for this kind of device only. This lets a mouse and a trackpad scroll in opposite directions.")
            }
        }
    }

    private var appOverridesSection: some View {
        let rules = appModel.activeProfile.scroll.appRules
        let candidates = runningAppOptions.filter { option in
            !rules.contains { $0.bundleIdentifier == option.bundleIdentifier }
        }

        return Section {
            ForEach(rules) { rule in
                AppOverrideRow(
                    rule: rule,
                    bypass: appRuleBinding(rule.id, \.bypassScrolling),
                    smoothing: appRuleBinding(rule.id, \.smoothingOverride),
                    reverseVertical: appRuleBinding(rule.id, \.reverseVerticalOverride),
                    reverseHorizontal: appRuleBinding(rule.id, \.reverseHorizontalOverride),
                    deleteAction: { deleteAppRule(rule.id) }
                )
            }

            HStack {
                if rules.isEmpty {
                    Text("Every app uses the settings above.")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                AddApplicationMenu(candidates: candidates, onOpen: refreshRunningApps) { bundleIdentifier, name in
                    addAppRule(bundleIdentifier: bundleIdentifier, name: name)
                }
            }

            if let appSelectionError {
                Text(appSelectionError).foregroundStyle(.red)
            }
        } header: {
            Text("App Exceptions")
        } footer: {
            SettingsFooter("Give one app its own scrolling, or leave it exactly as macOS scrolls it.")
        }
    }

    private var middleClickSection: some View {
        let settings = appModel.activeProfile.middleClick

        return Section {
            SettingsToggle(
                "Middle click without a middle button",
                detail: "Open links in new tabs and close tabs from a trackpad or a two-button mouse.",
                isOn: binding(\.middleClick.enabled)
            )

            Group {
                Picker("Trigger", selection: binding(\.middleClick.trigger)) {
                    ForEach(MiddleClickTrigger.runtimeSupportedCases) { trigger in
                        Text(trigger.title).tag(trigger)
                    }
                }

                Picker("Action", selection: middleClickActionBinding) {
                    Text("Middle click").tag(MiddleClickAction.middleClick)
                    Text("Close tab (⌘W)").tag(MiddleClickAction.closeTab)
                }

                if settings.trigger == .modifierClick {
                    Label("Control-click normally opens the shortcut menu. With this trigger it middle-clicks instead.", systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .symbolRenderingMode(.multicolor)
                }
            }
            .disabled(!settings.enabled)

            LabeledContent("Status") {
                SettingsStatusBadge(title: middleClickRuntimeTitle, tone: middleClickRuntimeTone)
            }
        } header: {
            Text("Middle Click")
        } footer: {
            SettingsFooter("Three-finger tap reads the trackpad through a private macOS interface, so a system update can interrupt it.")
        }
    }

    /// "Open Background Tab" was the same middle click under another name, so it is shown as one.
    private var middleClickActionBinding: Binding<MiddleClickAction> {
        Binding {
            appModel.activeProfile.middleClick.action == .closeTab ? .closeTab : .middleClick
        } set: { newValue in
            var profile = appModel.activeProfile
            profile.middleClick.action = newValue
            appModel.updateActiveProfile(profile)
        }
    }

    private var middleClickRuntimeTitle: String {
        let settings = appModel.activeProfile.middleClick
        guard settings.enabled else { return "Off" }
        guard appModel.permissions.accessibility == .granted else { return "Waiting for Accessibility" }
        guard !appModel.store.config.safeModeEnabled else { return "Paused" }

        if settings.trigger == .experimentalThreeFinger {
            return appModel.multitouchMiddleClick.lastStatus
        }

        return appModel.systemEvents.status.eventTapRunning ? "Running" : "Starting"
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
            if profile.scroll != appModel.activeProfile.scroll { profile.scroll.preset = .custom }
            appModel.updateActiveProfile(profile)
        }
    }

    private var presetBinding: Binding<SmoothingPreset> {
        Binding {
            appModel.activeProfile.scroll.preset
        } set: { preset in
            var profile = appModel.activeProfile
            profile.scroll.applyPreset(preset)
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
            // Direction is separate from feel, so it leaves the chosen preset alone.
            if keyPath == \DeviceScrollRule.smoothingEnabled { profile.scroll.preset = .custom }
            appModel.updateActiveProfile(profile)
        }
    }

    private func refreshRunningApps() {
        runningAppOptions = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .compactMap { app -> RunningAppOption? in
                guard let bundleIdentifier = app.bundleIdentifier else { return nil }
                return RunningAppOption(
                    bundleIdentifier: bundleIdentifier,
                    name: app.localizedName ?? bundleIdentifier
                )
            }
            .uniquedByBundleIdentifier()
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func addAppRule(bundleIdentifier: String, name: String) {
        var profile = appModel.activeProfile
        guard !profile.scroll.appRules.contains(where: { $0.bundleIdentifier == bundleIdentifier }) else {
            appSelectionError = "An override for \(name) already exists."
            return
        }
        appSelectionError = nil
        profile.scroll.appRules.append(AppScrollRule(
            bundleIdentifier: bundleIdentifier, appName: name,
            smoothingOverride: nil, reverseVerticalOverride: nil
        ))
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
