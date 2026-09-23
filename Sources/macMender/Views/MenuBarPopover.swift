import AppKit
import SwiftUI

struct MenuBarPopover: View {
    @ObservedObject var appModel: AppModel
    var openSettingsAction: (() -> Void)?
    var closeAction: (() -> Void)?
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            VStack(spacing: 0) {
                PopoverControlToggle(
                    title: "Three-Finger Tap",
                    systemImage: "hand.tap",
                    isOn: threeFingerTapBinding,
                    accessibilityHint: "Turn three-finger middle click on or off"
                )
                controlDivider

                PopoverControlToggle(
                    title: "Reverse Mouse Scrolling",
                    systemImage: "computermouse",
                    isOn: externalMouseReverseBinding,
                    accessibilityHint: "Reverse vertical scrolling for an external mouse"
                )
                controlDivider

                PopoverControlToggle(
                    title: "Dock Previews",
                    systemImage: "dock.arrow.up.rectangle",
                    isOn: dockPreviewsBinding,
                    accessibilityHint: "Turn Dock window previews on or off"
                )
                controlDivider

                PopoverControlToggle(
                    title: "Window Switcher",
                    systemImage: "rectangle.3.group",
                    isOn: windowSwitcherBinding,
                    accessibilityHint: "Turn the Option-Tab window switcher on or off"
                )
                controlDivider

                HStack(spacing: 12) {
                    Label("Keep Awake", systemImage: "cup.and.saucer")
                        .labelStyle(PopoverControlLabelStyle())
                    Spacer()
                    Menu {
                        if appModel.keepAwake.isActive {
                            Button("Stop Session", action: appModel.keepAwake.stop)
                            Divider()
                        }
                        ForEach(KeepAwakeDuration.allCases) { duration in
                            Button(duration.title) {
                                appModel.keepAwake.start(duration: duration, keepDisplayAwake: false)
                            }
                            .disabled(appModel.store.config.safeModeEnabled)
                        }
                        Divider()
                        Button("Session Settings…") { openSettings(section: .keepAwake) }
                    } label: {
                        Text(appModel.keepAwake.isActive ? "On" : "Off")
                    }
                    .fixedSize()
                    .accessibilityLabel("Keep Awake session")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                controlDivider

                PopoverControlToggle(
                    title: "Pause Helpers",
                    systemImage: "pause.circle",
                    isOn: Binding(
                        get: { appModel.store.config.safeModeEnabled },
                        set: { _ in appModel.toggleSafeMode() }
                    ),
                    accessibilityHint: "Pause input and window helpers and end Keep Awake sessions"
                )
            }
            .padding(.vertical, 4)

            Divider()

            footer
        }
        .frame(width: 328, height: 310, alignment: .topLeading)
        .background {
            PopoverGlassBackdrop()
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: MacMenderBrandAssets.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)

            Text("macMender")
                .font(.headline)

            Spacer(minLength: 8)

            if appModel.permissions.accessibility != .granted {
                Button {
                    openSettings(section: .privacy)
                } label: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Accessibility permission required")
                .accessibilityLabel("Accessibility permission required")
                .accessibilityHint("Open Privacy settings in macMender")
            } else if appModel.store.config.safeModeEnabled {
                Button {
                    openSettings(section: .advanced)
                } label: {
                    Image(systemName: "pause.circle.fill")
                        .foregroundStyle(.orange)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Safe Mode is pausing helpers")
                .accessibilityLabel("Safe Mode is on")
                .accessibilityHint("Open Advanced settings in macMender")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var controlDivider: some View {
        Divider().padding(.leading, 42)
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                openSettings(section: .overview)
            } label: {
                Label("Open macMender", systemImage: "macwindow")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .accessibilityHint("Open the full app with its sidebar visible")

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .accessibilityLabel("Quit macMender")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var threeFingerTapBinding: Binding<Bool> {
        Binding {
            appModel.activeProfile.isThreeFingerTapEnabled
        } set: { isEnabled in
            appModel.setThreeFingerTapEnabled(isEnabled)
        }
    }

    private var externalMouseReverseBinding: Binding<Bool> {
        Binding {
            appModel.isExternalMouseReverseScrollingEnabled
        } set: { isEnabled in
            appModel.setExternalMouseReverseScrollingEnabled(isEnabled)
        }
    }

    private var dockPreviewsBinding: Binding<Bool> {
        Binding {
            appModel.activeProfile.dockPreviews.enabled
        } set: { isEnabled in
            appModel.setDockPreviewsEnabled(isEnabled)
        }
    }

    private var windowSwitcherBinding: Binding<Bool> {
        Binding {
            appModel.activeProfile.windowSwitcher.enabled
        } set: { isEnabled in
            appModel.setWindowSwitcherEnabled(isEnabled)
        }
    }

    private func openSettings(section: SettingsSection) {
        appModel.requestMainWindow(section: section)
        closeAction?()
        dismiss()

        DispatchQueue.main.async {
            if let openSettingsAction {
                openSettingsAction()
            } else {
                if !appModel.focusPreferencesWindow() {
                    openWindow(id: "preferences")
                }
                appModel.activateApp()
            }
        }
    }
}

private struct PopoverGlassBackdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        if reduceTransparency {
            Color(nsColor: .windowBackgroundColor)
        } else {
            Rectangle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Color.white.opacity(0.08)
                }
        }
    }
}

private struct PopoverControlToggle: View {
    var title: String
    var systemImage: String
    @Binding var isOn: Bool
    var accessibilityHint: String

    var body: some View {
        HStack(spacing: 12) {
            Label(title, systemImage: systemImage)
                .labelStyle(PopoverControlLabelStyle())

            Spacer(minLength: 12)

            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
                .fixedSize()
                .accessibilityLabel(title)
                .accessibilityValue(isOn ? "On" : "Off")
                .accessibilityHint(accessibilityHint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
    }
}

private struct PopoverControlLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 10) {
            configuration.icon
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 20)
            configuration.title
                .foregroundStyle(.primary)
        }
    }
}
