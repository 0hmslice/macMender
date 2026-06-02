import AppKit
import SwiftUI

struct OverviewView: View {
    @ObservedObject var appModel: AppModel

    var body: some View {
        PreferencesScrollView {
            OverviewHero(appModel: appModel)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 14) {
                OverviewStatusCard(
                    title: "Accessibility",
                    subtitle: "System access",
                    symbol: "display",
                    status: appModel.permissions.accessibility.title,
                    tone: appModel.permissions.accessibility == .granted ? .active : .warning
                )
                OverviewStatusCard(
                    title: "Screen Recording",
                    subtitle: "Window thumbnails",
                    symbol: "record.circle",
                    status: appModel.permissions.screenRecording.title,
                    tone: appModel.permissions.screenRecording == .granted ? .active : .warning
                )
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

            HStack(alignment: .top, spacing: 14) {
                SectionCard(title: "Quick Actions", subtitle: "Common tasks.", symbolName: "bolt") {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                        FriendlyActionTile(
                            title: "Refresh windows",
                            subtitle: "Find open windows now",
                            systemImage: "arrow.clockwise"
                        ) {
                            appModel.windowSwitcher.refreshDiscovery(settings: appModel.activeProfile.windowSwitcher)
                        }
                        FriendlyActionTile(
                            title: "Test preview",
                            subtitle: "See your animation",
                            systemImage: "sparkles"
                        ) {
                            showPreviewAnimationSample()
                        }
                        FriendlyActionTile(
                            title: "Open permissions",
                            subtitle: "Review system access",
                            systemImage: "shield"
                        ) {
                            appModel.selectedSection = .privacy
                        }
                    }
                }

                SectionCard(title: "Mendy is here to help", subtitle: "Need guidance? Mendy keeps the setup honest.", symbolName: "sparkles") {
                    HStack(alignment: .bottom, spacing: 12) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your Mac is set up with the features this profile manages.")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            Button("Check status") {
                                appModel.refreshSystemState(force: true)
                            }
                        }
                        Spacer(minLength: 0)
                        MendyAvatarView(mood: appModel.mendyMood, size: MendyAvatarSize.panel)
                    }
                }
                .frame(width: 360)
            }

            SectionCard(title: "Services", subtitle: "Technical details stay here when you need them.", symbolName: "dot.radiowaves.left.and.right") {
                DisclosureGroup("Service details") {
                    VStack(alignment: .leading, spacing: 10) {
                        RuntimeRow(title: "Input monitoring", detail: appModel.systemEvents.status.eventTapRunning ? "Ready for shortcuts and input adjustments" : "Waiting for permission or setup", running: appModel.systemEvents.status.eventTapRunning)
                        RuntimeRow(
                            title: "Dock previews",
                            detail: appModel.dockHover.isRunning ? (appModel.dockHover.lastHoveredApp ?? "Watching Dock item hover") : "Paused until Accessibility is granted",
                            running: appModel.dockHover.isRunning
                        )
                        RuntimeRow(
                            title: "Menu bar discovery",
                            detail: menuBarRuntimeDetail,
                            running: !appModel.menuBarScanner.detectedItems.isEmpty
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

    private var menuBarRuntimeDetail: String {
        guard appModel.menuBarScanner.shelfEnabled else { return "Paused" }
        if appModel.hiddenMenuBarItemCount == 0 { return "Manual setup guide active" }
        return appModel.menuBarScanner.overflowStatusDescription
    }

    private func showPreviewAnimationSample() {
        let screenFrame = NSApp.keyWindow?.screen?.visibleFrame ?? NSScreen.main?.visibleFrame ?? .zero
        let anchor = CGRect(x: screenFrame.midX - 30, y: screenFrame.minY + 8, width: 60, height: 60)
        appModel.windowSwitcher.showDockPreviewAnimationSample(
            settings: appModel.activeProfile.dockPreviews.overlaySettings(using: appModel.activeProfile.windowSwitcher),
            anchorFrame: anchor
        )
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
                    CapabilityBadge(title: menuBarChipTitle, systemImage: "menubar.rectangle", tone: appModel.menuBarScanner.detectedItems.isEmpty ? .neutral : .active)
                }
            }

            Spacer(minLength: 0)

            Button("Refresh Status") {
                appModel.refreshSystemState(force: true)
            }
            .buttonStyle(.borderedProminent)
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

    private var menuBarChipTitle: String {
        appModel.menuBarScanner.detectedItems.isEmpty ? "Menu bar guide ready" : "Menu bar monitored"
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
