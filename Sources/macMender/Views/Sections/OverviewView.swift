import SwiftUI

struct OverviewView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        PreferencesScrollView {
            OverviewHero(appModel: appModel)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 14)], spacing: 14) {
                OverviewPermissionsCard(appModel: appModel)
                OverviewMiddleClickCard(appModel: appModel)
                OverviewWindowSwitcherCard(appModel: appModel)
                OverviewDockPreviewsCard(appModel: appModel)
            }
        }
    }
}

private struct OverviewHero: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        HStack(spacing: 26) {
            MendySectionImageView(section: .overview, size: MendyAvatarSize.prominent)

            VStack(alignment: .leading, spacing: 12) {
                Text("macMender is \(appModel.runningStatusTitle.lowercased())")
                    .font(.system(size: 34, weight: .semibold))
                    .lineLimit(1)
                Text(heroSubtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    CapabilityBadge(title: permissionsStatus.title, systemImage: "checkmark.circle.fill", tone: CapabilityBadge.Tone(featureStatusKind: permissionsStatus.kind))
                    CapabilityBadge(title: dockPreviewStatus.title, systemImage: "dock.rectangle", tone: CapabilityBadge.Tone(featureStatusKind: dockPreviewStatus.kind))
                    CapabilityBadge(title: windowSwitcherStatus.title, systemImage: "rectangle.3.group", tone: CapabilityBadge.Tone(featureStatusKind: windowSwitcherStatus.kind))
                }
            }

            Spacer(minLength: 0)

            if appModel.permissions.needsAttention {
                Button("Open Permissions") {
                    appModel.selectedSection = .privacy
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(28)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.thinMaterial)
                .overlay {
                    LinearGradient(
                        colors: [
                            Color.blue.opacity(0.16),
                            Color.cyan.opacity(0.07),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                }
                .overlay(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.22), lineWidth: 1)
                }
                .shadow(color: Color.black.opacity(0.10), radius: 18, y: 8)
        }
    }

    private var heroSubtitle: String {
        if appModel.permissions.needsAttention {
            return "Accessibility needs review before shortcuts, previews, and window actions can run."
        }
        if appModel.store.config.safeModeEnabled {
            return "Safe Mode is on, so active system changes are paused."
        }
        return "Your Mac is set up and the main helpers are ready."
    }

    private var permissionsStatus: FeatureStatusSummary {
        PermissionStatusPolicy.permissionsSummary(
            accessibility: appModel.permissions.accessibility,
            screenRecording: appModel.permissions.screenRecording,
            inputMonitoring: appModel.permissions.inputMonitoring
        )
    }

    private var dockPreviewStatus: FeatureStatusSummary {
        PermissionStatusPolicy.dockPreviewStatus(
            settings: appModel.activeProfile.dockPreviews,
            accessibility: appModel.permissions.accessibility,
            safeModeEnabled: appModel.store.config.safeModeEnabled,
            runtimeRunning: appModel.dockHover.isRunning
        )
    }

    private var windowSwitcherStatus: FeatureStatusSummary {
        PermissionStatusPolicy.windowSwitcherStatus(
            settings: appModel.activeProfile.windowSwitcher,
            featureEnabled: appModel.store.config.featureToggles.windowSwitcher,
            accessibility: appModel.permissions.accessibility,
            safeModeEnabled: appModel.store.config.safeModeEnabled
        )
    }
}

