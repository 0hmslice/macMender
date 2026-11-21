import AppKit
import SwiftUI

struct MenuBarPopover: View {
    @ObservedObject var appModel: AppModel
    var openSettingsAction: (() -> Void)?
    var closeAction: (() -> Void)?
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    private var isPaused: Bool { appModel.store.config.safeModeEnabled }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    QuickControlTile(
                        title: "Dock Previews",
                        systemImage: SettingsSection.dockPreviews.symbolName,
                        isOn: dockPreviewsBinding
                    )
                    QuickControlTile(
                        title: "Window Switcher",
                        systemImage: SettingsSection.windowSwitcher.symbolName,
                        isOn: windowSwitcherBinding
                    )
                }
                GridRow {
                    QuickControlTile(
                        title: "Three-Finger Tap",
                        systemImage: "hand.tap",
                        isOn: threeFingerTapBinding
                    )
                    QuickControlTile(
                        title: "Reverse Wheel",
                        systemImage: "arrow.up.arrow.down",
                        isOn: externalMouseReverseBinding
                    )
                }
            }
            .disabled(isPaused)
            .opacity(isPaused ? 0.5 : 1)

            keepAwakeRow

            if appModel.shouldShowProfileSwitcher {
                Picker("Profile", selection: Binding(
                    get: { appModel.store.config.activeProfileID },
                    set: { appModel.setActiveProfile($0) }
                )) {
                    ForEach(appModel.store.config.profiles) { profile in
                        Text(profile.name).tag(profile.id)
                    }
                }
                .padding(.horizontal, 2)
            }

            Divider()

            footer
        }
        .padding(12)
        .frame(width: 380, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(nsImage: MacMenderBrandAssets.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text("macMender")
                    .font(.headline)
                HStack(spacing: 5) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 7, height: 7)
                        .accessibilityHidden(true)
                    Text(statusTitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 8)

            if appModel.permissions.accessibility != .granted {
                Button("Fix…") { openSettings(section: .privacy) }
                    .controlSize(.small)
                    .accessibilityHint("Opens Privacy settings to allow Accessibility access")
            } else {
                Button {
                    appModel.toggleSafeMode()
                } label: {
                    Label(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill")
                }
                .controlSize(.small)
                .help(isPaused ? "Turn macMender's features back on" : "Turn every feature off until you resume")
            }
        }
    }

    private var statusTitle: String {
        if appModel.permissions.accessibility != .granted { return "Needs Accessibility access" }
        if isPaused { return "Paused" }
        return appModel.shouldShowProfileSwitcher ? "Running · \(appModel.activeProfile.name)" : "Running"
    }

    private var statusColor: Color {
        if appModel.permissions.accessibility != .granted { return .orange }
        return isPaused ? .yellow : .green
    }

    private var keepAwakeRow: some View {
        let session = appModel.keepAwake.session

        return HStack(spacing: 10) {
            QuickControlIcon(systemImage: session == nil ? "cup.and.saucer" : "cup.and.saucer.fill", isOn: session != nil)

            VStack(alignment: .leading, spacing: 1) {
                Text("Keep Awake")
                    .font(.callout.weight(.medium))
                Text(keepAwakeStatus(session))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            if session != nil {
                Button("Stop", action: appModel.keepAwake.stop)
                    .controlSize(.small)
            } else {
                Menu("Start") {
                    ForEach(KeepAwakeDuration.allCases) { duration in
                        Button(duration.title) {
                            appModel.keepAwake.start(duration: duration, keepDisplayAwake: false)
                        }
                    }
                    Divider()
                    Button("More Options…") { openSettings(section: .keepAwake) }
                }
                .controlSize(.small)
                .fixedSize()
                .disabled(isPaused)
                .accessibilityLabel("Start a Keep Awake session")
            }
        }
        .padding(10)
        .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func keepAwakeStatus(_ session: KeepAwakeSession?) -> String {
        guard let session else { return "Your Mac sleeps as usual" }
        return session.endsAt.map { "Awake until \($0.formatted(date: .omitted, time: .shortened))" } ?? "Awake until you stop it"
    }

    private var footer: some View {
        HStack(spacing: 8) {
            Button {
                openSettings(section: appModel.selectedSection)
            } label: {
                Label("Settings…", systemImage: "gearshape")
            }
            .accessibilityHint("Opens the macMender window")

            Spacer()

            Button("Quit") {
                NSApp.terminate(nil)
            }
            .accessibilityLabel("Quit macMender")
        }
        .buttonStyle(.borderless)
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

/// A Control Center-style switch: a tile that is tinted while its feature is on.
private struct QuickControlTile: View {
    var title: String
    var systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 8) {
                QuickControlIcon(systemImage: systemImage, isOn: isOn)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.callout.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                    Text(isOn ? "On" : "Off")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.quaternary.opacity(isOn ? 1 : 0.6), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(.isToggle)
        // Replacing the button's children drops its default action, so it is given back.
        .accessibilityAction { isOn.toggle() }
    }
}

private struct QuickControlIcon: View {
    var systemImage: String
    var isOn: Bool

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(isOn ? Color.white : Color.primary)
            .frame(width: 28, height: 28)
            .background(isOn ? AnyShapeStyle(Color.accentColor.gradient) : AnyShapeStyle(.quaternary), in: Circle())
            .accessibilityHidden(true)
    }
}
