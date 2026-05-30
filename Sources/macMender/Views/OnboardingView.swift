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
                        subtitle: "Grant the access macMender needs to tune input, middle-click, and window behavior. Nothing leaves this Mac.",
                        symbolName: "wrench.and.screwdriver"
                    ) {
                        HStack(alignment: .top, spacing: 16) {
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
                        }
                    }

                    SectionCard(
                        title: "Drag macMender into Settings",
                        subtitle: "If System Settings shows an empty permissions list or an add button, drag this app tile into the list after opening the correct pane.",
                        symbolName: "hand.draw"
                    ) {
                        HStack(spacing: 16) {
                            DraggableAppTile()

                            VStack(alignment: .leading, spacing: 10) {
                                OnboardingStep(number: 1, title: "Click Open Accessibility.")
                                OnboardingStep(number: 2, title: "Unlock System Settings if macOS asks.")
                                OnboardingStep(number: 3, title: "Turn on macMender, or drag the app tile into the list if macOS asks you to add an app.")
                                OnboardingStep(number: 4, title: "Return here. The status updates automatically.")
                            }
                        }
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

private struct DraggableAppTile: View {
    private var appURL: URL {
        Bundle.main.bundleURL
    }

    var body: some View {
        VStack(spacing: 10) {
            MendyAvatarView(mood: .idle, size: MendyAvatarSize.panel)

            Text("macMender.app")
                .font(.headline)
            Text("Drag to the permissions list")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 210, height: 180)
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
