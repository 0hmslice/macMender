import AppKit
import SwiftUI

struct MenuBarPopover: View {
    @ObservedObject var appModel: AppModel
    var openSettingsAction: (() -> Void)?
    var closeAction: (() -> Void)?
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        content
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 8) {
            header

            Divider()

            VStack(spacing: 0) {
                PopoverStatusLine(item: permissionsItem)
                Divider().padding(.leading, 25)
                PopoverStatusLine(item: middleClickItem)
                Divider().padding(.leading, 25)
                PopoverStatusLine(item: dockPreviewItem)
                Divider().padding(.leading, 25)
                PopoverStatusLine(item: windowSwitcherItem)
            }

            actionRow

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
                .accessibilityLabel("Quit macMender")
            }
        }
        .padding(12)
        .frame(width: 292, height: 236, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: overallSymbolName)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(overallTone.color)
                .frame(width: 32, height: 32)
                .background(overallTone.color.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("macMender")
                    .font(.headline)
                Text(appModel.runningStatusTitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(overallTone.color)
                Text(appModel.runningStatusDetail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }

            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("macMender status")
        .accessibilityValue("\(appModel.runningStatusTitle). \(appModel.runningStatusDetail)")
    }

    private var overallTone: MacMenderStatusTone {
        if !appModel.store.config.hasCompletedOnboarding {
            return .attention
        }
        if appModel.store.config.safeModeEnabled {
            return .paused
        }
        if permissionsNeedAttention {
            return .attention
        }
        return appModel.systemEvents.status.eventTapRunning ? .active : .neutral
    }

    private var overallSymbolName: String {
        guard appModel.store.config.hasCompletedOnboarding,
              !appModel.store.config.safeModeEnabled,
              !permissionsNeedAttention,
              !appModel.systemEvents.status.eventTapRunning else {
            return appModel.runningStatusSymbol
        }
        return "circle.dashed"
    }

    private var permissionsItem: PopoverStatusItem {
        let missing = requiredPermissionNames
        if missing.isEmpty {
            return PopoverStatusItem(title: "Permissions", value: "Ready", symbolName: "lock.shield", tone: .active)
        }
        let value = missing.count == 1 ? "Needs \(missing[0])" : "\(missing.count) need review"
        return PopoverStatusItem(title: "Permissions", value: value, symbolName: "lock.shield", tone: .attention)
    }

    private var middleClickItem: PopoverStatusItem {
        let status = PermissionStatusPolicy.threeFingerTapStatus(
            settings: appModel.activeProfile.middleClick,
            accessibility: appModel.permissions.accessibility,
            safeModeEnabled: appModel.store.config.safeModeEnabled,
            runtimeRunning: appModel.multitouchMiddleClick.isRunning
        )
        return PopoverStatusItem(title: "Three-Finger Tap", value: status.title, symbolName: "hand.tap", tone: MacMenderStatusTone(featureStatusKind: status.kind))
    }

    private var dockPreviewItem: PopoverStatusItem {
        let status = PermissionStatusPolicy.dockPreviewStatus(
            settings: appModel.activeProfile.dockPreviews,
            accessibility: appModel.permissions.accessibility,
            safeModeEnabled: appModel.store.config.safeModeEnabled,
            runtimeRunning: appModel.dockHover.isRunning
        )
        return PopoverStatusItem(title: "Dock Previews", value: status.title, symbolName: "dock.rectangle", tone: MacMenderStatusTone(featureStatusKind: status.kind))
    }

    private var windowSwitcherItem: PopoverStatusItem {
        let status = PermissionStatusPolicy.windowSwitcherStatus(
            settings: appModel.activeProfile.windowSwitcher,
            featureEnabled: appModel.store.config.featureToggles.windowSwitcher,
            accessibility: appModel.permissions.accessibility,
            safeModeEnabled: appModel.store.config.safeModeEnabled
        )
        return PopoverStatusItem(title: "Window Switcher", value: status.title, symbolName: "rectangle.3.group", tone: MacMenderStatusTone(featureStatusKind: status.kind))
    }

    private var permissionsNeedAttention: Bool {
        !requiredPermissionNames.isEmpty
    }

    private var shouldShowPermissionsAction: Bool {
        permissionsNeedAttention || !appModel.store.config.hasCompletedOnboarding
    }

    private var requiredPermissionNames: [String] {
        PermissionStatusPolicy.requiredPermissionNames(accessibility: appModel.permissions.accessibility)
    }

    private var footerStatus: String {
        if !appModel.store.config.hasCompletedOnboarding {
            return "Finish setup in macMender."
        }
        if appModel.store.config.safeModeEnabled {
            return "Input and previews are paused."
        }
        if permissionsNeedAttention {
            return "Review permissions to finish setup."
        }
        if !appModel.systemEvents.status.eventTapRunning {
            return "Starting local helpers…"
        }
        return "Running locally."
    }

    private var actionRow: some View {
        HStack(spacing: 6) {
            Button {
                openSettings()
            } label: {
                Label("Open macMender", systemImage: "arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .accessibilityHint("Opens the macMender settings window")

            if shouldShowPermissionsAction {
                Button {
                    appModel.selectedSection = .privacy
                    openSettings()
                } label: {
                    Label("Permissions", systemImage: "lock.shield")
                }
                .buttonStyle(.borderless)
                .controlSize(.small)
                .accessibilityHint("Opens the Privacy page in macMender")
            }
        }
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

private struct PopoverStatusItem {
    var title: String
    var value: String
    var symbolName: String
    var tone: MacMenderStatusTone
}

private struct PopoverStatusLine: View {
    var item: PopoverStatusItem

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: item.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 18)
                .accessibilityHidden(true)

            Text(item.title)
                .font(.caption)
                .foregroundStyle(.primary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Label(item.value, systemImage: item.tone.defaultSymbol)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(item.tone.color)
                .lineLimit(1)
                .minimumScaleFactor(0.78)
        }
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(item.title)
        .accessibilityValue(item.value)
    }
}
