import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedSection: SettingsSection = .overview
    @Published private(set) var isRefreshingStatus = false
    @Published private(set) var lastStatusRefresh: Date?
    @Published private(set) var lastStatusRefreshSummary = "Not refreshed yet"
    @Published private(set) var firstWindowReadyAt: Date?
    @Published private(set) var runtimeStartedAt: Date?

    let store: ProfileStore
    let permissions: PermissionService
    let dock: DockPreferencesService
    let loginItems: LoginItemService
    let menuBarSpacing: MenuBarSpacingService
    let diagnostics: DiagnosticsService
    let systemEvents: SystemEventService
    let windowSwitcher: WindowSwitcherService
    let dockHover: DockHoverService
    let multitouchMiddleClick: MultitouchMiddleClickService

    private var cancellables = Set<AnyCancellable>()
    private var lastFullRefresh: Date?
    private var hasStartedRuntime = false
    private let modelCreatedAt = Date()

    init(
        store: ProfileStore = ProfileStore(),
        permissions: PermissionService = PermissionService(),
        dock: DockPreferencesService = DockPreferencesService(),
        loginItems: LoginItemService = LoginItemService(),
        menuBarSpacing: MenuBarSpacingService = MenuBarSpacingService(),
        diagnostics: DiagnosticsService = DiagnosticsService(),
        systemEvents: SystemEventService = SystemEventService(),
        windowSwitcher: WindowSwitcherService = WindowSwitcherService(),
        dockHover: DockHoverService = DockHoverService(),
        multitouchMiddleClick: MultitouchMiddleClickService = MultitouchMiddleClickService()
    ) {
        self.store = store
        self.permissions = permissions
        self.dock = dock
        self.loginItems = loginItems
        self.menuBarSpacing = menuBarSpacing
        self.diagnostics = diagnostics
        self.systemEvents = systemEvents
        self.windowSwitcher = windowSwitcher
        self.dockHover = dockHover
        self.multitouchMiddleClick = multitouchMiddleClick
        bindChildChanges()
        wireRuntimeHandlers()
    }

    var activeProfile: MacMenderProfile {
        store.activeProfile
    }

    var runningStatusTitle: String {
        if !store.config.hasCompletedOnboarding { return "Setup Required" }
        if store.config.safeModeEnabled { return "Paused" }
        if permissions.accessibility != .granted { return "Needs Accessibility" }
        if !systemEvents.status.eventTapRunning { return "Starting" }
        return "Running"
    }

    var runningStatusDetail: String {
        if !store.config.hasCompletedOnboarding {
            return "Open Settings to finish onboarding"
        }
        if store.config.safeModeEnabled {
            return "Safe Mode is on"
        }
        if permissions.accessibility != .granted {
            return "Open Settings to finish setup"
        }
        return systemEvents.status.lastEventDescription
    }

    var runningStatusSymbol: String {
        if !store.config.hasCompletedOnboarding { return "arrow.right.circle.fill" }
        if store.config.safeModeEnabled { return "pause.circle.fill" }
        if permissions.accessibility != .granted { return "exclamationmark.triangle.fill" }
        return "checkmark.circle.fill"
    }

    var mendyMood: MendyMood {
        if store.config.safeModeEnabled || permissions.accessibility != .granted {
            return .error
        }

        switch selectedSection {
        case .overview:
            return .success
        case .general:
            return .idle
        case .menuBarSpacing:
            return .thinking
        case .input:
            return .scanning
        case .dockWindows:
            return .scanning
        case .profiles:
            return .thinking
        case .privacy:
            return permissions.needsAttention ? .error : .success
        case .advanced:
            return .idle
        }
    }

    var statusItemMendyMood: MendyMood {
        if !store.config.hasCompletedOnboarding || store.config.safeModeEnabled || permissions.needsAttention {
            return .error
        }
        if dockHover.lastHoveredApp != nil || windowSwitcher.isShowing {
            return .scanning
        }
        return .success
    }

    func refreshSystemState(force: Bool = false) {
        if !force,
           let lastFullRefresh,
           Date().timeIntervalSince(lastFullRefresh) < 1.5 {
            updateRuntime()
            return
        }
        lastFullRefresh = Date()
        permissions.refresh()
        dock.refresh()
        loginItems.refresh()
        updateRuntime()
    }

    func refreshStatus() {
        guard !isRefreshingStatus else { return }
        isRefreshingStatus = true
        lastStatusRefreshSummary = "Updating status..."

        Task { @MainActor [weak self] in
            guard let self else { return }
            self.permissions.refresh()
            self.dock.refresh()
            self.loginItems.refresh()
            self.updateRuntime()
            self.lastStatusRefresh = Date()
            self.lastStatusRefreshSummary = self.statusRefreshSummary()
            try? await Task.sleep(for: .milliseconds(300))
            self.isRefreshingStatus = false
        }
    }

    func startRuntimeIfNeeded() {
        guard !hasStartedRuntime else {
            refreshPassiveState()
            return
        }
        hasStartedRuntime = true
        runtimeStartedAt = Date()
        refreshSystemState(force: true)
    }

    func refreshPassiveState() {
        permissions.refresh()
        dock.refresh()
        loginItems.refresh()
    }

    func markFirstWindowReady() {
        if firstWindowReadyAt == nil {
            firstWindowReadyAt = Date()
        }
    }

    func toggleSafeMode() {
        store.config.safeModeEnabled.toggle()
        store.save()
        updateRuntime()
    }

    func setHideDockIcon(_ isHidden: Bool) {
        store.config.appBehavior.hideDockIcon = isHidden
        store.save()
        applyActivationPolicy()
        if isHidden {
            keepPreferencesWindowFrontIfVisible()
        }
    }

    func applyMenuBarSpacing(_ preference: MenuBarSpacingPreference) {
        store.config.appBehavior.menuBarSpacing = preference
        store.save()
        menuBarSpacing.apply(preference, customValue: store.config.appBehavior.menuBarSpacingCustomValue)
    }

    func applyMenuBarSpacing(_ preference: MenuBarSpacingPreference, customValue: Int) {
        store.config.appBehavior.menuBarSpacing = preference
        store.config.appBehavior.menuBarSpacingCustomValue = MenuBarSpacingPreference.clampedValue(customValue)
        store.save()
        menuBarSpacing.apply(preference, customValue: store.config.appBehavior.menuBarSpacingCustomValue)
    }

    func refreshMenuBarSpacingStatus() {
        menuBarSpacing.refreshCurrentValues()
    }

    func setActiveProfile(_ profileID: UUID) {
        store.setActiveProfile(profileID)
        updateRuntime()
    }

    func completeOnboarding() {
        store.completeOnboarding()
        selectedSection = .overview
        updateRuntime()
    }

    func resetToOnboarding() {
        store.resetToOnboarding()
        hasStartedRuntime = false
        selectedSection = .overview
        refreshSystemState(force: true)
    }

    func createProfile(named name: String) {
        store.createProfile(named: name)
        updateRuntime()
    }

    func deleteProfile(_ profileID: UUID) {
        store.deleteProfile(profileID)
        updateRuntime()
    }

    func updateActiveProfile(_ profile: MacMenderProfile) {
        let previousProfile = activeProfile
        store.updateActiveProfile(profile)
        let updatedProfile = activeProfile
        guard previousProfile != updatedProfile else { return }
        updateRuntimeAfterProfileChange(from: previousProfile, to: updatedProfile)
    }

    func activateApp() {
        if !store.config.appBehavior.hideDockIcon {
            setActivationPolicyIfNeeded(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @discardableResult
    func focusPreferencesWindow() -> Bool {
        activateApp()
        if let window = NSApp.windows.first(where: { $0.title == "macMender" || $0.identifier?.rawValue.contains("preferences") == true }) {
            window.level = .normal
            window.isReleasedWhenClosed = false
            window.makeKeyAndOrderFront(nil)
            return true
        }
        return false
    }

    func exportConfiguration() {
        let panel = NSSavePanel()
        panel.title = "Export macMender Configuration"
        panel.nameFieldStringValue = "macMender-config.json"
        panel.allowedContentTypes = [.json]

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else { return }
            Task { @MainActor in
                self?.store.export(to: url)
            }
        }
    }

    func updateRuntime() {
        applyActivationPolicy()
        let runtimePaused = store.config.safeModeEnabled || !store.config.hasCompletedOnboarding

        systemEvents.update(
            profile: activeProfile,
            safeModeEnabled: runtimePaused,
            accessibilityGranted: permissions.accessibility == .granted,
            featureToggles: store.config.featureToggles
        )

        applyDockPreviewRuntime(runtimePaused: runtimePaused)

        applyMiddleClickRuntime(runtimePaused: runtimePaused)
    }

    private func updateRuntimeAfterProfileChange(from previousProfile: MacMenderProfile, to currentProfile: MacMenderProfile) {
        let runtimePaused = store.config.safeModeEnabled || !store.config.hasCompletedOnboarding

        if previousProfile.scroll != currentProfile.scroll ||
            previousProfile.windowSwitcher != currentProfile.windowSwitcher ||
            previousProfile.middleClick != currentProfile.middleClick {
            systemEvents.update(
                profile: currentProfile,
                safeModeEnabled: runtimePaused,
                accessibilityGranted: permissions.accessibility == .granted,
                featureToggles: store.config.featureToggles
            )
        }

        if previousProfile.dockPreviews != currentProfile.dockPreviews ||
            previousProfile.windowSwitcher != currentProfile.windowSwitcher {
            applyDockPreviewRuntime(runtimePaused: runtimePaused)
        }

        if previousProfile.middleClick != currentProfile.middleClick {
            applyMiddleClickRuntime(runtimePaused: runtimePaused)
        }
    }

    private func applyDockPreviewRuntime(runtimePaused: Bool) {
        dockHover.hoverDelay = activeProfile.dockPreviews.hoverDelay
        windowSwitcher.updateDockPreviewIdleTimeout(activeProfile.dockPreviews.previewIdleTimeout)
        windowSwitcher.updateDockPreviewAnimation(
            style: activeProfile.dockPreviews.animationStyle,
            duration: activeProfile.dockPreviews.animationDuration
        )

        if permissions.accessibility == .granted,
           !runtimePaused,
           store.config.featureToggles.windowSwitcher,
           activeProfile.dockPreviews.enabled {
            dockHover.start()
        } else {
            dockHover.stop()
        }
    }

    private func applyMiddleClickRuntime(runtimePaused: Bool) {
        if permissions.accessibility == .granted,
           !runtimePaused,
           activeProfile.middleClick.enabled,
           activeProfile.middleClick.trigger == .experimentalThreeFinger {
            multitouchMiddleClick.start()
        } else {
            multitouchMiddleClick.stop()
        }
    }

    private func applyActivationPolicy() {
        let shouldHideDockIcon = store.config.hasCompletedOnboarding && store.config.appBehavior.hideDockIcon
        setActivationPolicyIfNeeded(shouldHideDockIcon ? .accessory : .regular)
    }

    private func setActivationPolicyIfNeeded(_ policy: NSApplication.ActivationPolicy) {
        guard NSApp.activationPolicy() != policy else { return }
        NSApp.setActivationPolicy(policy)
    }

    private func keepPreferencesWindowFrontIfVisible() {
        guard let window = NSApp.windows.first(where: { $0.title == "macMender" || $0.identifier?.rawValue.contains("preferences") == true }),
              window.isVisible else {
            return
        }
        NSApp.activate(ignoringOtherApps: true)
        window.level = .normal
        window.makeKeyAndOrderFront(nil)
    }

    private func bindChildChanges() {
        [
            store.objectWillChange.eraseToAnyPublisher(),
            permissions.objectWillChange.eraseToAnyPublisher(),
            dock.objectWillChange.eraseToAnyPublisher(),
            loginItems.objectWillChange.eraseToAnyPublisher(),
            menuBarSpacing.objectWillChange.eraseToAnyPublisher(),
            diagnostics.objectWillChange.eraseToAnyPublisher(),
            systemEvents.objectWillChange.eraseToAnyPublisher(),
            windowSwitcher.objectWillChange.eraseToAnyPublisher(),
            dockHover.objectWillChange.eraseToAnyPublisher(),
            multitouchMiddleClick.objectWillChange.eraseToAnyPublisher()
        ]
        .forEach { publisher in
            publisher
                .sink { [weak self] _ in
                    Task { @MainActor [weak self] in
                        self?.objectWillChange.send()
                    }
                }
                .store(in: &cancellables)
        }
    }

    private func wireRuntimeHandlers() {
        systemEvents.onShowSwitcher = { [weak self] in
            guard let self else { return }
            self.windowSwitcher.show(settings: self.activeProfile.windowSwitcher)
        }
        systemEvents.onCycleSwitcher = { [weak self] in
            self?.windowSwitcher.cycle()
        }
        systemEvents.onCommitSwitcher = { [weak self] in
            self?.windowSwitcher.commit()
        }
        systemEvents.onCancelSwitcher = { [weak self] in
            self?.windowSwitcher.cancel()
        }
        dockHover.onHoverApp = { [weak self] identity, frame in
            guard let self else { return }
            self.windowSwitcher.showDockPreview(
                identity: identity,
                settings: self.activeProfile.dockPreviews.overlaySettings(using: self.activeProfile.windowSwitcher),
                anchorFrame: frame
            )
        }
        dockHover.onExitDock = { [weak self] in
            self?.windowSwitcher.scheduleDockPreviewDismiss()
        }
    }

    private func statusRefreshSummary() -> String {
        if permissions.needsAttention {
            return "Updated permissions and service status. A permission still needs review."
        }
        if store.config.safeModeEnabled {
            return "Updated permissions and service status. Safe Mode is on."
        }
        return "Updated permissions, login item status, Dock defaults, and active helpers."
    }
}