private struct OverviewPermissionsCard: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        OverviewFeatureCard(
            title: "Permissions",
            benefit: permissionsStatus.detail,
            systemImage: "lock.shield",
            status: permissionsStatus.title,
            tone: CapabilityBadge.Tone(featureStatusKind: permissionsStatus.kind),
            detailRows: [
                OverviewDetailRowData(title: "Accessibility", value: appModel.permissions.accessibility.title, tone: permissionTone(appModel.permissions.accessibility)),
                OverviewDetailRowData(title: "Screen Recording", value: PermissionStatusPolicy.screenRecordingSummary(appModel.permissions.screenRecording).title, tone: CapabilityBadge.Tone(featureStatusKind: PermissionStatusPolicy.screenRecordingSummary(appModel.permissions.screenRecording).kind)),
                OverviewDetailRowData(title: "Input Monitoring", value: PermissionStatusPolicy.inputMonitoringSummary(appModel.permissions.inputMonitoring).title, tone: CapabilityBadge.Tone(featureStatusKind: PermissionStatusPolicy.inputMonitoringSummary(appModel.permissions.inputMonitoring).kind))
            ],
            actionLabel: appModel.permissions.needsAttention ? "Review permissions" : "Open Privacy",
            action: { appModel.selectedSection = .privacy }
        )
    }

    private var permissionsStatus: FeatureStatusSummary {
        PermissionStatusPolicy.permissionsSummary(
            accessibility: appModel.permissions.accessibility,
            screenRecording: appModel.permissions.screenRecording,
            inputMonitoring: appModel.permissions.inputMonitoring
        )
    }

    private func permissionTone(_ state: PermissionState) -> CapabilityBadge.Tone {
        state == .granted ? .active : .warning
    }
}

private struct OverviewMiddleClickCard: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        let status = PermissionStatusPolicy.threeFingerTapStatus(
            settings: appModel.activeProfile.middleClick,
            accessibility: appModel.permissions.accessibility,
            safeModeEnabled: appModel.store.config.safeModeEnabled,
            runtimeRunning: appModel.multitouchMiddleClick.isRunning
        )
        OverviewFeatureCard(
            title: "Three-Finger Tap",
            benefit: "Tap with three fingers to act like middle click.",
            systemImage: "hand.tap",
            status: status.title,
            tone: CapabilityBadge.Tone(featureStatusKind: status.kind),
            detailRows: [
                OverviewDetailRowData(title: "Links", value: "Open in new tabs", tone: .neutral),
                OverviewDetailRowData(title: "Tabs", value: "Close with middle click", tone: .neutral),
                OverviewDetailRowData(title: "Input Monitoring", value: PermissionStatusPolicy.inputMonitoringSummary(appModel.permissions.inputMonitoring).title, tone: CapabilityBadge.Tone(featureStatusKind: PermissionStatusPolicy.inputMonitoringSummary(appModel.permissions.inputMonitoring).kind))
            ],
            actionLabel: "Input settings",
            action: { appModel.selectedSection = .input }
        )
    }
}

private struct OverviewWindowSwitcherCard: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        OverviewFeatureCard(
            title: "Window Switcher",
            benefit: "Option+Tab shows your open windows.",
            systemImage: "rectangle.3.group",
            status: statusTitle,
            tone: tone,
            detailRows: [
                OverviewDetailRowData(title: "Shortcut", value: appModel.activeProfile.windowSwitcher.shortcut, tone: .neutral),
                OverviewDetailRowData(title: "Windows", value: discoveredWindowCount, tone: .neutral),
                OverviewDetailRowData(title: "Layout", value: appModel.activeProfile.windowSwitcher.layout.title, tone: .neutral)
            ],
            actionLabel: "Dock & Windows",
            action: { appModel.selectedSection = .dockWindows }
        )
    }

    private var statusTitle: String {
        status.title
    }

    private var tone: CapabilityBadge.Tone {
        CapabilityBadge.Tone(featureStatusKind: status.kind)
    }

    private var status: FeatureStatusSummary {
        PermissionStatusPolicy.windowSwitcherStatus(
            settings: appModel.activeProfile.windowSwitcher,
            featureEnabled: appModel.store.config.featureToggles.windowSwitcher,
            accessibility: appModel.permissions.accessibility,
            safeModeEnabled: appModel.store.config.safeModeEnabled
        )
    }

    private var discoveredWindowCount: String {
        guard appModel.windowSwitcher.hasRunWindowDiscovery else {
            return "Check when opened"
        }
        let total = appModel.windowSwitcher.lastDiscoveryReport.totalWindows
        return total == 1 ? "1 window" : "\(total) windows"
    }
}

