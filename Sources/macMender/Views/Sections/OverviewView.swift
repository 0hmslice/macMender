import SwiftUI

struct OverviewView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        MacMenderScrollablePage(maxContentWidth: 820) {
            OverviewSummary(appModel: appModel)

            MacMenderContentSection(
                title: "Features",
                subtitle: "Open a feature to review its settings.",
                systemImage: "slider.horizontal.3"
            ) {
                VStack(spacing: 0) {
                    OverviewFeatureRow(
                        title: "Permissions",
                        summary: permissionsSummary,
                        systemImage: "lock.shield",
                        action: { appModel.selectedSection = .privacy }
                    )

                    Divider()

                    OverviewFeatureRow(
                        title: "Three-Finger Tap",
                        summary: threeFingerTapSummary,
                        systemImage: "hand.tap",
                        action: { appModel.selectedSection = .input }
                    )

                    Divider()

                    OverviewFeatureRow(
                        title: "Window Switcher",
                        summary: windowSwitcherSummary,
                        systemImage: "rectangle.3.group",
                        action: { appModel.selectedSection = .dockWindows }
                    )

                    Divider()

                    OverviewFeatureRow(
                        title: "Dock Previews",
                        summary: dockPreviewSummary,
                        systemImage: "dock.rectangle",
                        action: { appModel.selectedSection = .dockWindows }
                    )
                }
            }
        }
    }

    private var permissionsSummary: FeatureStatusSummary {
        PermissionStatusPolicy.permissionsSummary(
            accessibility: appModel.permissions.accessibility,
            screenRecording: appModel.permissions.screenRecording,
            inputMonitoring: appModel.permissions.inputMonitoring
        )
    }

    private var threeFingerTapSummary: FeatureStatusSummary {
        PermissionStatusPolicy.threeFingerTapStatus(
            settings: appModel.activeProfile.middleClick,
            accessibility: appModel.permissions.accessibility,
            safeModeEnabled: appModel.store.config.safeModeEnabled,
            runtimeRunning: appModel.multitouchMiddleClick.isRunning
        )
    }

    private var windowSwitcherSummary: FeatureStatusSummary {
        PermissionStatusPolicy.windowSwitcherStatus(
            settings: appModel.activeProfile.windowSwitcher,
            featureEnabled: appModel.store.config.featureToggles.windowSwitcher,
            accessibility: appModel.permissions.accessibility,
            safeModeEnabled: appModel.store.config.safeModeEnabled
        )
    }

    private var dockPreviewSummary: FeatureStatusSummary {
        PermissionStatusPolicy.dockPreviewStatus(
            settings: appModel.activeProfile.dockPreviews,
            accessibility: appModel.permissions.accessibility,
            safeModeEnabled: appModel.store.config.safeModeEnabled,
            runtimeRunning: appModel.dockHover.isRunning
        )
    }
}
private struct OverviewSummary: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        HStack(alignment: .center, spacing: MacMenderSpacing.section) {
            Image(systemName: summarySymbol)
                .font(.system(size: 25, weight: .semibold))
                .foregroundStyle(summaryTone.color)
                .frame(width: 48, height: 48)
                .background(summaryTone.color.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: MacMenderSpacing.compact) {
                Text(summaryTitle)
                    .font(.title2.weight(.semibold))
                    .accessibilityAddTraits(.isHeader)

                Text(summaryDetail)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Label("Profile: \(appModel.activeProfile.name)", systemImage: appModel.activeProfile.symbolName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: MacMenderSpacing.standard)

            if appModel.permissions.needsAttention {
                Button("Review Permissions") {
                    appModel.selectedSection = .privacy
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(MacMenderSpacing.section)
        .frame(maxWidth: .infinity, alignment: .leading)
        .macMenderContentSurface(radius: MacMenderRadius.prominent)
        .accessibilityElement(children: .contain)
    }

    private var summaryTitle: String {
        if appModel.permissions.needsAttention {
            return "One action needs attention"
        }
        if appModel.store.config.safeModeEnabled {
            return "Safe Mode is on"
        }
        return "macMender is ready"
    }

    private var summaryDetail: String {
        if appModel.permissions.needsAttention {
            return "Accessibility is required before shortcuts, Dock previews, and window actions can run."
        }
        if appModel.store.config.safeModeEnabled {
            return "Active system helpers are paused until you turn Safe Mode off."
        }
        return "Your enabled helpers are available and macMender is running normally."
    }

    private var summaryTone: MacMenderStatusTone {
        if appModel.permissions.needsAttention {
            return .attention
        }
        if appModel.store.config.safeModeEnabled {
            return .paused
        }
        return .active
    }

    private var summarySymbol: String {
        summaryTone.defaultSymbol
    }
}

private struct OverviewFeatureRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var title: String
    var summary: FeatureStatusSummary
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: MacMenderSpacing.standard) {
                Image(systemName: systemImage)
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: MacMenderSpacing.compact) {
                    Text(title)
                        .font(.body.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(summary.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: MacMenderSpacing.standard)

                MacMenderStatusLabel(
                    title: summary.title,
                    tone: MacMenderStatusTone(featureStatusKind: summary.kind)
                )

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.horizontal, MacMenderSpacing.small)
            .padding(.vertical, MacMenderSpacing.standard)
            .contentShape(.rect)
            .background(
                Color.primary.opacity(isHovered ? 0.05 : 0),
                in: RoundedRectangle(cornerRadius: MacMenderRadius.control, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .animation(MacMenderMotion.feedback(reduceMotion: reduceMotion), value: isHovered)
        .onHover { isHovered = $0 }
        .accessibilityLabel("\(title), \(summary.title). \(summary.detail)")
        .accessibilityHint("Open settings")
    }
}
