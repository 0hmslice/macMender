import AppKit
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var appModel: AppModel
    @State private var step: OnboardingStep = .welcome
    @State private var finishMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            HStack(spacing: 0) {
                stepRail

                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        stepContent
                    }
                    .padding(30)
                    .frame(maxWidth: 900, alignment: .leading)
                    .frame(maxWidth: .infinity)
                }
            }

            Divider()
            footer
        }
        .background {
            ZStack {
                Color(nsColor: .windowBackgroundColor).opacity(0.22)
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.08),
                        Color.accentColor.opacity(0.05),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
            .ignoresSafeArea()
        }
        .onAppear {
            appModel.permissions.refresh()
        }
    }

    private var header: some View {
        HStack(spacing: 18) {
            MendySectionImageView(section: mendySection, size: 108)

            VStack(alignment: .leading, spacing: 5) {
                Text(step.title)
                    .font(.largeTitle.bold())
                Text(step.subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(28)
    }

    private var stepRail: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(OnboardingStep.allCases) { candidate in
                Button {
                    step = candidate
                    finishMessage = nil
                    recheckPermissions()
                } label: {
                    HStack(spacing: 10) {
                        Text("\(candidate.rawValue + 1)")
                            .font(.caption.bold())
                            .foregroundStyle(candidate == step ? .white : .secondary)
                            .frame(width: 22, height: 22)
                            .background(candidate == step ? Color.accentColor : Color.secondary.opacity(0.16), in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text(candidate.shortTitle)
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(candidate.railSubtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .liquidGlass(candidate == step ? .row : .button, radius: 12)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)
        }
        .padding(18)
        .frame(width: 250)
        .background(.thinMaterial.opacity(0.35))
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
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeroCard(
                section: .overview,
                title: "Meet macMender",
                subtitle: "Make your Mac feel smoother with better gestures, Dock previews, and fast window switching."
            ) {
                HStack(spacing: 8) {
                    CapabilityBadge(title: "Runs locally", systemImage: "externaldrive", tone: .active)
                    CapabilityBadge(title: "No analytics", systemImage: "chart.bar.xaxis", tone: .active)
                    CapabilityBadge(title: "No tracking", systemImage: "eye.slash", tone: .active)
                }
            }

            PreferencesSectionGrid(minimumColumnWidth: 220) {
                OnboardingFeatureCard(title: "Three-Finger Tap", detail: "Use a trackpad tap as middle click.", symbolName: "hand.tap")
                OnboardingFeatureCard(title: "Dock Previews", detail: "Preview app windows from the Dock.", symbolName: "dock.rectangle")
                OnboardingFeatureCard(title: "Window Switcher", detail: "Move between windows faster.", symbolName: "rectangle.3.group")
            }
        }
    }

    private var inputStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeroCard(
                section: .input,
                title: "Three-Finger Tap",
                subtitle: "Tap with three fingers to act like a middle mouse button."
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    CapabilityBadge(title: middleClickSetupTitle, systemImage: middleClickSetupSymbol, tone: middleClickSetupTone)
                    Text("Open links in new tabs, close tabs, and use middle-click actions without a mouse wheel.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            PreferencesSectionGrid(minimumColumnWidth: 230) {
                OnboardingFeatureCard(title: "Links", detail: "Open links in new tabs where apps support middle click.", symbolName: "plus.rectangle.on.rectangle")
                OnboardingFeatureCard(title: "Tabs", detail: "Close tabs with familiar middle-click behavior.", symbolName: "xmark.circle")
                OnboardingFeatureCard(title: "Input Settings", detail: "Mouse, trackpad, and scroll settings stay in Input.", symbolName: "computermouse")
            }
        }
    }

    private var dockWindowsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeroCard(
                section: .dockWindows,
                title: "Dock & Windows",
                subtitle: "Preview app windows from the Dock and switch between windows faster."
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 8) {
                        CapabilityBadge(title: appModel.permissions.accessibility == .granted ? "Accessibility ready" : "Needs Accessibility", systemImage: "accessibility", tone: appModel.permissions.accessibility == .granted ? .active : .warning)
                        CapabilityBadge(title: appModel.permissions.screenRecording == .granted ? "Thumbnails ready" : "Icon fallback", systemImage: "rectangle.on.rectangle", tone: appModel.permissions.screenRecording == .granted ? .active : .warning)
                    }
                    Text("This setup step checks status only. It does not scan windows or capture thumbnails.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            PreferencesSectionGrid(minimumColumnWidth: 260) {
                OnboardingFeatureCard(title: "Dock Previews", detail: "Hover the Dock to inspect app windows before switching.", symbolName: "dock.arrow.up.rectangle")
                OnboardingFeatureCard(title: "Window Switcher", detail: "Use Option+Tab to switch between windows.", symbolName: "rectangle.3.group")
            }
        }
    }

    private var permissionsStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeroCard(
                section: .privacy,
                title: "Permissions",
                subtitle: "Turn on only the access needed for the features you use."
            ) {
                Button {
                    recheckPermissions()
                } label: {
                    Label("Recheck Permissions", systemImage: "arrow.clockwise")
                }
            }

            VStack(spacing: 12) {
                PermissionStatusRow(
                    title: "Accessibility",
                    detail: "Required for shortcuts, Dock hover previews, window actions, and middle-click actions.",
                    state: appModel.permissions.accessibility,
                    systemImage: "accessibility",
                    primaryTitle: "Request Access",
                    secondaryTitle: "Open Settings",
                    primaryAction: { appModel.permissions.requestAccessibility() },
                    secondaryAction: { appModel.permissions.openAccessibilitySettings() }
                )
                PermissionStatusRow(
                    title: "Screen Recording",
                    detail: "Used for local window thumbnails. Dock previews can fall back to icons without it.",
                    state: appModel.permissions.screenRecording,
                    systemImage: "rectangle.on.rectangle",
                    primaryTitle: "Request Access",
                    secondaryTitle: "Open Settings",
                    primaryAction: { appModel.permissions.requestScreenRecording() },
                    secondaryAction: { appModel.permissions.openScreenRecordingSettings() }
                )
                PermissionStatusRow(
                    title: "Input Monitoring",
                    detail: "macOS listen-event access. Gesture runtime status is shown separately.",
                    state: appModel.permissions.inputMonitoring,
                    systemImage: "keyboard",
                    primaryTitle: "Request Access",
                    secondaryTitle: "Open Settings",
                    primaryAction: { appModel.permissions.requestInputMonitoring() },
                    secondaryAction: { appModel.permissions.openInputMonitoringSettings() }
                ) {
                    CapabilityBadge(title: "Gesture: \(gestureRuntimeState.title)", systemImage: gestureRuntimeState.symbolName, tone: gestureRuntimeState.tone)
                }
            }

            SectionCard(
                title: "Add macMender if it is missing",
                subtitle: "If macMender is not listed, use the + button or drag the app in if macOS allows it.",
                symbolName: "hand.draw"
            ) {
                PermissionDragToAddGuide()
            }
        }
    }

    private var privacyStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeroCard(
                section: .privacy,
                title: "macMender runs locally.",
                subtitle: "No analytics. No tracking. No remote APIs by default."
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Window thumbnails stay on your Mac. Permissions are only used for the features you enable.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                    HStack(spacing: 8) {
                        CapabilityBadge(title: "Local settings", systemImage: "externaldrive", tone: .neutral)
                        CapabilityBadge(title: "Local thumbnails", systemImage: "rectangle.on.rectangle", tone: .neutral)
                    }
                }
            }

            SectionCard(title: "Local Details", subtitle: "Available later in Privacy if you want the exact paths.", symbolName: "externaldrive") {
                DisclosureGroup("Show local details") {
                    Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 8) {
                        GridRow {
                            Text("Remote APIs")
                            Text("None by default").foregroundStyle(.secondary)
                        }
                        GridRow {
                            Text("Configuration")
                            Text(appModel.store.configURL.path).foregroundStyle(.secondary).textSelection(.enabled)
                        }
                        GridRow {
                            Text("Window thumbnails")
                            Text("Used locally for Dock previews").foregroundStyle(.secondary)
                        }
                    }
                    .padding(.top, 6)
                }
            }
        }
    }

    private var finishStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            OnboardingHeroCard(
                section: .overview,
                title: finishTitle,
                subtitle: finishSubtitle
            ) {
                HStack(spacing: 8) {
                    CapabilityBadge(title: middleClickSetupTitle, systemImage: "hand.tap", tone: middleClickSetupTone)
                    CapabilityBadge(title: appModel.permissions.needsAttention ? "Permissions need review" : "Permissions ready", systemImage: "lock.shield", tone: appModel.permissions.needsAttention ? .warning : .active)
                }
            }

            PreferencesSectionGrid(minimumColumnWidth: 220) {
                OnboardingSummaryCard(title: "Three-Finger Tap", status: middleClickSetupTitle, tone: middleClickSetupTone, symbolName: "hand.tap")
                OnboardingSummaryCard(title: "Dock Previews", status: appModel.dockHover.isRunning ? "Active" : "Ready after setup", tone: appModel.permissions.accessibility == .granted ? .active : .warning, symbolName: "dock.rectangle")
                OnboardingSummaryCard(title: "Window Switcher", status: appModel.permissions.accessibility == .granted ? "Ready" : "Needs access", tone: appModel.permissions.accessibility == .granted ? .active : .warning, symbolName: "rectangle.3.group")
                OnboardingSummaryCard(title: "Input Monitoring", status: appModel.permissions.inputMonitoring.title, tone: appModel.permissions.inputMonitoring == .granted ? .active : .warning, symbolName: "keyboard")
            }

            if let finishMessage {
                Label(finishMessage, systemImage: "info.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .liquidGlass(.row)
            }
        }
    }

    private var footer: some View {
        HStack {
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
                Button(appModel.permissions.needsAttention ? "Open macMender" : "Open macMender") {
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
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.thinMaterial.opacity(0.38))
    }

    private var mendySection: SettingsSection {
        switch step {
        case .welcome, .finish:
            .overview
        case .input:
            .input
        case .dockWindows:
            .dockWindows
        case .permissions, .privacy:
            .privacy
        }
    }

    private var middleClickSetupTitle: String {
        let settings = appModel.activeProfile.middleClick
        guard settings.enabled, settings.trigger == .experimentalThreeFinger else {
            return "Off"
        }
        guard appModel.permissions.accessibility == .granted else {
            return "Needs Permission"
        }
        return "Enabled"
    }

    private var middleClickSetupSymbol: String {
        switch middleClickSetupTone {
        case .active:
            "checkmark.circle.fill"
        case .warning:
            "exclamationmark.circle"
        case .neutral:
            "pause.circle"
        }
    }

    private var middleClickSetupTone: CapabilityBadge.Tone {
        switch middleClickSetupTitle {
        case "Enabled":
            .active
        case "Needs Permission":
            .warning
        default:
            .neutral
        }
    }

    private var gestureRuntimeState: OnboardingRuntimeState {
        let settings = appModel.activeProfile.middleClick
        guard settings.enabled, settings.trigger == .experimentalThreeFinger else {
            return .off("Off")
        }
        guard appModel.permissions.accessibility == .granted else {
            return .needsPermission("Needs Permission")
        }
        if appModel.multitouchMiddleClick.isRunning {
            return .active("Active")
        }
        return .off("Off")
    }

    private var finishTitle: String {
        appModel.permissions.needsAttention ? "Ready with a few limits" : "You are ready."
    }

    private var finishSubtitle: String {
        if appModel.permissions.needsAttention {
            return "macMender can open now. Missing permissions can be reviewed later from Privacy."
        }
        return "Three-Finger Tap, Dock previews, Window Switcher, and permissions are ready."
    }

    private func recheckPermissions() {
        appModel.permissions.refresh()
    }
}

