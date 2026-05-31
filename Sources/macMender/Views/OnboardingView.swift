import AppKit
import SwiftUI

struct OnboardingView: View {
    @ObservedObject var appModel: AppModel
    @State private var finishMessage: String?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    OnboardingMendyIntro()

                    SectionCard(
                        title: "Enable macMender",
                        subtitle: "Grant the access macMender needs to tune input, middle-click, window previews, and window actions. Nothing leaves this Mac.",
                        symbolName: "wrench.and.screwdriver"
                    ) {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), alignment: .leading, spacing: 14) {
                            PermissionSetupCard(
                                title: "Accessibility",
                                detail: "Required for scroll tuning, middle-click actions, global shortcuts, and window actions.",
                                status: appModel.permissions.accessibility,
                                systemImage: "accessibility",
                                primaryTitle: "Open Accessibility",
                                primaryAction: {
                                    appModel.permissions.openAccessibilitySettings()
                                }
                            )

                            PermissionSetupCard(
                                title: "Screen Recording",
                                detail: "Optional. Enables live window thumbnails. The app still works without it.",
                                status: appModel.permissions.screenRecording,
                                systemImage: "rectangle.on.rectangle",
                                primaryTitle: "Open Screen Recording",
                                primaryAction: {
                                    appModel.permissions.openScreenRecordingSettings()
                                }
                            )

                            PermissionGuidanceCard(
                                title: "Input Monitoring",
                                detail: "macOS may ask for this when observing global input. Open this pane if macOS prompts or Option+Tab does not respond.",
                                systemImage: "keyboard",
                                primaryTitle: "Open Input Monitoring",
                                primaryAction: {
                                    appModel.permissions.openInputMonitoringSettings()
                                }
                            )
                        }
                    }

                    SectionCard(
                        title: "Add macMender if it is missing",
                        subtitle: "System Settings sometimes needs you to add the app before the toggle appears.",
                        symbolName: "hand.draw"
                    ) {
                        PermissionDragToAddGuide()
                    }

                    SectionCard(
                        title: "Finish",
                        subtitle: finishSubtitle,
                        symbolName: appModel.permissions.accessibility == .granted ? "checkmark.circle" : "lock"
                    ) {
                        HStack(spacing: 14) {
                            MendyAvatarView(
                                mood: appModel.permissions.accessibility == .granted ? .success : .greeting,
                                size: MendyAvatarSize.panel
                            )

                            VStack(alignment: .leading, spacing: 6) {
                                CapabilityBadge(
                                    title: appModel.permissions.accessibility == .granted ? "Ready" : "Waiting for Accessibility",
                                    systemImage: appModel.permissions.accessibility == .granted ? "checkmark.circle.fill" : "exclamationmark.circle",
                                    tone: appModel.permissions.accessibility == .granted ? .active : .warning
                                )

                                Text(appModel.permissions.accessibility == .granted ? "Mendy is ready to start quietly fixing workflow annoyances." : "Mendy will start after Accessibility is enabled.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()

                            Button("Refresh") {
                                finishMessage = nil
                                appModel.refreshSystemState(force: true)
                            }

                            Button("Start Using macMender") {
                                startUsingMacMender()
                            }
                            .buttonStyle(.borderedProminent)
                        }

                        if let finishMessage {
                            Label(finishMessage, systemImage: "exclamationmark.triangle.fill")
                                .font(.callout)
                                .foregroundStyle(.orange)
                                .transition(.opacity.combined(with: .move(edge: .top)))
                        }
                    }
                }
                .padding(28)
                .frame(maxWidth: 980, alignment: .leading)
            }
        }
        .background(.regularMaterial.opacity(0.18))
        .onAppear {
            appModel.refreshSystemState(force: true)
        }
        .onReceive(timer) { _ in
            appModel.refreshSystemState()
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            MendyAvatarView(mood: appModel.permissions.needsAttention ? .error : .happy, size: MendyAvatarSize.hero)

            VStack(alignment: .leading, spacing: 4) {
                Text("Set up macMender")
                    .font(.largeTitle.bold())
                Text("A private, local utility for fixing small macOS workflow annoyances.")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(28)
    }

    private var finishSubtitle: String {
        if appModel.permissions.accessibility == .granted {
            return "Accessibility is granted. Screen Recording can be enabled later from Privacy and Permissions."
        }
        return "macMender needs Accessibility before it can safely modify input and window behavior."
    }

    private func startUsingMacMender() {
        appModel.permissions.refresh()

        guard appModel.permissions.accessibility == .granted else {
            withAnimation(.snappy(duration: 0.2)) {
                finishMessage = "macOS has not reported Accessibility access for this build yet. Turn on macMender in System Settings, then return here."
            }
            appModel.permissions.requestAccessibility()
            appModel.permissions.openAccessibilitySettings()
            return
        }

        withAnimation(.snappy(duration: 0.25)) {
            finishMessage = nil
            appModel.completeOnboarding()
        }
    }
}

