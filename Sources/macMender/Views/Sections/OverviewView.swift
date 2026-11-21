import SwiftUI

struct OverviewView: View {
    @ObservedObject var appModel: AppModel

    private var isPaused: Bool { appModel.store.config.safeModeEnabled }

    var body: some View {
        SettingsPage(section: .overview) {
            if appModel.permissions.needsAttention || isPaused {
                Section {
                    if appModel.permissions.needsAttention {
                        SettingsRow(
                            title: "macMender needs Accessibility access",
                            detail: "Previews, window switching, and shortcuts stay off until you allow it.",
                            systemImage: "exclamationmark.triangle.fill",
                            tint: .orange
                        ) {
                            Button("Fix…") { appModel.selectedSection = .privacy }
                        }
                    }
                    if isPaused {
                        SettingsRow(
                            title: "macMender is paused",
                            detail: "Every feature is off until you resume.",
                            systemImage: "pause.fill",
                            tint: .yellow
                        ) {
                            Button("Resume") { appModel.toggleSafeMode() }
                        }
                    }
                }
            }

            Section("Features") {
                featureRow(
                    .dockPreviews,
                    summary: dockPreviewSummary,
                    isOn: Binding(
                        get: { appModel.activeProfile.dockPreviews.enabled },
                        set: { appModel.setDockPreviewsEnabled($0) }
                    )
                )
                featureRow(
                    .windowSwitcher,
                    summary: windowSwitcherSummary,
                    isOn: Binding(
                        get: { appModel.activeProfile.windowSwitcher.enabled },
                        set: { appModel.setWindowSwitcherEnabled($0) }
                    )
                )
                featureRow(
                    .input,
                    title: "Middle Click",
                    summary: middleClickSummary,
                    isOn: appModel.profileBinding(\.middleClick.enabled)
                )
                featureRow(
                    .input,
                    title: "Smooth Scrolling",
                    summary: scrollingSummary,
                    isOn: nil
                )
                featureRow(.keepAwake, summary: keepAwakeSummary, isOn: nil)
                featureRow(.menuBarSpacing, summary: menuBarSummary, isOn: nil)
            }

            Section("Setup") {
                OverviewLinkRow(
                    title: "Permissions",
                    detail: permissionsSummary.detail,
                    systemImage: SettingsSection.privacy.symbolName,
                    tint: SettingsSection.privacy.tint,
                    status: SettingsStatusBadge(
                        title: permissionsSummary.kind == .needsAttention ? "Needs access" : "Ready",
                        tone: MacMenderStatusTone(featureStatusKind: permissionsSummary.kind)
                    )
                ) { appModel.selectedSection = .privacy }

                OverviewLinkRow(
                    title: "Profile",
                    detail: appModel.store.config.profiles.count == 1
                        ? "One profile. Add more to keep different setups."
                        : "\(appModel.store.config.profiles.count) profiles saved.",
                    systemImage: SettingsSection.profiles.symbolName,
                    tint: SettingsSection.profiles.tint,
                    status: Text(appModel.activeProfile.name).foregroundStyle(.secondary)
                ) { appModel.selectedSection = .profiles }
            }
        }
    }

    /// One feature: what it is doing, a switch when it has one, and a way into its page.
    private func featureRow(
        _ section: SettingsSection,
        title: String? = nil,
        summary: FeatureStatusSummary,
        isOn: Binding<Bool>?
    ) -> some View {
        HStack(spacing: 12) {
            Button {
                appModel.selectedSection = section
            } label: {
                HStack(spacing: 12) {
                    SettingsIconTile(systemImage: section.symbolName, tint: section.tint, size: 26)
                    SettingsRowText(title: title ?? section.title, detail: summary.detail)
                    Spacer(minLength: 8)
                    if isOn == nil {
                        SettingsStatusBadge(title: summary.title, tone: MacMenderStatusTone(featureStatusKind: summary.kind))
                    }
                }
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens \(section.title) settings")

            if let isOn {
                Toggle(title ?? section.title, isOn: isOn)
                    .labelsHidden()
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
                .accessibilityHidden(true)
        }
        .padding(.vertical, 2)
    }

    private var permissionsSummary: FeatureStatusSummary {
        PermissionStatusPolicy.permissionsSummary(
            accessibility: appModel.permissions.accessibility,
            screenRecording: appModel.permissions.screenRecording,
            inputMonitoring: .granted
        )
    }

    private var middleClickSummary: FeatureStatusSummary {
        let settings = appModel.activeProfile.middleClick
        guard settings.enabled else {
            return FeatureStatusSummary(title: "Off", detail: "Middle click from a trackpad or two-button mouse.", kind: .off)
        }
        if settings.trigger == .experimentalThreeFinger {
            return PermissionStatusPolicy.threeFingerTapStatus(
                settings: settings,
                accessibility: appModel.permissions.accessibility,
                safeModeEnabled: isPaused,
                runtimeRunning: appModel.multitouchMiddleClick.isRunning
            )
        }
        return FeatureStatusSummary(title: "On", detail: "\(settings.trigger.title) middle-clicks.", kind: isPaused ? .paused : .active)
    }

    private var scrollingSummary: FeatureStatusSummary {
        let scroll = appModel.activeProfile.scroll
        let smoothing = scroll.verticalSmoothingEnabled || scroll.horizontalSmoothingEnabled
        return FeatureStatusSummary(
            title: smoothing ? scroll.preset.title : "Off",
            detail: smoothing ? "Mouse wheel scrolling is smoothed." : "Mouse wheel scrolling is unchanged.",
            kind: smoothing ? (isPaused ? .paused : .active) : .off
        )
    }

    private var keepAwakeSummary: FeatureStatusSummary {
        if let session = appModel.keepAwake.session {
            let until = session.endsAt.map { "Awake until \($0.formatted(date: .omitted, time: .shortened))." } ?? "Awake until you stop it."
            return FeatureStatusSummary(title: "On", detail: until, kind: .active)
        }
        return FeatureStatusSummary(title: "Off", detail: "Your Mac sleeps as usual.", kind: .off)
    }

    private var menuBarSummary: FeatureStatusSummary {
        let preference = appModel.store.config.appBehavior.menuBarSpacing
        return FeatureStatusSummary(
            title: preference.title,
            detail: preference == .systemDefault ? "Menu bar icons use the macOS spacing." : "Menu bar icons use your spacing.",
            kind: preference == .systemDefault ? .off : .active
        )
    }

    private var windowSwitcherSummary: FeatureStatusSummary {
        PermissionStatusPolicy.windowSwitcherStatus(
            settings: appModel.activeProfile.windowSwitcher,
            featureEnabled: appModel.store.config.featureToggles.windowSwitcher,
            accessibility: appModel.permissions.accessibility,
            safeModeEnabled: isPaused
        )
    }

    private var dockPreviewSummary: FeatureStatusSummary {
        PermissionStatusPolicy.dockPreviewStatus(
            settings: appModel.activeProfile.dockPreviews,
            accessibility: appModel.permissions.accessibility,
            safeModeEnabled: isPaused,
            runtimeRunning: appModel.dockHover.isRunning
        )
    }
}

/// A row that opens another page, with a status on the right.
private struct OverviewLinkRow<Status: View>: View {
    var title: String
    var detail: String
    var systemImage: String
    var tint: Color
    var status: Status
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                SettingsIconTile(systemImage: systemImage, tint: tint, size: 26)
                SettingsRowText(title: title, detail: detail)
                Spacer(minLength: 8)
                status
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(.vertical, 2)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}
