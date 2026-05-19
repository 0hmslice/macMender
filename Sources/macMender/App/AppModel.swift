import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    @Published var selectedSection: SettingsSection = .overview

    let store: ProfileStore
    let permissions: PermissionService
    let dock: DockPreferencesService
    let loginItems: LoginItemService
    let diagnostics: DiagnosticsService
    let systemEvents: SystemEventService
    let windowSwitcher: WindowSwitcherService
    let menuBarScanner: MenuBarScannerService
    let dockHover: DockHoverService
    let multitouchMiddleClick: MultitouchMiddleClickService

    private var cancellables = Set<AnyCancellable>()
    private var lastFullRefresh: Date?

    init(
        store: ProfileStore = ProfileStore(),
        permissions: PermissionService = PermissionService(),
        dock: DockPreferencesService = DockPreferencesService(),
        loginItems: LoginItemService = LoginItemService(),
        diagnostics: DiagnosticsService = DiagnosticsService(),
        systemEvents: SystemEventService = SystemEventService(),
        windowSwitcher: WindowSwitcherService = WindowSwitcherService(),
        menuBarScanner: MenuBarScannerService = MenuBarScannerService(),
        dockHover: DockHoverService = DockHoverService(),
        multitouchMiddleClick: MultitouchMiddleClickService = MultitouchMiddleClickService()
    ) {
        self.store = store
        self.permissions = permissions
        self.dock = dock
        self.loginItems = loginItems
        self.diagnostics = diagnostics
        self.systemEvents = systemEvents
        self.windowSwitcher = windowSwitcher
        self.menuBarScanner = menuBarScanner
        self.dockHover = dockHover
        self.multitouchMiddleClick = multitouchMiddleClick
        bindChildChanges()
        wireRuntimeHandlers()
    }

    var activeProfile: MacMenderProfile {
        store.activeProfile
    }

    var menuBarSymbol: String {
        if store.config.safeModeEnabled { return "wrench.and.screwdriver.fill" }
        if permissions.needsAttention { return "wrench.and.screwdriver" }
        return "wrench.and.screwdriver"
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
            return .alert
        }

        switch selectedSection {
        case .overview:
            return .success
        case .input:
            return .fixing
        case .menuBar:
            return .profileChange
        case .dockWindows:
            return .fixing
        case .profiles:
            return .profileChange
        case .privacy:
            return permissions.needsAttention ? .alert : .success
        case .advanced:
            return .idle
        }
    }

    var menuBarMendyMood: MendyMood {
        if !store.config.hasCompletedOnboarding || store.config.safeModeEnabled || permissions.needsAttention {
            return .alert
        }
        if dockHover.lastHoveredApp != nil || windowSwitcher.isShowing {
            return .fixing
        }
        return .success
    }

    var hasMenuBarOverflowItems: Bool {
        !hiddenMenuBarSelections.isEmpty
    }

    var hiddenMenuBarSelections: [MenuBarItemModel] {
        let visibleSystemManagedKeys = Set(menuBarScanner.detectedItems.filter(\.isSystemManaged).map(\.sectionKey))
        return store.config.menuBarLayout.items.filter {
            $0.section != .pinned && !visibleSystemManagedKeys.contains($0.bundleIdentifier)
        }
    }

    var hiddenMenuBarItemCount: Int {
        hiddenMenuBarSelections.count
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
        menuBarScanner.refresh(force: force)
        updateRuntime()
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
        store.updateActiveProfile(profile)
        updateRuntime()
    }

    func setMenuBarSection(_ item: DetectedMenuBarItem, section: MenuBarSection) {
        guard item.isHideCandidate else { return }
        store.setMenuBarSection(itemKey: item.sectionKey, title: item.displayTitle, section: section)
        let menuBarShelfEnabled = store.config.featureToggles.menuBarManagement && !store.config.safeModeEnabled && store.config.hasCompletedOnboarding
        guard menuBarShelfEnabled else { return }
        menuBarScanner.configureControls(
            enabled: menuBarShelfEnabled,
            hasConcealableItems: hasMenuBarOverflowItems,
            layout: store.config.menuBarLayout
        )
        menuBarScanner.showOverflow()
        menuBarScanner.move(item, to: section)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
            guard let self else { return }
            if section == .pinned {
                self.menuBarScanner.configureControls(
                    enabled: menuBarShelfEnabled,
                    hasConcealableItems: self.hasMenuBarOverflowItems,
                    layout: self.store.config.menuBarLayout
                )
            } else {
                self.menuBarScanner.hideOverflow()
            }
        }
    }

    func menuBarSection(for item: DetectedMenuBarItem) -> MenuBarSection {
        guard item.isHideCandidate else { return .pinned }
        return store.config.menuBarLayout.section(for: item.sectionKey)
    }

    func isMenuBarItemHidden(_ item: DetectedMenuBarItem) -> Bool {
        guard item.isHideCandidate else { return false }
        return store.config.menuBarLayout.section(for: item.sectionKey) != .pinned
    }

    func setMenuBarItemHidden(_ item: DetectedMenuBarItem, hidden: Bool) {
        guard item.isHideCandidate else { return }
        setMenuBarSection(item, section: hidden ? .overflow : .pinned)
    }

    func setStoredMenuBarItemVisible(_ item: MenuBarItemModel) {
        store.setMenuBarSection(itemKey: item.bundleIdentifier, title: item.title, section: .pinned)
        updateRuntime()
    }

    func updateMenuBarLayout(_ update: (inout MenuBarLayout) -> Void) {
        update(&store.config.menuBarLayout)
        store.save()
        menuBarScanner.configureControls(
            enabled: store.config.featureToggles.menuBarManagement && !store.config.safeModeEnabled && store.config.hasCompletedOnboarding,
            hasConcealableItems: hasMenuBarOverflowItems,
            layout: store.config.menuBarLayout
        )
    }

    func applyMenuBarSpacing() {
        menuBarScanner.applySpacingOffset(store.config.menuBarLayout.itemSpacingOffset)
    }

    func activateApp() {
        if !store.config.appBehavior.hideDockIcon {
            NSApp.setActivationPolicy(.regular)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @discardableResult
    func focusPreferencesWindow() -> Bool {
        activateApp()
        if let window = NSApp.windows.first(where: { $0.title == "macMender" || $0.identifier?.rawValue.contains("preferences") == true }) {
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

        dockHover.hoverDelay = activeProfile.dockPreviews.hoverDelay
        if permissions.accessibility == .granted,
           !runtimePaused,
           store.config.featureToggles.windowSwitcher,
           activeProfile.dockPreviews.enabled {
            dockHover.start()
        } else {
            dockHover.stop()
        }

        menuBarScanner.configureControls(
            enabled: store.config.featureToggles.menuBarManagement && !runtimePaused,
            hasConcealableItems: hasMenuBarOverflowItems,
            layout: store.config.menuBarLayout
        )
        if store.config.featureToggles.menuBarManagement && !runtimePaused {
            let desiredSections = Dictionary(uniqueKeysWithValues: store.config.menuBarLayout.items.map { ($0.bundleIdentifier, $0.section) })
            menuBarScanner.reconcileDesiredSections(desiredSections)
        }

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
        NSApp.setActivationPolicy(shouldHideDockIcon ? .accessory : .regular)
    }

    private func bindChildChanges() {
        [
            store.objectWillChange.eraseToAnyPublisher(),
            permissions.objectWillChange.eraseToAnyPublisher(),
            dock.objectWillChange.eraseToAnyPublisher(),
            loginItems.objectWillChange.eraseToAnyPublisher(),
            diagnostics.objectWillChange.eraseToAnyPublisher(),
            systemEvents.objectWillChange.eraseToAnyPublisher(),
            windowSwitcher.objectWillChange.eraseToAnyPublisher(),
            menuBarScanner.objectWillChange.eraseToAnyPublisher(),
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
        dockHover.onHoverApp = { [weak self] appName, frame in
            guard let self else { return }
            self.windowSwitcher.showDockPreview(
                appName: appName,
                settings: self.activeProfile.dockPreviews.overlaySettings(using: self.activeProfile.windowSwitcher),
                anchorFrame: frame
            )
        }
        dockHover.onExitDock = { [weak self] in
            self?.windowSwitcher.scheduleDockPreviewDismiss()
        }
    }
}
