import AppKit
import SwiftUI

struct MenuBarPopover: View {
    @ObservedObject var appModel: AppModel
    var openSettingsAction: (() -> Void)?
    var closeAction: (() -> Void)?
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                MendyAvatarView(mood: appModel.menuBarMendyMood, size: MendyAvatarSize.panel)

                VStack(alignment: .leading, spacing: 2) {
                    Text("macMender")
                        .font(.headline)
                    Text(appModel.runningStatusTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusTone)
                    Text(statusDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .padding(12)
            .liquidGlass(.row)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 8) {
                PopoverStatusChip(title: "Accessibility", isActive: appModel.permissions.accessibility == .granted)
                PopoverStatusChip(title: "Screen Recording", isActive: appModel.permissions.screenRecording == .granted)
                PopoverStatusChip(title: "Dock Previews", isActive: appModel.dockHover.isRunning)
                PopoverStatusChip(title: "Window Switcher", isActive: appModel.store.config.featureToggles.windowSwitcher && appModel.activeProfile.windowSwitcher.enabled)
                PopoverStatusChip(title: "Menu Bar Setup", isActive: true, detail: "Safe")
            }

            VStack(spacing: 8) {
                Button {
                    openSettings()
                } label: {
                    Label(appModel.store.config.hasCompletedOnboarding ? "Open Settings" : "Continue Setup", systemImage: "gearshape")
                }
                .buttonStyle(LiquidGlassButtonStyle())

                Button {
                    appModel.selectedSection = .privacy
                    openSettings()
                } label: {
                    Label("Check Permissions", systemImage: "lock.shield")
                }
                .buttonStyle(LiquidGlassButtonStyle())

                Button {
                    appModel.selectedSection = .menuBar
                    openSettings()
                } label: {
                    Label("Learn Menu Bar Setup", systemImage: "command")
                }
                .buttonStyle(LiquidGlassButtonStyle())
            }

            Text("Arrange menu-bar icons safely with macOS Command-drag.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            Divider()

            Button {
                NSApp.terminate(nil)
            } label: {
                Label("Quit macMender", systemImage: "power")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 4)
        }
        .padding(12)
        .frame(width: 318)
        .liquidGlass(.panel)
    }

    private var statusDetail: String {
        if !appModel.store.config.hasCompletedOnboarding {
            return "Finish setup to start local helpers."
        }
        if appModel.store.config.safeModeEnabled {
            return "Paused by Safe Mode."
        }
        if appModel.permissions.accessibility != .granted {
            return "Accessibility is required for global shortcuts and window actions."
        }
        return "Dock previews and window switching are available. Menu bar setup uses macOS Command-drag."
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

private struct PopoverStatusChip: View {
    var title: String
    var isActive: Bool
    var detail: String?

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: isActive ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(isActive ? .green : .orange)
            Text(detail ?? (isActive ? title : "\(title) Missing"))
                .lineLimit(1)
        }
        .font(.caption2.weight(.medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .frame(maxWidth: .infinity, alignment: .leading)
        .liquidGlass(.row)
    }
}
