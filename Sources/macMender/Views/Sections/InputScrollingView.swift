import AppKit
import SwiftUI

struct InputScrollingView: View {
    @ObservedObject var appModel: AppModel
    @State private var tab = InputTab.global
    @State private var selectedRunningAppBundleID = ""

    enum InputTab: String, CaseIterable, Identifiable {
        case global = "Global"
        case devices = "Devices"
        case apps = "Apps"
        case middleClick = "Middle Click"
        var id: String { rawValue }
    }

    var body: some View {
        PreferencesScrollView {
            Picker("Input Area", selection: $tab) {
                ForEach(InputTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)

            switch tab {
            case .global:
                globalView
            case .devices:
                devicesView
            case .apps:
                appsView
            case .middleClick:
                middleClickView
            }
        }
    }

    private var globalView: some View {
        SectionCard(title: "Scroll Feel", subtitle: "Per-axis direction and smoothing. Event modification remains off while Safe Mode is enabled.", symbolName: "scroll") {
            let profile = appModel.activeProfile
            VStack(alignment: .leading, spacing: 14) {
                Picker("Preset", selection: presetBinding) {
                    ForEach(SmoothingPreset.allCases) { preset in
                        Text(preset.title).tag(preset)
                    }
                }
                .pickerStyle(.segmented)

                Grid(alignment: .leading, horizontalSpacing: 20, verticalSpacing: 10) {
                    GridRow {
                        Text("Vertical")
                        Toggle("Smooth", isOn: binding(\.scroll.verticalSmoothingEnabled))
                        Toggle("Reverse", isOn: binding(\.scroll.reverseVertical))
                    }
                    GridRow {
                        Text("Horizontal")
                        Toggle("Smooth", isOn: binding(\.scroll.horizontalSmoothingEnabled))
                        Toggle("Reverse", isOn: binding(\.scroll.reverseHorizontal))
                    }
                }

                LabeledSlider(title: "Step", value: binding(\.scroll.step), range: 0.25...6, step: 0.25, valueLabel: profile.scroll.step.sliderValueLabel)
                LabeledSlider(title: "Gain", value: binding(\.scroll.gain), range: 0.5...3, step: 0.05, valueLabel: profile.scroll.gain.sliderValueLabel)
                LabeledSlider(title: "Duration", value: binding(\.scroll.duration), range: 0...0.5, step: 0.01, valueLabel: "\(profile.scroll.duration.sliderValueLabel)s")

                ScrollPreview(settings: profile.scroll)
            }
        }
    }

    private var devicesView: some View {
        SectionCard(title: "Device Rules", subtitle: "Physical-device matching is best-effort with public APIs.", symbolName: "sensor") {
            VStack(spacing: 8) {
                ForEach(appModel.activeProfile.scroll.deviceRules) { rule in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: rule.deviceKind == .builtInTrackpad ? "rectangle.and.hand.point.up.left" : "computermouse")
                                .foregroundStyle(.secondary)
                                .frame(width: 28)
                            VStack(alignment: .leading) {
                                Text(rule.displayName)
                                Text(rule.deviceKind.title)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            CapabilityBadge(title: rule.isPhysicalDeviceSpecific ? "Device-specific" : "Device type", systemImage: "sensor", tone: .neutral)
                        }

                        Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                            GridRow {
                                Toggle("Smooth", isOn: deviceRuleBinding(rule.id, \.smoothingEnabled))
                                Toggle("Reverse Vertical", isOn: deviceRuleBinding(rule.id, \.reverseVertical))
                                Toggle("Reverse Horizontal", isOn: deviceRuleBinding(rule.id, \.reverseHorizontal))
                            }
                        }
                    }
                    .padding(10)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    private var appsView: some View {
        SectionCard(title: "Per-App Overrides", subtitle: "Overrides are matched by bundle identifier.", symbolName: "app.connected.to.app.below.fill") {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Picker("Running App", selection: selectedRunningAppBinding) {
                        ForEach(runningAppOptions) { option in
                            Text(option.name).tag(option.bundleIdentifier)
                        }
                    }
                    .frame(maxWidth: 320)

                    Button("Add Override") {
                        addSelectedRunningAppRule()
                    }
                    .disabled(selectedRunningAppBinding.wrappedValue.isEmpty || selectedRunningAppAlreadyExists)
                }

                if appModel.activeProfile.scroll.appRules.isEmpty {
                    EmptyStateView(title: "No App Overrides", message: "Apps inherit the current profile until you add a focused override.", symbolName: "square.stack.3d.up.slash")
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(appModel.activeProfile.scroll.appRules) { rule in
                            AppOverrideRow(
                                rule: rule,
                                smoothing: appRuleBinding(rule.id, \.smoothingOverride),
                                reverseVertical: appRuleBinding(rule.id, \.reverseVerticalOverride),
                                reverseHorizontal: appRuleBinding(rule.id, \.reverseHorizontalOverride),
                                deleteAction: { deleteAppRule(rule.id) }
                            )
                        }
                    }
                }
            }
        }
    }

    private var middleClickView: some View {
        SectionCard(title: "Middle Click", subtitle: "macMender can post middle clicks from mouse triggers or local three-finger tap detection.", symbolName: "hand.tap") {
            VStack(alignment: .leading, spacing: 14) {
                Toggle("Enable Middle Click", isOn: binding(\.middleClick.enabled))
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
                    CapabilityBadge(title: "Requires Accessibility", systemImage: "lock.shield", tone: appModel.permissions.accessibility == .granted ? .active : .warning)
                    CapabilityBadge(
                        title: middleClickRuntimeTitle,
                        systemImage: middleClickRuntimeSymbol,
                        tone: middleClickRuntimeTone
                    )
                }
            }
        }
    }

    private var middleClickRuntimeTitle: String {
        let settings = appModel.activeProfile.middleClick
        guard settings.enabled else { return "Disabled" }
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
        return appModel.systemEvents.status.eventTapRunning ? "checkmark.circle.fill" : "circle.dashed"
    }

    private var middleClickRuntimeTone: CapabilityBadge.Tone {
        let settings = appModel.activeProfile.middleClick
        guard settings.enabled,
              appModel.permissions.accessibility == .granted,
              !appModel.store.config.safeModeEnabled else {
            return .neutral
        }
        if settings.trigger == .experimentalThreeFinger {
            return appModel.multitouchMiddleClick.isRunning ? .active : .warning
        }
        return appModel.systemEvents.status.eventTapRunning ? .active : .warning
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

    private func deviceRuleBinding<Value>(_ ruleID: UUID, _ keyPath: WritableKeyPath<DeviceScrollRule, Value>) -> Binding<Value> {
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

    private var runningAppOptions: [RunningAppOption] {
        NSWorkspace.shared.runningApplications
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
    }

    private var selectedRunningAppBinding: Binding<String> {
        Binding {
            let options = runningAppOptions
            if selectedRunningAppBundleID.isEmpty || !options.contains(where: { $0.bundleIdentifier == selectedRunningAppBundleID }) {
                return options.first?.bundleIdentifier ?? ""
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

    private func appRuleBinding<Value>(_ ruleID: UUID, _ keyPath: WritableKeyPath<AppScrollRule, Value>) -> Binding<Value> {
        Binding {
            guard let rule = appModel.activeProfile.scroll.appRules.first(where: { $0.id == ruleID }) else {
                return AppScrollRule(bundleIdentifier: "", appName: "", smoothingOverride: nil, reverseVerticalOverride: nil)[keyPath: keyPath]
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

private struct RunningAppOption: Identifiable {
    var id: String { bundleIdentifier }
    var bundleIdentifier: String
    var name: String
}

private extension Array where Element == RunningAppOption {
    func uniquedByBundleIdentifier() -> [RunningAppOption] {
        var seen = Set<String>()
        return filter { option in
            guard !seen.contains(option.bundleIdentifier) else { return false }
            seen.insert(option.bundleIdentifier)
            return true
        }
    }
}

private struct AppOverrideRow: View {
    var rule: AppScrollRule
    var smoothing: Binding<Bool?>
    var reverseVertical: Binding<Bool?>
    var reverseHorizontal: Binding<Bool?>
    var deleteAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 2) {
                    Text(rule.appName)
                        .font(.headline)
                    Text(rule.bundleIdentifier)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }

                Spacer()

                Button("Remove", role: .destructive, action: deleteAction)
            }

            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 8) {
                GridRow {
                    TriStateOverridePicker(title: "Smoothing", value: smoothing)
                    TriStateOverridePicker(title: "Reverse Vertical", value: reverseVertical)
                    TriStateOverridePicker(title: "Reverse Horizontal", value: reverseHorizontal)
                }
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var icon: NSImage {
        if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rule.bundleIdentifier) {
            return NSWorkspace.shared.icon(forFile: appURL.path)
        }
        return NSImage(systemSymbolName: "app", accessibilityDescription: nil) ?? NSImage()
    }
}

private struct TriStateOverridePicker: View {
    var title: String
    var value: Binding<Bool?>

    var body: some View {
        Picker(title, selection: Binding(
            get: { OverrideValue(value.wrappedValue) },
            set: { value.wrappedValue = $0.boolValue }
        )) {
            ForEach(OverrideValue.allCases) { option in
                Text(option.title).tag(option)
            }
        }
        .pickerStyle(.menu)
        .frame(minWidth: 150)
    }
}

private enum OverrideValue: String, CaseIterable, Identifiable {
    case inherit
    case on
    case off

    init(_ value: Bool?) {
        switch value {
        case true: self = .on
        case false: self = .off
        case nil: self = .inherit
        }
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .inherit: "Inherit"
        case .on: "On"
        case .off: "Off"
        }
    }

    var boolValue: Bool? {
        switch self {
        case .inherit: nil
        case .on: true
        case .off: false
        }
    }
}

private struct ScrollPreview: View {
    var settings: ScrollSettings

    private var samples: [ScrollSample] {
        ScrollTransformer(settings: settings).projectedSamples(from: ScrollSample(x: 0, y: 120), count: 10)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Curve Preview")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .bottom, spacing: 4) {
                ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(.blue.opacity(0.65))
                        .frame(width: 14, height: max(4, min(80, abs(sample.y))))
                }
            }
            .frame(height: 90, alignment: .bottom)
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }
}
