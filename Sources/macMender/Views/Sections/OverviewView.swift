import SwiftUI

struct OverviewView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        PreferencesScrollView {
            OverviewHero(appModel: appModel)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 14)], spacing: 14) {
                SoftStatusCard(
                    title: "Permissions",
                    subtitle: appModel.permissions.needsAttention ? "Needs review" : "Access looks good",
                    systemImage: "lock.shield",
                    tone: appModel.permissions.needsAttention ? .warning : .active
                ) {
                    VStack(alignment: .leading, spacing: 6) {
                        OverviewStatusLine(
                            title: "Accessibility",
                            status: appModel.permissions.accessibility.title,
                            tone: appModel.permissions.accessibility == .granted ? .active : .warning
                        )
                        OverviewStatusLine(
                            title: "Screen Recording",
                            status: appModel.permissions.screenRecording.title,
                            tone: appModel.permissions.screenRecording == .granted ? .active : .warning
                        )
                    }
                }
                OverviewStatusCard(
                    title: "Window Switcher",
                    subtitle: appModel.activeProfile.windowSwitcher.shortcut,
                    symbol: "rectangle.3.group",
                    status: windowSwitcherStatus,
                    tone: windowSwitcherIsReady ? .active : .warning
                )
                OverviewStatusCard(
                    title: "Dock Previews",
                    subtitle: "Hover to preview",
                    symbol: "dock.rectangle",
                    status: appModel.dockHover.isRunning ? "Active" : "Paused",
                    tone: appModel.dockHover.isRunning ? .active : .warning
                )
            }

            OverviewRefreshCard(appModel: appModel)

            SectionCard(title: "Services", subtitle: "Technical details stay here when you need them.", symbolName: "dot.radiowaves.left.and.right") {
                DisclosureGroup("Service details") {
                    VStack(alignment: .leading, spacing: 10) {
                        RuntimeRow(title: "Input monitoring", detail: appModel.systemEvents.status.eventTapRunning ? "Ready for shortcuts and input adjustments" : "Waiting for permission or setup", running: appModel.systemEvents.status.eventTapRunning)
                        RuntimeRow(
                            title: "Dock previews",
                            detail: appModel.dockHover.isRunning ? (appModel.dockHover.lastHoveredApp ?? "Watching Dock item hover") : "Paused until Accessibility is granted",
                            running: appModel.dockHover.isRunning
                        )
                    }
                    .padding(.top, 8)
                }
                .font(.callout)
            }
        }
    }

    private var windowSwitcherIsReady: Bool {
        appModel.store.config.featureToggles.windowSwitcher &&
        !appModel.store.config.safeModeEnabled &&
        appModel.permissions.accessibility == .granted
    }

    private var windowSwitcherStatus: String {
        if !appModel.store.config.featureToggles.windowSwitcher { return "Off" }
        if appModel.store.config.safeModeEnabled { return "Paused" }
        if appModel.permissions.accessibility != .granted { return "Needs access" }
        return "Ready"
    }

}

private struct OverviewHero: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        HStack(spacing: 26) {
            MendyAvatarView(mood: heroMood, size: MendyAvatarSize.prominent)

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

    private var heroMood: MendyMood {
        if appModel.permissions.needsAttention { return .thinking }
        if appModel.store.config.safeModeEnabled { return .idle }
        return .success
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

private struct OverviewRefreshCard: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        SectionCard(
            title: "Status Refresh",
            subtitle: "Updates the health summary without scanning windows or capturing thumbnails.",
            symbolName: "arrow.clockwise"
        ) {
            HStack(spacing: 14) {
                if appModel.isRefreshingOverview {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(appModel.isRefreshingOverview ? "Updating status..." : lastUpdatedTitle)
                        .font(.callout.weight(.semibold))
                    Text(appModel.lastOverviewRefreshSummary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Button {
                    appModel.refreshOverviewStatus()
                } label: {
                    Label(appModel.isRefreshingOverview ? "Refreshing" : "Refresh Status", systemImage: "arrow.clockwise")
                }
                .disabled(appModel.isRefreshingOverview)
            }
        }
    }

    private var lastUpdatedTitle: String {
        guard let last = appModel.lastOverviewRefresh else {
            return "Not refreshed yet"
        }
        if Date().timeIntervalSince(last) < 60 {
            return "Updated just now"
        }
        return "Updated at \(last.formatted(date: .omitted, time: .shortened))"
    }
}

private struct OverviewStatusCard: View {
    var title: String
    var subtitle: String
    var symbol: String
    var status: String
    var tone: CapabilityBadge.Tone

    var body: some View {
        SoftStatusCard(title: title, subtitle: subtitle, systemImage: symbol, tone: tone) {
            Label(status, systemImage: tone == .active ? "checkmark.circle.fill" : "exclamationmark.circle")
                .font(.caption.weight(.semibold))
                .foregroundStyle(tone == .active ? .green : .orange)
        }
    }
}

private struct OverviewStatusLine: View {
    var title: String
    var status: String
    var tone: CapabilityBadge.Tone

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: tone == .active ? "checkmark.circle.fill" : "exclamationmark.circle")
                .foregroundStyle(tone == .active ? .green : .orange)
            Text(title)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            Text(status)
                .foregroundStyle(tone == .active ? .green : .orange)
        }
        .font(.caption.weight(.semibold))
    }
}

private struct RuntimeRow: View {
    var title: String
    var detail: String
    var running: Bool

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Label(title, systemImage: running ? "checkmark.circle.fill" : "pause.circle")
                .font(.callout.weight(.medium))
                .foregroundStyle(running ? .green : .orange)
            Spacer()
            Text(detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .liquidGlass(.row)
    }
}