private enum OnboardingStep: Int, CaseIterable, Identifiable {
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
            "Set up trackpad middle click and input behavior."
        case .dockWindows:
            "Preview windows from the Dock and switch faster."
        case .permissions:
            "Use real macOS status for each permission."
        case .privacy:
            "Understand what stays local."
        case .finish:
            "Open the app or review anything missing."
        }
    }

    var railSubtitle: String {
        switch self {
        case .welcome: "Start here"
        case .input: "Middle click"
        case .dockWindows: "Previews"
        case .permissions: "Real status"
        case .privacy: "Local trust"
        case .finish: "Open app"
        }
    }

    var next: OnboardingStep? {
        OnboardingStep(rawValue: rawValue + 1)
    }

    var previous: OnboardingStep? {
        OnboardingStep(rawValue: rawValue - 1)
    }
}

private enum OnboardingRuntimeState {
    case active(String)
    case off(String)
    case needsPermission(String)

    var title: String {
        switch self {
        case let .active(title), let .off(title), let .needsPermission(title):
            title
        }
    }

    var symbolName: String {
        switch self {
        case .active:
            "checkmark.circle.fill"
        case .off:
            "pause.circle"
        case .needsPermission:
            "exclamationmark.circle"
        }
    }

    var tone: CapabilityBadge.Tone {
        switch self {
        case .active:
            .active
        case .off:
            .neutral
        case .needsPermission:
            .warning
        }
    }
}

