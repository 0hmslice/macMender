import SwiftUI

/// First-run setup: what macMender does, which features to turn on, and the permissions they need.
struct OnboardingView: View {
    @ObservedObject var appModel: AppModel
    @State private var step = OnboardingStep.initial

    private static let maximumContentWidth: CGFloat = 640

    var body: some View {
        VStack(spacing: 0) {
            GeometryReader { proxy in
                Form {
                    Section {
                        header
                    }
                    stepContent
                }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .contentMargins(.horizontal, max(0, (proxy.size.width - Self.maximumContentWidth) / 2), for: .scrollContent)
            }

            Divider()
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear { appModel.permissions.refresh() }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 18) {
            Image(nsImage: MacMenderBrandAssets.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .frame(width: 76, height: 76)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.title.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)
                Text(step.subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome: welcomeStep
        case .features: featuresStep
        case .permissions: permissionsStep
        case .finish: finishStep
        }
    }

    // MARK: Steps

    @ViewBuilder
    private var welcomeStep: some View {
        Section {
            SettingsRow(
                title: "Dock Previews",
                detail: "Rest the pointer on a Dock icon to see that app's windows, then switch, close, or arrange them.",
                systemImage: SettingsSection.dockPreviews.symbolName,
                tint: SettingsSection.dockPreviews.tint
            ) { EmptyView() }
            SettingsRow(
                title: "Window Switcher",
                detail: "Press ⌥ Tab to move between individual windows, not just apps.",
                systemImage: SettingsSection.windowSwitcher.symbolName,
                tint: SettingsSection.windowSwitcher.tint
            ) { EmptyView() }
            SettingsRow(
                title: "Mouse & Trackpad",
                detail: "Smooth the mouse wheel, set scroll direction for each device, and middle-click with a three-finger tap.",
                systemImage: SettingsSection.input.symbolName,
                tint: SettingsSection.input.tint
            ) { EmptyView() }
            SettingsRow(
                title: "Keep Awake",
                detail: "Stop your Mac sleeping while something long finishes.",
                systemImage: SettingsSection.keepAwake.symbolName,
                tint: SettingsSection.keepAwake.tint
            ) { EmptyView() }
        } header: {
            Text("What You Get")
        } footer: {
            SettingsFooter("Free and local. No account, no analytics, and nothing leaves this Mac.")
        }
    }

    @ViewBuilder
    private var featuresStep: some View {
        Section {
            SettingsToggle(
                "Dock Previews",
                detail: "Show an app's windows when you hover its Dock icon.",
                isOn: appModel.profileBinding(\.dockPreviews.enabled)
            )
            SettingsToggle(
                "Window Switcher",
                detail: "Switch between windows with ⌥ Tab.",
                isOn: appModel.profileBinding(\.windowSwitcher.enabled)
            )
            SettingsToggle(
                "Three-finger tap to middle-click",
                detail: "Open links in new tabs and close tabs from the trackpad.",
                isOn: Binding(
                    get: { appModel.activeProfile.isThreeFingerTapEnabled },
                    set: { appModel.setThreeFingerTapEnabled($0) }
                )
            )
            SettingsToggle(
                "Smooth mouse wheel scrolling",
                detail: "Gives a wheel mouse the glide of a trackpad. Trackpads are left alone.",
                isOn: smoothScrollingBinding
            )
        } header: {
            Text("Turn On What You Want")
        } footer: {
            SettingsFooter("Each one has its own page of settings afterwards, and you can change your mind at any time.")
        }
    }

    @ViewBuilder
    private var permissionsStep: some View {
        Section {
            PermissionSettingsRow(
                title: "Accessibility",
                detail: "Required. Lets macMender see Dock icons, switch and arrange windows, and respond to shortcuts and scrolling.",
                systemImage: "accessibility",
                tint: .blue,
                state: appModel.permissions.accessibility,
                request: appModel.permissions.requestAccessibility,
                openSettings: appModel.permissions.openAccessibilitySettings
            )
            PermissionSettingsRow(
                title: "Screen Recording",
                detail: "Optional. Shows each window's contents in previews and the switcher. Without it you see app icons.",
                systemImage: "rectangle.on.rectangle",
                tint: .purple,
                state: appModel.permissions.screenRecording,
                request: appModel.permissions.requestScreenRecording,
                openSettings: appModel.permissions.openScreenRecordingSettings
            )
        } header: {
            Text("macOS Permissions")
        } footer: {
            HStack {
                Text("macOS asks you to approve each one in System Settings. It may ask you to quit and reopen macMender afterwards.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Check Again") { appModel.permissions.refresh() }
                    .controlSize(.small)
            }
        }

        Section {
            DisclosureGroup("macMender is not in the list in System Settings") {
                PermissionDragToAddGuide()
                    .padding(.vertical, 6)
            }
        }
    }

    @ViewBuilder
    private var finishStep: some View {
        if appModel.permissions.needsAttention {
            Section {
                SettingsRow(
                    title: "Accessibility is not allowed yet",
                    detail: "Previews, window switching, and shortcuts stay off until it is. You can also do this later in Privacy.",
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .orange
                ) {
                    Button("Go Back") { step = .permissions }
                }
            }
        }

        Section("Try These First") {
            if appModel.activeProfile.dockPreviews.enabled {
                tip("Rest the pointer on a Dock icon", "A preview of that app's windows appears above it.", .dockPreviews)
            }
            if appModel.activeProfile.windowSwitcher.enabled {
                tip("Hold ⌥ and press Tab", "Keep pressing Tab to move through windows; release ⌥ to switch.", .windowSwitcher)
            }
            if appModel.activeProfile.isThreeFingerTapEnabled {
                tip("Tap a link with three fingers", "It opens in a new tab, just like a middle click.", .input)
            }
            tip("Look in the menu bar", "macMender's icon has quick switches and opens this window.", .overview)
        }

        Section {
            SettingsToggle(
                "Open macMender at login",
                detail: "So it is ready whenever you use your Mac.",
                isOn: Binding(
                    get: { appModel.loginItems.launchAtLogin },
                    set: { appModel.loginItems.setLaunchAtLogin($0) }
                )
            )
            .disabled(!appModel.loginItems.canManageLaunchAtLogin)
        }
    }

    private func tip(_ title: String, _ detail: String, _ section: SettingsSection) -> some View {
        SettingsRow(title: title, detail: detail, systemImage: section.symbolName, tint: section.tint) { EmptyView() }
    }

    private var smoothScrollingBinding: Binding<Bool> {
        Binding {
            let scroll = appModel.activeProfile.scroll
            return scroll.verticalSmoothingEnabled || scroll.horizontalSmoothingEnabled
        } set: { isOn in
            var profile = appModel.activeProfile
            profile.scroll.applyPreset(isOn ? .balanced : .off)
            appModel.updateActiveProfile(profile)
        }
    }

    // MARK: Footer

    private var footer: some View {
        HStack(spacing: 12) {
            if step != .finish {
                Button("Skip Setup") { appModel.completeOnboarding() }
                    .buttonStyle(.borderless)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 6) {
                ForEach(OnboardingStep.allCases) { candidate in
                    Circle()
                        .fill(candidate == step ? Color.accentColor : Color.secondary.opacity(0.3))
                        .frame(width: 7, height: 7)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Step \(step.rawValue + 1) of \(OnboardingStep.allCases.count)")

            Spacer()

            if let previous = step.previous {
                Button("Back") { step = previous }
            }
            if let next = step.next {
                Button(step == .welcome ? "Get Started" : "Continue") {
                    appModel.permissions.refresh()
                    step = next
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            } else {
                Button("Start Using macMender") { appModel.completeOnboarding() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .controlSize(.large)
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
    }
}

enum OnboardingStep: Int, CaseIterable, Identifiable {
    case welcome
    case features
    case permissions
    case finish

    var id: Int { rawValue }

    static var initial: OnboardingStep {
        #if DEBUG
        // Development aid: open at a given step when taking screenshots.
        if let raw = ProcessInfo.processInfo.environment["MACMENDER_ONBOARDING_STEP"].flatMap(Int.init),
           let step = OnboardingStep(rawValue: raw) {
            return step
        }
        #endif
        return .welcome
    }

    var title: String {
        switch self {
        case .welcome: "Welcome to macMender"
        case .features: "Choose Your Features"
        case .permissions: "Allow Access"
        case .finish: "You're All Set"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome: "Small improvements that make a Mac feel like yours. Setup takes about a minute."
        case .features: "Everything is optional. Start with what sounds useful."
        case .permissions: "macMender needs your permission before it can see windows or respond to shortcuts."
        case .finish: "macMender is running. It lives in the menu bar."
        }
    }

    var next: OnboardingStep? { OnboardingStep(rawValue: rawValue + 1) }
    var previous: OnboardingStep? { OnboardingStep(rawValue: rawValue - 1) }
}
