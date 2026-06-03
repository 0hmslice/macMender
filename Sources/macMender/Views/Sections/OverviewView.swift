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
                    CapabilityBadge(title: permissionsChipTitle, systemImage: "checkmark.circle.fill", tone: appModel.permissions.needsAttention ? .warning : .active)
                    CapabilityBadge(title: appModel.dockHover.isRunning ? "Dock previews active" : "Dock previews paused", systemImage: "dock.rectangle", tone: appModel.dockHover.isRunning ? .active : .warning)
                    CapabilityBadge(title: windowSwitcherChipTitle, systemImage: "rectangle.3.group", tone: windowSwitcherIsReady ? .active : .warning)
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
            return "A permission needs review before every feature can run."
        }
        if appModel.store.config.safeModeEnabled {
            return "Safe Mode is on, so active system changes are paused."
        }
        return "Your Mac is set up and the main helpers are ready."
    }

    private var permissionsChipTitle: String {
        appModel.permissions.needsAttention ? "Permissions need review" : "Permissions granted"
    }

    private var windowSwitcherIsReady: Bool {
        appModel.store.config.featureToggles.windowSwitcher &&
        !appModel.store.config.safeModeEnabled &&
        appModel.permissions.accessibility == .granted
    }

    private var windowSwitcherChipTitle: String {
        windowSwitcherIsReady ? "Window switcher ready" : "Window switcher paused"
    }
}

private struct OverviewPermissionsCard: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        OverviewFeatureCard(
            title: "Permissions",
            benefit: allGranted ? "macMender has the access it needs." : "Review access so enabled features can run.",
            systemImage: "lock.shield",
            status: allGranted ? "Ready" : "Needs review",
            tone: allGranted ? .active : .warning,
            detailRows: [
                OverviewDetailRowData(title: "Accessibility", value: appModel.permissions.accessibility.title, tone: permissionTone(appModel.permissions.accessibility)),
                OverviewDetailRowData(title: "Screen Recording", value: appModel.permissions.screenRecording.title, tone: permissionTone(appModel.permissions.screenRecording)),
                OverviewDetailRowData(title: "Input Monitoring", value: appModel.permissions.inputMonitoring.title, tone: permissionTone(appModel.permissions.inputMonitoring))
            ],
            actionTitle: allGranted ? nil : "Review permissions",
            action: allGranted ? nil : { appModel.selectedSection = .privacy }
        )
    }

    private var allGranted: Bool {
        appModel.permissions.accessibility == .granted &&
        appModel.permissions.screenRecording == .granted &&
        appModel.permissions.inputMonitoring == .granted
    }

    private func permissionTone(_ state: PermissionState) -> CapabilityBadge.Tone {
        state == .granted ? .active : .warning
    }
}

private struct OverviewMiddleClickCard: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        OverviewFeatureCard(
            title: "Three-Finger Tap",
            benefit: "Tap with three fingers to act like middle click.",
            systemImage: "hand.tap",
            status: statusTitle,
            tone: tone,
            detailRows: [
                OverviewDetailRowData(title: "Links", value: "Open in new tabs", tone: .neutral),
                OverviewDetailRowData(title: "Tabs", value: "Close with middle click", tone: .neutral),
                OverviewDetailRowData(title: "Input Monitoring", value: appModel.permissions.inputMonitoring.title, tone: appModel.permissions.inputMonitoring == .granted ? .active : .warning)
            ],
            actionTitle: "Input settings",
            action: { appModel.selectedSection = .input }
        )
    }

    private var statusTitle: String {
        let settings = appModel.activeProfile.middleClick
        guard settings.enabled, settings.trigger == .experimentalThreeFinger else {
            return "Off"
        }
        guard appModel.permissions.accessibility == .granted else {
            return "Needs permission"
        }
        guard appModel.permissions.inputMonitoring == .granted else {
            return "Needs permission"
        }
        guard !appModel.store.config.safeModeEnabled else {
            return "Paused"
        }
        return appModel.multitouchMiddleClick.isRunning ? "Active" : "Ready"
    }

    private var tone: CapabilityBadge.Tone {
        switch statusTitle {
        case "Active", "Ready":
            .active
        case "Off":
            .neutral
        default:
            .warning
        }
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
            actionTitle: "Dock & Windows",
            action: { appModel.selectedSection = .dockWindows }
        )
    }

    private var statusTitle: String {
        if !appModel.store.config.featureToggles.windowSwitcher ||
            !appModel.activeProfile.windowSwitcher.enabled {
            return "Off"
        }
        if appModel.store.config.safeModeEnabled {
            return "Paused"
        }
        if appModel.permissions.accessibility != .granted {
            return "Needs permission"
        }
        return "Ready"
    }

    private var tone: CapabilityBadge.Tone {
        switch statusTitle {
        case "Ready":
            .active
        case "Off":
            .neutral
        default:
            .warning
        }
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
            actionTitle: "Dock & Windows",
            action: { appModel.selectedSection = .dockWindows }
        )
    }

    private var statusTitle: String {
        guard appModel.activeProfile.dockPreviews.enabled else {
            return "Off"
        }
        if appModel.store.config.safeModeEnabled {
            return "Paused"
        }
        if appModel.permissions.accessibility != .granted {
            return "Needs permission"
        }
        return appModel.dockHover.isRunning ? "Active" : "Ready"
    }

    private var tone: CapabilityBadge.Tone {
        switch statusTitle {
        case "Active", "Ready":
            .active
        case "Off":
            .neutral
        default:
            .warning
        }
    }
}

private struct OverviewFeatureCard: View {
    var title: String
    var benefit: String
    var systemImage: String
    var status: String
    var tone: CapabilityBadge.Tone
    var detailRows: [OverviewDetailRowData]
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .frame(width: 38, height: 38)
                    .background(iconColor.opacity(0.13), in: Circle())

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                    Text(benefit)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            CapabilityBadge(title: status, systemImage: statusSymbol, tone: tone)

            VStack(spacing: 7) {
                ForEach(detailRows.prefix(3)) { row in
                    OverviewDetailRow(row: row)
                }
            }

            if let actionTitle, let action {
                Button(action: action) {
                    HStack(spacing: 4) {
                        Text(actionTitle)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.semibold))
                    }
                    .font(.caption.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .padding(.top, 2)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .topLeading)
        .liquidGlass(.card, radius: 14)
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
    var id: String { title }
    var title: String
    var value: String
    var tone: CapabilityBadge.Tone
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