private struct OnboardingHeroCard<Content: View>: View {
    var section: SettingsSection
    var title: String
    var subtitle: String
    @ViewBuilder var content: Content

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            MendySectionImageView(section: section, size: 132)

            VStack(alignment: .leading, spacing: 10) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                content
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(.card, radius: 16)
    }
}

private struct OnboardingFeatureCard: View {
    var title: String
    var detail: String
    var symbolName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: symbolName)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.tint)
                .frame(width: 34, height: 34)
                .background(.tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .liquidGlass(.card, radius: 12)
    }
}

private struct OnboardingSummaryCard: View {
    var title: String
    var status: String
    var tone: CapabilityBadge.Tone
    var symbolName: String

    var body: some View {
        SoftStatusCard(title: title, subtitle: status, systemImage: symbolName, tone: tone) {
            Label(status, systemImage: tone == .active ? "checkmark.circle.fill" : "exclamationmark.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tone == .active ? .green : .orange)
        }
    }
}

private struct PermissionStatusRow<Accessory: View>: View {
    var title: String
    var detail: String
    var state: PermissionState
    var systemImage: String
    var primaryTitle: String
    var secondaryTitle: String
    var primaryAction: () -> Void
    var secondaryAction: () -> Void
    @ViewBuilder var accessory: Accessory