private struct OnboardingMendyIntro: View {
    var body: some View {
        SectionCard(
            title: "Meet Mendy",
            subtitle: "A quiet local helper for smoothing input, tidying the menu bar, and making Dock windows easier to reach.",
            symbolName: "sparkles"
        ) {
            HStack(alignment: .top, spacing: 12) {
                MendyIntroCard(mood: .scanning, title: "Input", detail: "Smooth scroll and mouse fixes")
                MendyIntroCard(mood: .thinking, title: "Menu Bar", detail: "Hide clutter until you hover Mendy")
                MendyIntroCard(mood: .success, title: "Dock", detail: "Window previews and safer defaults")
            }
        }
    }
}

private struct MendyIntroCard: View {
    var mood: MendyMood
    var title: String
    var detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            MendyAvatarView(mood: mood, size: MendyAvatarSize.panel)
            Text(title)
                .font(.headline)
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 194, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PermissionSetupCard: View {
    var title: String
    var detail: String
    var status: PermissionState
    var systemImage: String
    var primaryTitle: String
    var primaryAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text(status.title)
                        .font(.caption)
                        .foregroundStyle(status == .granted ? .green : .orange)
                }
                Spacer()
            }

            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(primaryTitle, action: primaryAction)
                .buttonStyle(.borderedProminent)
                .disabled(status == .granted)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PermissionGuidanceCard: View {
    var title: String
    var detail: String
    var systemImage: String
    var primaryTitle: String
    var primaryAction: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: systemImage)
                    .font(.title2)
                    .foregroundStyle(.secondary)
                    .frame(width: 30)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                    Text("Guided setup")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            Text(detail)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Button(primaryTitle, action: primaryAction)
                .buttonStyle(.bordered)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

private struct PermissionDragToAddGuide: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var animateArrow = false

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            MendyAvatarView(mood: .thinking, size: MendyAvatarSize.panel)

            DraggableAppTile()

            Image(systemName: "arrow.right")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .offset(x: reduceMotion ? 0 : (animateArrow ? 4 : -1))
                .animation(reduceMotion ? nil : .easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: animateArrow)
                .onAppear { animateArrow = true }

            PrivacyListMockup()

            VStack(alignment: .leading, spacing: 10) {
                OnboardingStep(number: 1, title: "Click Open System Settings from macMender.")
                OnboardingStep(number: 2, title: "Look for macMender in the Privacy & Security list.")
                OnboardingStep(number: 3, title: "Drag the macMender app icon here if it is not listed.")
                OnboardingStep(number: 4, title: "Turn the toggle on, then restart macMender if macOS asks.")
                Text("If dragging is not accepted, use the + button or reopen macMender and try again.")
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
            Text("Drag to the permissions list")
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
            Text("Drag macMender here")
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

private struct OnboardingStep: View {
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
        }
    }
}
