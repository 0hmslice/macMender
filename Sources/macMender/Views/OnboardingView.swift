import AppKit
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var appModel: AppModel
    @State private var step: OnboardingStep = .welcome
    @State private var finishMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                OnboardingStepRail(selection: stepSelection)

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: MacMenderSpacing.section) {
                        MacMenderPageHeader(
                            title: step.title,
                            subtitle: step.subtitle,
                            systemImage: step.systemImage
                        )

                        stepContent
                    }
                    .padding(MacMenderSpacing.page)
                    .frame(maxWidth: 900, alignment: .topLeading)
                    .frame(maxWidth: .infinity, alignment: .top)
                }
                .scrollContentBackground(.hidden)
            }

            Divider()
            footer
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .onAppear {
            appModel.permissions.refresh()
        }
    }

    private var stepSelection: Binding<OnboardingStep?> {
        Binding(
            get: { step },
            set: { candidate in
                guard let candidate else { return }
                step = candidate
                finishMessage = nil
                recheckPermissions()
            }
        )
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .welcome:
            welcomeStep
        case .input:
            inputStep
        case .dockWindows:
            dockWindowsStep
        case .permissions:
            permissionsStep
        case .privacy:
            privacyStep
        case .finish:
            finishStep
        }
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: MacMenderSpacing.section) {
            OnboardingMendyMoment(
                mood: .greeting,
                title: "Meet macMender",
                subtitle: "A focused set of Mac utilities for gestures, Dock previews, and fast window switching."
            ) {
                OnboardingStatusGroup(items: [
                    OnboardingStatusItem(title: "Runs locally", tone: .active, systemImage: "externaldrive"),
                    OnboardingStatusItem(title: "No analytics", tone: .active, systemImage: "chart.bar.xaxis"),
                    OnboardingStatusItem(title: "No tracking", tone: .active, systemImage: "eye.slash")
                ])
            }

            MacMenderContentSection(
                title: "What macMender improves",
                subtitle: "Each feature stays independently configurable after setup.",
                systemImage: "wrench.and.screwdriver"
            ) {
                LazyVGrid(columns: onboardingFeatureColumns, alignment: .leading, spacing: MacMenderSpacing.section) {
                    OnboardingFeatureItem(
                        title: "Three-Finger Tap",
                        detail: "Use a trackpad tap as a middle click.",
                        systemImage: "hand.tap"
                    )
                    OnboardingFeatureItem(
                        title: "Dock Previews",
                        detail: "Preview an app's real windows from the Dock.",
                        systemImage: "dock.rectangle"
                    )
                    OnboardingFeatureItem(
                        title: "Window Switcher",
                        detail: "Move directly between open windows with Option+Tab.",
                        systemImage: "rectangle.3.group"
                    )
                }
            }

            MacMenderCallout(systemImage: "lock.shield", tone: .neutral) {
                Text("Settings, diagnostics, and window thumbnails remain on this Mac.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var inputStep: some View {
        VStack(alignment: .leading, spacing: MacMenderSpacing.section) {
            MacMenderContentSection(
                title: "Three-Finger Tap",
                subtitle: "Tap with three fingers to perform a standard middle-click action.",
                systemImage: "hand.tap"
            ) {
                VStack(alignment: .leading, spacing: MacMenderSpacing.section) {
                    OnboardingFlowDiagram(items: [
                        OnboardingDiagramItem(title: "Three-finger tap", systemImage: "hand.tap"),
                        OnboardingDiagramItem(title: "Middle click", systemImage: "computermouse"),
                        OnboardingDiagramItem(title: "App action", systemImage: "plus.rectangle.on.rectangle")
                    ])

                    Divider()

                    MacMenderSettingsRow(
                        title: "Current status",
                        detail: threeFingerTapSummary.detail
                    ) {
                        MacMenderStatusLabel(
                            title: threeFingerTapSummary.title,
                            tone: MacMenderStatusTone(featureStatusKind: threeFingerTapSummary.kind),
                            systemImage: "hand.tap"
                        )
                    }
                }
            }

            MacMenderContentSection(
                title: "Familiar middle-click behavior",
                subtitle: "Apps decide which middle-click actions they support.",
                systemImage: "computermouse"
            ) {
                LazyVGrid(columns: onboardingFeatureColumns, alignment: .leading, spacing: MacMenderSpacing.section) {
                    OnboardingFeatureItem(
                        title: "Open links",
                        detail: "Open links in new tabs where an app supports middle click.",
                        systemImage: "plus.rectangle.on.rectangle"
                    )
                    OnboardingFeatureItem(
                        title: "Close tabs",
                        detail: "Use familiar middle-click behavior in supported tab bars.",
                        systemImage: "xmark.circle"
                    )
                    OnboardingFeatureItem(
                        title: "Tune later",
                        detail: "Mouse, trackpad, and scroll controls remain available in Input.",
                        systemImage: "slider.horizontal.3"
                    )
                }
            }
        }
    }

    private var dockWindowsStep: some View {
        VStack(alignment: .leading, spacing: MacMenderSpacing.section) {
            MacMenderContentSection(
                title: "Dock previews and Window Switcher",
                subtitle: "See the right window before you activate it.",
                systemImage: "dock.arrow.up.rectangle"
            ) {
                VStack(alignment: .leading, spacing: MacMenderSpacing.section) {
                    OnboardingFlowDiagram(items: [
                        OnboardingDiagramItem(title: "Dock item", systemImage: "dock.rectangle"),
                        OnboardingDiagramItem(title: "Window preview", systemImage: "rectangle.on.rectangle"),
                        OnboardingDiagramItem(title: "Activate", systemImage: "rectangle.3.group")
                    ])

                    Divider()

                    VStack(spacing: MacMenderSpacing.standard) {
                        OnboardingSummaryRow(
                            title: "Dock Previews",
                            detail: dockPreviewSummary.detail,
                            status: dockPreviewSummary.title,
                            tone: MacMenderStatusTone(featureStatusKind: dockPreviewSummary.kind),
                            systemImage: "dock.rectangle"
                        )

                        Divider()

                        OnboardingSummaryRow(
                            title: "Window Switcher",
                            detail: windowSwitcherSummary.detail,
                            status: windowSwitcherSummary.title,
                            tone: MacMenderStatusTone(featureStatusKind: windowSwitcherSummary.kind),
                            systemImage: "rectangle.3.group"
                        )

                        Divider()

                        let screenRecording = PermissionStatusPolicy.screenRecordingSummary(appModel.permissions.screenRecording)
                        OnboardingSummaryRow(
                            title: "Window Thumbnails",
                            detail: screenRecording.detail,
                            status: screenRecording.title,
                            tone: MacMenderStatusTone(featureStatusKind: screenRecording.kind),
                            systemImage: "rectangle.on.rectangle"
                        )
                    }
                }
            }

            MacMenderCallout(systemImage: "info.circle", tone: .neutral) {
                Text("This setup step checks status only. It does not scan windows or capture thumbnails.")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: MacMenderSpacing.section) {
            MacMenderContentSection(
                title: "Permission status",
                subtitle: "Turn on only the access needed for the features you use.",
                systemImage: "lock.shield"
            ) {
                VStack(spacing: 0) {
                    MacMenderSettingsRow(
                        title: "Overall permissions",
                        detail: permissionsSummary.detail
                    ) {
                        MacMenderStatusLabel(
                            title: permissionsSummary.title,
                            tone: MacMenderStatusTone(featureStatusKind: permissionsSummary.kind),
                            systemImage: "lock.shield"
                        )
                    }
                    .padding(.bottom, MacMenderSpacing.standard)

                    Divider()

                    HStack {
                        Text("macOS reports the current status for each permission.")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        Spacer(minLength: MacMenderSpacing.standard)

                        Button {
                            recheckPermissions()
                        } label: {
                            Label("Recheck Permissions", systemImage: "arrow.clockwise")
                        }
                    }
                    .padding(.vertical, MacMenderSpacing.standard)

                    Divider()

                    OnboardingPermissionRow(
                        title: "Accessibility",
                        detail: "Required for shortcuts, Dock hover previews, window actions, and middle-click actions.",
                        state: appModel.permissions.accessibility,
                        systemImage: "accessibility",
                        primaryTitle: "Request Access",
                        secondaryTitle: "Open Settings",
                        primaryAction: { appModel.permissions.requestAccessibility() },
                        secondaryAction: { appModel.permissions.openAccessibilitySettings() }
                    )

                    Divider()

                    OnboardingPermissionRow(
                        title: "Screen Recording",
                        detail: "Optional for local window thumbnails. Dock previews can fall back to icons without it.",
                        state: appModel.permissions.screenRecording,
                        summary: PermissionStatusPolicy.screenRecordingSummary(appModel.permissions.screenRecording),
                        systemImage: "rectangle.on.rectangle",
                        primaryTitle: "Request Access",
                        secondaryTitle: "Open Settings",
                        primaryAction: { appModel.permissions.requestScreenRecording() },
                        secondaryAction: { appModel.permissions.openScreenRecordingSettings() }
                    )

                    Divider()

                    OnboardingPermissionRow(
                        title: "Input Monitoring",
                        detail: "Optional macOS listen-event access. Gesture runtime status is shown separately.",
                        state: appModel.permissions.inputMonitoring,
                        summary: PermissionStatusPolicy.inputMonitoringSummary(appModel.permissions.inputMonitoring),
                        systemImage: "keyboard",
                        primaryTitle: "Request Access",
                        secondaryTitle: "Open Settings",
                        primaryAction: { appModel.permissions.requestInputMonitoring() },
                        secondaryAction: { appModel.permissions.openInputMonitoringSettings() }
                    ) {
                        MacMenderStatusLabel(
                            title: "Gesture: \(threeFingerTapSummary.title)",
                            tone: MacMenderStatusTone(featureStatusKind: threeFingerTapSummary.kind),
                            systemImage: "hand.tap"
                        )
                    }
                }
            }

            MacMenderContentSection(
                title: "Add macMender if it is missing",
                subtitle: "Use the + button or drag the app in if macOS allows it.",
                systemImage: "hand.draw"
            ) {
                PermissionDragToAddGuide()
            }
        }
    }

    private var privacyStep: some View {
        VStack(alignment: .leading, spacing: MacMenderSpacing.section) {
            MacMenderCallout(systemImage: "checkmark.shield", tone: .active) {
                VStack(alignment: .leading, spacing: MacMenderSpacing.compact) {
                    Text("macMender runs locally.")
                        .fontWeight(.semibold)
                    Text("No analytics, tracking, or remote APIs are used by default.")
                        .foregroundStyle(.secondary)
                }
            }

            MacMenderContentSection(
                title: "Local by design",
                subtitle: "Permissions are used only for the features you enable.",
                systemImage: "externaldrive"
            ) {
                LazyVGrid(columns: onboardingFeatureColumns, alignment: .leading, spacing: MacMenderSpacing.section) {
                    OnboardingFeatureItem(
                        title: "Local settings",
                        detail: "Profiles and preferences are stored on this Mac.",
                        systemImage: "externaldrive"
                    )
                    OnboardingFeatureItem(
                        title: "Local thumbnails",
                        detail: "Window images are used locally for previews.",
                        systemImage: "rectangle.on.rectangle"
                    )
                    OnboardingFeatureItem(
                        title: "Permission control",
                        detail: "macOS remains in control of every permission.",
                        systemImage: "lock.shield"
                    )
                }
            }

            MacMenderContentSection(
                title: "Local details",
                subtitle: "These details remain available later from Privacy.",
                systemImage: "info.circle"
            ) {
                DisclosureGroup("Show local details") {
                    Grid(alignment: .leading, horizontalSpacing: MacMenderSpacing.section, verticalSpacing: MacMenderSpacing.small) {
                        GridRow {
                            Text("Remote APIs")
                            Text("None by default").foregroundStyle(.secondary)
                        }
                        GridRow {
                            Text("Configuration")
                            Text(appModel.store.configURL.path)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                        }
                        GridRow {
                            Text("Window thumbnails")
                            Text("Used locally for Dock previews").foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, MacMenderSpacing.small)
                }
            }
        }
    }

    private var finishStep: some View {
        VStack(alignment: .leading, spacing: MacMenderSpacing.section) {
            OnboardingMendyMoment(
                mood: permissionsSummary.kind == .needsAttention ? .error : .success,
                title: finishTitle,
                subtitle: finishSubtitle
            ) {
                OnboardingStatusGroup(items: [
                    OnboardingStatusItem(
                        title: "Three-Finger Tap: \(threeFingerTapSummary.title)",
                        tone: MacMenderStatusTone(featureStatusKind: threeFingerTapSummary.kind),
                        systemImage: "hand.tap"
                    ),
                    OnboardingStatusItem(
                        title: "Permissions: \(permissionsSummary.title)",
                        tone: MacMenderStatusTone(featureStatusKind: permissionsSummary.kind),
                        systemImage: "lock.shield"
                    )
                ])
            }

            MacMenderContentSection(
                title: "Setup summary",
                subtitle: "You can change these settings at any time.",
                systemImage: "checkmark.circle"
            ) {
                VStack(spacing: MacMenderSpacing.standard) {
                    OnboardingSummaryRow(
                        title: "Three-Finger Tap",
                        detail: threeFingerTapSummary.detail,
                        status: threeFingerTapSummary.title,
                        tone: MacMenderStatusTone(featureStatusKind: threeFingerTapSummary.kind),
                        systemImage: "hand.tap"
                    )
                    Divider()
                    OnboardingSummaryRow(
                        title: "Dock Previews",
                        detail: dockPreviewSummary.detail,
                        status: dockPreviewSummary.title,
                        tone: MacMenderStatusTone(featureStatusKind: dockPreviewSummary.kind),
                        systemImage: "dock.rectangle"
                    )
                    Divider()
                    OnboardingSummaryRow(
                        title: "Window Switcher",
                        detail: windowSwitcherSummary.detail,
                        status: windowSwitcherSummary.title,
                        tone: MacMenderStatusTone(featureStatusKind: windowSwitcherSummary.kind),
                        systemImage: "rectangle.3.group"
                    )
                    Divider()
                    OnboardingSummaryRow(
                        title: "Permissions",
                        detail: permissionsSummary.detail,
                        status: permissionsSummary.title,
                        tone: MacMenderStatusTone(featureStatusKind: permissionsSummary.kind),
                        systemImage: "lock.shield"
                    )
                }
            }

            if let finishMessage {
                MacMenderCallout(systemImage: "info.circle", tone: .neutral) {
                    Text(finishMessage)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var footer: some View {
        HStack(spacing: MacMenderSpacing.standard) {
            Button("Skip for Now") {
                finishMessage = nil
                appModel.completeOnboarding()
            }
            .foregroundStyle(.secondary)

            Spacer()

            if step != .welcome {
                Button("Back") {
                    step = step.previous ?? .welcome
                    finishMessage = nil
                }
            }

            if step == .finish {
                if appModel.permissions.needsAttention {
                    Button("Review Permissions") {
                        step = .permissions
                        finishMessage = nil
                    }
                }

                Button("Open macMender") {
                    finishMessage = appModel.permissions.needsAttention ? "You can finish permission setup later from Privacy." : nil
                    appModel.completeOnboarding()
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(step == .welcome ? "Get Started" : "Continue") {
                    if step == .permissions {
                        recheckPermissions()
                    }
                    step = step.next ?? .finish
                    finishMessage = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .controlSize(.large)
        .padding(.horizontal, MacMenderSpacing.page)
        .padding(.vertical, MacMenderSpacing.standard)
        .background(.bar)
    }

    private var onboardingFeatureColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 210), alignment: .topLeading)]
    }

    private var permissionsSummary: FeatureStatusSummary {
        PermissionStatusPolicy.permissionsSummary(
            accessibility: appModel.permissions.accessibility,
            screenRecording: appModel.permissions.screenRecording,
            inputMonitoring: appModel.permissions.inputMonitoring
        )
    }

    private var threeFingerTapSummary: FeatureStatusSummary {
        PermissionStatusPolicy.threeFingerTapStatus(
            settings: appModel.activeProfile.middleClick,
            accessibility: appModel.permissions.accessibility,
            safeModeEnabled: appModel.store.config.safeModeEnabled,
            runtimeRunning: appModel.multitouchMiddleClick.isRunning
        )
    }

    private var dockPreviewSummary: FeatureStatusSummary {
        PermissionStatusPolicy.dockPreviewStatus(
            settings: appModel.activeProfile.dockPreviews,
            accessibility: appModel.permissions.accessibility,
            safeModeEnabled: appModel.store.config.safeModeEnabled,
            runtimeRunning: appModel.dockHover.isRunning
        )
    }

    private var windowSwitcherSummary: FeatureStatusSummary {
        PermissionStatusPolicy.windowSwitcherStatus(
            settings: appModel.activeProfile.windowSwitcher,
            featureEnabled: appModel.store.config.featureToggles.windowSwitcher,
            accessibility: appModel.permissions.accessibility,
            safeModeEnabled: appModel.store.config.safeModeEnabled
        )
    }

    private var finishTitle: String {
        permissionsSummary.kind == .needsAttention ? "Setup needs one review" : "Setup is complete."
    }

    private var finishSubtitle: String {
        permissionsSummary.detail
    }

    private func recheckPermissions() {
        appModel.permissions.refresh()
    }
}

enum OnboardingStep: Int, CaseIterable, Identifiable, Hashable {
    case welcome
    case input
    case dockWindows
    case permissions
    case privacy
    case finish

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .welcome: "Welcome"
        case .input: "Input and Three-Finger Tap"
        case .dockWindows: "Dock and Windows"
        case .permissions: "Permissions"
        case .privacy: "Local Privacy"
        case .finish: "Finish"
        }
    }

    var shortTitle: String {
        switch self {
        case .welcome: "Welcome"
        case .input: "Input"
        case .dockWindows: "Dock & Windows"
        case .permissions: "Permissions"
        case .privacy: "Privacy"
        case .finish: "Finish"
        }
    }

    var subtitle: String {
        switch self {
        case .welcome:
            "A guided setup for gestures, Dock previews, and fast window switching."
        case .input:
            "Set up trackpad middle click and understand its behavior."
        case .dockWindows:
            "Preview windows from the Dock and switch faster."
        case .permissions:
            "Review the real macOS status for each permission."
        case .privacy:
            "See what macMender keeps local."
        case .finish:
            "Open the app or review anything missing."
        }
    }

    var railSubtitle: String {
        switch self {
        case .welcome: "Start here"
        case .input: "Middle click"
        case .dockWindows: "Previews"
        case .permissions: "System access"
        case .privacy: "Local trust"
        case .finish: "Open app"
        }
    }

    var systemImage: String {
        switch self {
        case .welcome: "sparkles"
        case .input: "hand.tap"
        case .dockWindows: "dock.rectangle"
        case .permissions: "lock.shield"
        case .privacy: "hand.raised"
        case .finish: "checkmark.circle"
        }
    }

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }
}
