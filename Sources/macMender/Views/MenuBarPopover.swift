import AppKit
import SwiftUI

struct MenuBarPopover: View {
    @ObservedObject var appModel: AppModel
    var openSettingsAction: (() -> Void)?
    var closeAction: (() -> Void)?
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer {
                content
            }
        } else {
            content
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 9) {
            header

            VStack(spacing: 5) {
                PopoverStatusLine(item: permissionsItem)
                PopoverStatusLine(item: middleClickItem)
                PopoverStatusLine(item: dockPreviewItem)
                PopoverStatusLine(item: windowSwitcherItem)
            }

            HStack(spacing: 7) {
                Button {
                    openSettings()
                } label: {
                    Label("Open macMender", systemImage: "arrow.right")
                }
                .buttonStyle(PopoverPrimaryButtonStyle())

                if shouldShowPermissionsAction {
                    Button {
                        appModel.selectedSection = .privacy
                        openSettings()
                    } label: {
                        Label("Permissions", systemImage: "lock.shield")
                    }
                    .buttonStyle(PopoverSecondaryButtonStyle())
                }
            }

            HStack {
                Text(footerStatus)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Image(systemName: "power")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                }
                .buttonStyle(.plain)
                .help("Quit macMender")
            }
        }
        .padding(10)
        .frame(width: 292)
        .liquidGlass(.panel)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 9) {
            MendyAvatarView(mood: appModel.statusItemMendyMood, size: MendyAvatarSize.compact)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text("macMender")
                    .font(.headline)
                Text(overallState.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(overallState.color)
                Text(overallState.detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: overallState.symbolName)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(overallState.color)
        }
        .padding(9)
        .liquidGlass(.row)
    }

    private var overallState: PopoverState {
        if appModel.store.config.safeModeEnabled {
            return PopoverState(title: "Paused", detail: "Safe Mode is on.", symbolName: "pause.circle.fill", color: .secondary)
        }
        if !appModel.store.config.hasCompletedOnboarding {
            return PopoverState(title: "Limited", detail: "Setup is not complete.", symbolName: "arrow.right.circle.fill", color: .orange)
        }
        if permissionsNeedAttention {
            return PopoverState(title: "Needs Attention", detail: "A permission needs review.", symbolName: "exclamationmark.circle.fill", color: .orange)
        }
        return PopoverState(title: "Running", detail: "Core features are ready.", symbolName: "checkmark.circle.fill", color: .green)
    }

    private var permissionsItem: PopoverStatusItem {
        let missing = missingPermissionNames
        if missing.isEmpty {
            return PopoverStatusItem(title: "Permissions", value: "Ready", symbolName: "lock.shield", tone: .active)
        }
        let value = missing.count == 1 ? "Needs \(missing[0])" : "\(missing.count) need review"
        return PopoverStatusItem(title: "Permissions", value: value, symbolName: "lock.shield", tone: .warning)
    }

    private var middleClickItem: PopoverStatusItem {
        let settings = appModel.activeProfile.middleClick
        guard settings.enabled, settings.trigger == .experimentalThreeFinger else {
            return PopoverStatusItem(title: "Three-Finger Tap", value: "Off", symbolName: "hand.tap", tone: .neutral)
        }
        if appModel.store.config.safeModeEnabled {
            return PopoverStatusItem(title: "Three-Finger Tap", value: "Paused", symbolName: "hand.tap", tone: .neutral)
        }
        guard appModel.permissions.accessibility == .granted else {
            return PopoverStatusItem(title: "Three-Finger Tap", value: "Needs access", symbolName: "hand.tap", tone: .warning)
        }
        guard appModel.permissions.inputMonitoring == .granted else {
            return PopoverStatusItem(title: "Three-Finger Tap", value: "Check input", symbolName: "hand.tap", tone: .warning)
        }
        let value = appModel.multitouchMiddleClick.isRunning ? "Active" : "Ready"
        return PopoverStatusItem(title: "Three-Finger Tap", value: value, symbolName: "hand.tap", tone: appModel.multitouchMiddleClick.isRunning ? .active : .neutral)
    }

    private var dockPreviewItem: PopoverStatusItem {
        guard appModel.activeProfile.dockPreviews.enabled else {
            return PopoverStatusItem(title: "Dock previews", value: "Off", symbolName: "dock.rectangle", tone: .neutral)
        }
        if appModel.store.config.safeModeEnabled {
            return PopoverStatusItem(title: "Dock previews", value: "Paused", symbolName: "dock.rectangle", tone: .neutral)
        }
        guard appModel.permissions.accessibility == .granted else {
            return PopoverStatusItem(title: "Dock previews", value: "Needs access", symbolName: "dock.rectangle", tone: .warning)
        }
        let value = appModel.dockHover.isRunning ? "Ready" : "Starting"
        return PopoverStatusItem(title: "Dock previews", value: value, symbolName: "dock.rectangle", tone: appModel.dockHover.isRunning ? .active : .neutral)
    }

    private var windowSwitcherItem: PopoverStatusItem {
        guard appModel.store.config.featureToggles.windowSwitcher else {
            return PopoverStatusItem(title: "Window Switcher", value: "Off", symbolName: "rectangle.3.group", tone: .neutral)
        }
        if appModel.store.config.safeModeEnabled {
            return PopoverStatusItem(title: "Window Switcher", value: "Paused", symbolName: "rectangle.3.group", tone: .neutral)
        }
        guard appModel.permissions.accessibility == .granted else {
            return PopoverStatusItem(title: "Window Switcher", value: "Needs access", symbolName: "rectangle.3.group", tone: .warning)
        }
        return PopoverStatusItem(title: "Window Switcher", value: "Ready", symbolName: "rectangle.3.group", tone: .active)
    }

    private var permissionsNeedAttention: Bool {
        !missingPermissionNames.isEmpty
    }

    private var shouldShowPermissionsAction: Bool {
        permissionsNeedAttention || !appModel.store.config.hasCompletedOnboarding
    }

    private var missingPermissionNames: [String] {
        var names = [String]()
        if appModel.permissions.accessibility != .granted {
            names.append("Accessibility")
        }
        if appModel.permissions.screenRecording != .granted {
            names.append("Screen Recording")
        }
        let middleClick = appModel.activeProfile.middleClick
        if middleClick.enabled,
           middleClick.trigger == .experimentalThreeFinger,
           appModel.permissions.inputMonitoring != .granted {
            names.append("Input Monitoring")
        }
        return names
    }

    private var footerStatus: String {
        if appModel.store.config.safeModeEnabled {
            return "Input and previews are paused."
        }
        if permissionsNeedAttention {
            return "Review permissions to finish setup."
        }
        return "Running locally."
    }

    private func openSettings() {
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

private struct PopoverState {
    var title: String
    var detail: String
    var symbolName: String
    var color: Color
}

private struct PopoverStatusItem {
    var title: String
    var value: String
    var symbolName: String
    var tone: PopoverStatusTone
}

private enum PopoverStatusTone {
    case active
    case warning
    case neutral

    var color: Color {
        switch self {
        case .active:
            .green
        case .warning:
            .orange
        case .neutral:
            .secondary
        }
    }
}

private struct PopoverStatusLine: View {
    var item: PopoverStatusItem

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: item.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(item.tone.color)
                .frame(width: 18)

            Text(item.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(item.value)
                .font(.caption.weight(.medium))
                .foregroundStyle(item.tone.color)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .liquidGlass(.row, radius: 7)
    }
}

private struct PopoverPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .liquidGlass(.button, radius: 7)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(LiquidGlassMotion.quick, value: configuration.isPressed)
    }
}

private struct PopoverSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .fixedSize(horizontal: true, vertical: false)
            .liquidGlass(.button, radius: 7)
            .opacity(configuration.isPressed ? 0.78 : 1)
            .animation(LiquidGlassMotion.quick, value: configuration.isPressed)
    }
}
