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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 9) {
                MendyAvatarView(mood: appModel.statusItemMendyMood, size: MendyAvatarSize.compact)

                VStack(alignment: .leading, spacing: 1) {
                    Text("macMender")
                        .font(.headline)
                    Text(popoverStatusTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusTone)
                }

                Spacer()
                StatusDot(isActive: !appModel.store.config.safeModeEnabled && appModel.permissions.accessibility == .granted)
            }
            .padding(10)
            .liquidGlass(.row)

            VStack(spacing: 6) {
                PopoverStatusRow(title: "Accessibility", value: appModel.permissions.accessibility.title, isActive: appModel.permissions.accessibility == .granted)
                PopoverStatusRow(title: "Screen Recording", value: appModel.permissions.screenRecording.title, isActive: appModel.permissions.screenRecording == .granted)
                PopoverStatusRow(title: "Window Switcher", value: windowSwitcherStatus, isActive: windowSwitcherIsReady)
                PopoverStatusRow(title: "Dock previews", value: appModel.dockHover.isRunning ? "Ready" : "Paused", isActive: appModel.dockHover.isRunning)
            }

            HStack(spacing: 8) {
                Button {
                    openSettings()
                } label: {
                    Label(appModel.store.config.hasCompletedOnboarding ? "Settings" : "Setup", systemImage: "gearshape")
                }
                .buttonStyle(LiquidGlassButtonStyle())

                Button {
                    appModel.selectedSection = .privacy
                    openSettings()
                } label: {
                    Label("Check Permissions", systemImage: "lock.shield")
                }
                .buttonStyle(LiquidGlassButtonStyle())
            }

            HStack {
                Text(statusDetail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Spacer()
                Button {
                    NSApp.terminate(nil)
                } label: {
                    Label("Quit", systemImage: "power")
                        .labelStyle(.iconOnly)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Quit macMender")
            }
        }
        .padding(10)
        .frame(width: 306)
        .liquidGlass(.panel)
    }

    private var statusDetail: String {
        if !appModel.store.config.hasCompletedOnboarding {
            return "Setup is not complete."
        }
        if appModel.store.config.safeModeEnabled {
            return "Safe Mode is on."
        }
        if appModel.permissions.accessibility != .granted {
            return "Accessibility is required."
        }
        return "macMender is running locally."
    }

    private var popoverStatusTitle: String {
        if appModel.store.config.safeModeEnabled { return "Paused" }
        if appModel.permissions.needsAttention { return "Needs attention" }
        return "Running"
    }

    private var windowSwitcherIsReady: Bool {
        appModel.store.config.featureToggles.windowSwitcher &&
        !appModel.store.config.safeModeEnabled &&
        appModel.permissions.accessibility == .granted
    }

    private var windowSwitcherStatus: String {
        if !appModel.store.config.featureToggles.windowSwitcher { return "Off" }
        if appModel.store.config.safeModeEnabled { return "Paused" }
        if appModel.permissions.accessibility != .granted { return "Needs Access" }
        return appModel.windowSwitcher.isShowing ? "Open" : "Ready"
    }

    private var statusTone: Color {
        if appModel.store.config.safeModeEnabled { return .secondary }
        if appModel.permissions.accessibility != .granted { return .orange }
        return .green
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

private struct PopoverStatusRow: View {
    var title: String
    var value: String
    var isActive: Bool

    var body: some View {
        HStack(spacing: 6) {
            StatusDot(isActive: isActive)
            Text(title)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Text(value)
                .foregroundStyle(isActive ? .green : .secondary)
                .lineLimit(1)
        }
        .font(.caption.weight(.medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(.row)
    }
}

private struct StatusDot: View {
    var isActive: Bool

    var body: some View {
        Circle()
            .fill(isActive ? .green : .orange)
            .frame(width: 7, height: 7)
            .shadow(color: (isActive ? Color.green : Color.orange).opacity(0.55), radius: 5)
    }
}