    init(
        title: String,
        detail: String,
        state: PermissionState,
        systemImage: String,
        primaryTitle: String,
        secondaryTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryAction: @escaping () -> Void,
        @ViewBuilder accessory: () -> Accessory = { EmptyView() }
    ) {
        self.title = title
        self.detail = detail
        self.state = state
        self.systemImage = systemImage
        self.primaryTitle = primaryTitle
        self.secondaryTitle = secondaryTitle
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: systemImage)
                .font(.title2.weight(.semibold))
                .foregroundStyle(state == .granted ? .green : .orange)
                .frame(width: 38, height: 38)
                .background((state == .granted ? Color.green : Color.orange).opacity(0.14), in: Circle())

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.headline)
                    CapabilityBadge(title: state.title, systemImage: state == .granted ? "checkmark.circle.fill" : "exclamationmark.circle", tone: state == .granted ? .active : .warning)
                    accessory
                    Spacer(minLength: 0)
                }
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 10)

            if state == .granted {
                Button(secondaryTitle, action: secondaryAction)
                    .foregroundStyle(.secondary)
            } else {
                Button(primaryTitle, action: primaryAction)
            }
        }
        .padding(14)
        .liquidGlass(.row, radius: 12)
    }
}

private struct PermissionDragToAddGuide: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animateArrow = false

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            MendySectionImageView(section: .privacy, size: MendyAvatarSize.panel)

            DraggableAppTile()

            Image(systemName: "arrow.right")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .offset(x: reduceMotion ? 0 : (animateArrow ? 0 : -8))
                .animation(reduceMotion ? nil : .easeOut(duration: 0.55), value: animateArrow)
                .onAppear { animateArrow = true }

            PrivacyListMockup()

            VStack(alignment: .leading, spacing: 10) {
                NumberedInstruction(number: 1, title: "Open the right Privacy & Security pane from macMender.")
                NumberedInstruction(number: 2, title: "Look for macMender in the permission list.")
                NumberedInstruction(number: 3, title: "If macMender is not listed, use the + button or drag the app in if macOS allows it.")
                NumberedInstruction(number: 4, title: "Turn the toggle on, then return here and recheck.")
                Text("If macOS asks you to reopen macMender, reopen it and continue setup from this step.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .liquidGlass(.card)
    }
}

private struct DraggableAppTile: View {
    private var appURL: URL {
        Bundle.main.bundleURL
    }

    private var appIcon: NSImage {
        NSWorkspace.shared.icon(forFile: appURL.path)
    }

    var body: some View {
        VStack(spacing: 10) {
            Image(nsImage: appIcon)
                .resizable()
                .frame(width: 58, height: 58)
                .shadow(color: .black.opacity(0.18), radius: 8, y: 4)

            Text("macMender app icon")
                .font(.headline)
            Text("Drag if macOS allows it")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 180, height: 154)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(.secondary.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [6, 5]))
        }
        .onDrag {
            NSItemProvider(object: appURL as NSURL)
        }
    }
}

private struct PrivacyListMockup: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Privacy & Security")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            PrivacyMockRow(title: "Finder", enabled: true)
            PrivacyMockRow(title: "macMender", enabled: false, highlighted: true)
            PrivacyMockRow(title: "Other App", enabled: true)
            Text("Add macMender here")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.top, 2)
        }
        .padding(12)
        .frame(width: 180)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.accentColor.opacity(0.22), lineWidth: 1)
        }
    }
}

private struct PrivacyMockRow: View {
    var title: String
    var enabled: Bool
    var highlighted: Bool = false

    var body: some View {
        HStack {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(highlighted ? Color.accentColor.opacity(0.40) : .secondary.opacity(0.25))
                .frame(width: 18, height: 18)
            Text(title)
                .font(.caption)
            Spacer()
            Capsule()
                .fill(enabled ? Color.green.opacity(0.75) : .secondary.opacity(0.25))
                .frame(width: 28, height: 16)
        }
    }
}

private struct NumberedInstruction: View {
    var number: Int
    var title: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text("\(number)")
                .font(.caption.bold())
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(.blue, in: Circle())
            Text(title)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
