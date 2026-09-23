import SwiftUI

struct OverviewView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        MacMenderScrollablePage(maxContentWidth: 820) {
            MacMenderPageHeader(
                title: "Overview",
                subtitle: "Review the current profile and open the features you want to adjust.",
                systemImage: SettingsSection.overview.symbolName
            )

            OverviewProfileSummary(appModel: appModel)

            if appModel.permissions.needsAttention {
                MacMenderCallout(systemImage: "exclamationmark.circle", tone: .attention) {
                    HStack {
                        Text("Accessibility is required for shortcuts, Dock previews, and window actions.")
                            .foregroundStyle(.secondary)
                        Spacer(minLength: MacMenderSpacing.standard)
                        Button("Review Permissions") {
                            appModel.selectedSection = .privacy
                        }
                    }
                }
            } else if appModel.store.config.safeModeEnabled {
                MacMenderCallout(systemImage: "pause.circle", tone: .paused) {
                    Text("Safe Mode is pausing input and window helpers.")
                        .foregroundStyle(.secondary)
                }
            }

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
                        systemImage: "dock.arrow.up.rectangle",
                        action: { appModel.selectedSection = .dockWindows }
                    )

                    Divider()

                    OverviewFeatureRow(
                        title: "Keep Awake",
                        summary: FeatureStatusSummary(
                            title: appModel.keepAwake.isActive ? "Active" : "Ready",
                            detail: appModel.keepAwake.isActive ? "A keep-awake session is running." : "Keep your Mac awake for a timed session.",
                            kind: appModel.keepAwake.isActive ? .active : .ready
                        ),
                        systemImage: "cup.and.saucer",
                        action: { appModel.selectedSection = .keepAwake }
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

private struct OverviewProfileSummary: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        HStack(alignment: .center, spacing: MacMenderSpacing.standard) {
            Image(systemName: SettingsSection.profiles.symbolName)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 28)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: MacMenderSpacing.compact) {
                Text(appModel.activeProfile.name)
                    .font(.headline)
                Text("Current profile · Input, Dock, and window settings")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: MacMenderSpacing.standard)

            Button("Manage Profiles") {
                appModel.selectedSection = .profiles
            }
            .controlSize(.small)
        }
        .padding(MacMenderSpacing.standard)
        .frame(maxWidth: .infinity, alignment: .leading)
        .macMenderContentSurface()
        .accessibilityElement(children: .contain)
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

                if shouldShowStatus {
                    MacMenderStatusLabel(
                        title: summary.title,
                        tone: MacMenderStatusTone(featureStatusKind: summary.kind)
                    )
                }

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

    private var shouldShowStatus: Bool {
        switch summary.kind {
        case .active, .ready:
            false
        case .paused, .needsAttention, .off, .optional:
            true
        }
    }
}
