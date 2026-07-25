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
                ForEach(statusItems) { item in
                    PopoverFeatureRow(item: item) {
                        openSettings(section: item.section)
                    }

                    if item.id != statusItems.last?.id {
                        Divider().padding(.leading, 36)
                    }
                }
            }
            .padding(.vertical, 5)

            Divider()

            footer
        }
        .frame(width: 312, height: 286, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 11) {
            Image(nsImage: MacMenderBrandAssets.applicationIconImage)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 34, height: 34)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text("macMender")
                    .font(.headline)

                Text(headerDetail)
                    .font(.caption)
                    .foregroundStyle(headerTone)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            Menu {
                Button("Quit macMender") {
                    NSApp.terminate(nil)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .frame(width: 20, height: 20)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More macMender actions")
            .accessibilityLabel("More macMender actions")
        }
        .padding(13)
        .accessibilityElement(children: .combine)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("Profile")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Text(appModel.activeProfile.name)
                    .font(.caption)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button {
                openSettings(section: .overview)
            } label: {
                Label("Open macMender", systemImage: "macwindow")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .accessibilityHint("Opens the full macMender window with its sidebar visible")
        }
        .padding(13)
    }

    private var statusItems: [PopoverFeatureItem] {
        [
            PopoverFeatureItem(
                title: "Permissions",
                value: requiredPermissionNames.isEmpty ? "Granted" : "Needs access",
                systemImage: SettingsSection.privacy.symbolName,
                tone: requiredPermissionNames.isEmpty ? .quiet : .attention,
                section: .privacy
            ),
            featureItem(
                title: "Three-Finger Tap",
                summary: PermissionStatusPolicy.threeFingerTapStatus(
                    settings: appModel.activeProfile.middleClick,
                    accessibility: appModel.permissions.accessibility,
                    safeModeEnabled: appModel.store.config.safeModeEnabled,
                    runtimeRunning: appModel.multitouchMiddleClick.isRunning
                ),
                systemImage: "hand.tap",
                section: .input
            ),
            featureItem(
                title: "Dock Previews",
                summary: PermissionStatusPolicy.dockPreviewStatus(
                    settings: appModel.activeProfile.dockPreviews,
                    accessibility: appModel.permissions.accessibility,
                    safeModeEnabled: appModel.store.config.safeModeEnabled,
                    runtimeRunning: appModel.dockHover.isRunning
                ),
                systemImage: "dock.arrow.up.rectangle",
                section: .dockWindows
            ),
            featureItem(
                title: "Window Switcher",
                summary: PermissionStatusPolicy.windowSwitcherStatus(
                    settings: appModel.activeProfile.windowSwitcher,
                    featureEnabled: appModel.store.config.featureToggles.windowSwitcher,
                    accessibility: appModel.permissions.accessibility,
                    safeModeEnabled: appModel.store.config.safeModeEnabled
                ),
                systemImage: "rectangle.3.group",
                section: .dockWindows
            )
        ]
    }

    private var headerDetail: String {
        if !appModel.store.config.hasCompletedOnboarding {
            return "Finish setup to enable features"
        }
        if appModel.store.config.safeModeEnabled {
            return "Features are paused by Safe Mode"
        }
        if !requiredPermissionNames.isEmpty {
            return "Accessibility needs attention"
        }

        let count = [
            appModel.activeProfile.middleClick.enabled,
            appModel.activeProfile.dockPreviews.enabled,
            appModel.activeProfile.windowSwitcher.enabled && appModel.store.config.featureToggles.windowSwitcher
        ].filter { $0 }.count
        return "\(count) feature\(count == 1 ? "" : "s") enabled"
    }

    private var headerTone: Color {
        if appModel.store.config.safeModeEnabled || !requiredPermissionNames.isEmpty {
            return .orange
        }
        return .secondary
    }

    private var requiredPermissionNames: [String] {
        PermissionStatusPolicy.requiredPermissionNames(accessibility: appModel.permissions.accessibility)
    }

    private func featureItem(
        title: String,
        summary: FeatureStatusSummary,
        systemImage: String,
        section: SettingsSection
    ) -> PopoverFeatureItem {
        PopoverFeatureItem(
            title: title,
            value: summary.shortDisplayValue,
            systemImage: systemImage,
            tone: PopoverFeatureTone(summary.kind),
            section: section
        )
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

private struct PopoverFeatureItem: Identifiable {
    var title: String
    var value: String
    var systemImage: String
    var tone: PopoverFeatureTone
    var section: SettingsSection

    var id: String { title }
}

private enum PopoverFeatureTone {
    case quiet
    case paused
    case attention

    init(_ statusKind: FeatureStatusKind) {
        switch statusKind {
        case .needsAttention:
            self = .attention
        case .paused:
            self = .paused
        case .active, .ready, .off, .optional:
            self = .quiet
        }
    }

    var color: Color {
        switch self {
        case .quiet:
            .secondary
        case .paused, .attention:
            .orange
        }
    }
}

private extension FeatureStatusSummary {
    var shortDisplayValue: String {
        switch kind {
        case .active:
            "On"
        case .ready:
            "Available"
        case .paused:
            "Paused"
        case .needsAttention:
            "Needs attention"
        case .off:
            "Off"
        case .optional:
            "Optional"
        }
    }
}

private struct PopoverFeatureRow: View {
    var item: PopoverFeatureItem
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: item.systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 20)
                    .accessibilityHidden(true)

                Text(item.title)
                    .foregroundStyle(.primary)

                Spacer(minLength: 8)

                Text(item.value)
                    .font(.caption)
                    .foregroundStyle(item.tone.color)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .contentShape(.rect)
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.title), \(item.value)")
        .accessibilityHint("Open \(item.section.title) settings")
    }
}