private struct OverviewDockPreviewsCard: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        OverviewFeatureCard(
            title: "Dock Previews",
            benefit: "Hover Dock icons to preview windows.",
            systemImage: "dock.rectangle",
            status: statusTitle,
            tone: tone,
            detailRows: [
                OverviewDetailRowData(title: "Previews", value: appModel.activeProfile.dockPreviews.enabled ? "Enabled" : "Off", tone: appModel.activeProfile.dockPreviews.enabled ? .active : .neutral),
                OverviewDetailRowData(title: "Animation", value: appModel.activeProfile.dockPreviews.animationStyle.title, tone: .neutral),
                OverviewDetailRowData(title: "Linger", value: "\(appModel.activeProfile.dockPreviews.previewIdleTimeout.sliderValueLabel)s", tone: .neutral)
            ],
            actionLabel: "Dock & Windows",
            action: { appModel.selectedSection = .dockWindows }
        )
    }

    private var statusTitle: String {
        status.title
    }

    private var tone: CapabilityBadge.Tone {
        CapabilityBadge.Tone(featureStatusKind: status.kind)
    }

    private var status: FeatureStatusSummary {
        PermissionStatusPolicy.dockPreviewStatus(
            settings: appModel.activeProfile.dockPreviews,
            accessibility: appModel.permissions.accessibility,
            safeModeEnabled: appModel.store.config.safeModeEnabled,
            runtimeRunning: appModel.dockHover.isRunning
        )
    }
}

private struct OverviewFeatureCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovered = false

    var title: String
    var benefit: String
    var systemImage: String
    var status: String
    var tone: CapabilityBadge.Tone
    var detailRows: [OverviewDetailRowData]
    var actionLabel: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(iconColor)
                        .frame(width: 34, height: 34)
                        .background(iconColor.opacity(0.13), in: Circle())

                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)

                    Spacer(minLength: 8)

                    CapabilityBadge(title: status, systemImage: statusSymbol, tone: tone)
                }
                .frame(height: 36)

                Text(benefit)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)

                VStack(spacing: 7) {
                    ForEach(normalizedRows) { row in
                        OverviewDetailRow(row: row)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
                .frame(height: 62, alignment: .top)

                Spacer(minLength: 0)

                HStack(spacing: 4) {
                    Spacer(minLength: 0)
                    Text(actionLabel)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.tint)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 214, maxHeight: 214, alignment: .topLeading)
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
        .liquidGlass(.card, radius: 14)
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(iconColor.opacity(isHovered ? 0.34 : 0.12), lineWidth: 1)
        }
        .shadow(color: .black.opacity(reduceMotion ? 0.08 : (isHovered ? 0.16 : 0.09)), radius: reduceMotion ? 10 : (isHovered ? 18 : 10), y: reduceMotion ? 4 : (isHovered ? 8 : 4))
        .scaleEffect(reduceMotion ? 1 : (isHovered ? 1.015 : 1))
        .offset(y: reduceMotion ? 0 : (isHovered ? -1 : 0))
        .animation(.easeInOut(duration: 0.16), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
        .accessibilityLabel("\(title). \(status). \(benefit) \(actionLabel).")
        .help(actionLabel)
    }

    private var normalizedRows: [OverviewDetailRowData] {
        let rows = Array(detailRows.prefix(3))
        if rows.count >= 3 { return rows }
        return rows + (rows.count..<3).map { index in
            OverviewDetailRowData(title: " ", value: " ", tone: .neutral, idSuffix: "placeholder-\(index)")
        }
    }

    private var iconColor: Color {
        switch tone {
        case .active:
            .green
        case .warning:
            .orange
        case .neutral:
            .blue
        }
    }

    private var statusSymbol: String {
        switch tone {
        case .active:
            "checkmark.circle.fill"
        case .warning:
            "exclamationmark.circle"
        case .neutral:
            "pause.circle"
        }
    }
}

private struct OverviewDetailRowData: Identifiable {
    var title: String
    var value: String
    var tone: CapabilityBadge.Tone
    var idSuffix: String?

    var id: String { idSuffix ?? title }

    init(title: String, value: String, tone: CapabilityBadge.Tone, idSuffix: String? = nil) {
        self.title = title
        self.value = value
        self.tone = tone
        self.idSuffix = idSuffix
    }
}

private struct OverviewDetailRow: View {
    var row: OverviewDetailRowData

    var body: some View {
        HStack(spacing: 8) {
            Text(row.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            Text(row.value)
                .font(.caption.weight(.medium))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
    }

    private var valueColor: Color {
        switch row.tone {
        case .active:
            .green
        case .warning:
            .orange
        case .neutral:
            .secondary
        }
    }
}
