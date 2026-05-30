import AppKit
import Combine
import Foundation
import MacMenderMenuBarEngine

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
    private var hasStartedRuntime = false

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
        self.menuBarScanner.onRequestSectionChange = { [weak self] item, section in
            self?.setMenuBarSection(item, section: section)
        }
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
            return .error
        }

        switch selectedSection {
        case .overview:
            return .success
        case .input:
            return .scanning
        case .menuBar:
            return .thinking
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

    var menuBarMendyMood: MendyMood {
        if !store.config.hasCompletedOnboarding || store.config.safeModeEnabled || permissions.needsAttention {
            return .error
        }
        if dockHover.lastHoveredApp != nil || windowSwitcher.isShowing {
            return .scanning
        }
        return .success
    }

    var hasMenuBarOverflowItems: Bool {
        !hiddenMenuBarSelections.isEmpty
    }

    private var hasConfiguredMenuBarOverflowItems: Bool {
        let visibleSystemManagedKeys = Set(menuBarScanner.detectedItems.filter(\.isSystemManaged).map(\.sectionKey))
        return store.config.menuBarLayout.items.contains {
            $0.section != .pinned && !visibleSystemManagedKeys.contains($0.bundleIdentifier)
        }
    }

    var hiddenMenuBarSelections: [MenuBarItemModel] {
        let visibleSystemManagedKeys = Set(menuBarScanner.detectedItems.filter(\.isSystemManaged).map(\.sectionKey))
        let physicallyVisibleKeys = Set(menuBarScanner.detectedItems.filter { item in
            item.isHideCandidate && item.actualSection == .pinned
        }.map(\.sectionKey))
        return store.config.menuBarLayout.items.filter {
            $0.section != .pinned &&
                !visibleSystemManagedKeys.contains($0.bundleIdentifier) &&
                !physicallyVisibleKeys.contains($0.bundleIdentifier)
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
        rememberDetectedMenuBarItems()
        updateRuntime()
    }

    func startRuntimeIfNeeded() {
        guard !hasStartedRuntime else {
            refreshPassiveState()
            return
        }
        hasStartedRuntime = true
        refreshSystemState(force: true)
    }

    func refreshPassiveState() {
        permissions.refresh()
        dock.refresh()
        loginItems.refresh()
        menuBarScanner.refresh(force: false)
        rememberDetectedMenuBarItems()
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
        store.updateActiveProfile(profile)
        updateRuntime()
    }

    func setMenuBarSection(_ item: DetectedMenuBarItem, section: MenuBarSection) {
        moveMenuBarItem(item, to: section, before: nil)
    }

    func moveMenuBarItem(_ item: DetectedMenuBarItem, to section: MenuBarSection, before target: DetectedMenuBarItem?) {
        guard item.isHideCandidate else { return }
        store.setMenuBarSection(itemKey: item.sectionKey, title: item.displayTitle, section: section, before: target?.sectionKey)
        let physicalTarget = target ?? nextDetectedMenuBarItem(after: item.sectionKey, in: section)
        let menuBarShelfEnabled = store.config.featureToggles.menuBarManagement && !store.config.safeModeEnabled && store.config.hasCompletedOnboarding
        guard menuBarShelfEnabled else { return }
        menuBarScanner.configureControls(
            enabled: menuBarShelfEnabled,
            hasConcealableItems: hasConfiguredMenuBarOverflowItems,
            layout: store.config.menuBarLayout
        )
        menuBarScanner.move(item, to: section, before: physicalTarget)
    }

    func moveMendyStatusItem(before target: DetectedMenuBarItem?) {
        let menuBarShelfEnabled = store.config.featureToggles.menuBarManagement && !store.config.safeModeEnabled && store.config.hasCompletedOnboarding
        guard menuBarShelfEnabled else { return }
        menuBarScanner.configureControls(
            enabled: menuBarShelfEnabled,
            hasConcealableItems: hasConfiguredMenuBarOverflowItems,
            layout: store.config.menuBarLayout
        )
        menuBarScanner.moveVisibleControl(before: target)
    }

    func menuBarSection(for item: DetectedMenuBarItem) -> MenuBarSection {
        MenuBarLayoutSectionSource.displayedSection(for: item)
    }

    func isMenuBarItemHidden(_ item: DetectedMenuBarItem) -> Bool {
        MenuBarLayoutSectionSource.isHiddenInLiveLayout(item)
    }

    func setMenuBarItemHidden(_ item: DetectedMenuBarItem, hidden: Bool) {
        guard item.isHideCandidate else { return }
        setMenuBarSection(item, section: hidden ? .overflow : .pinned)
    }

    func setStoredMenuBarItemVisible(_ item: MenuBarItemModel) {
        store.setMenuBarSection(itemKey: item.bundleIdentifier, title: item.title, section: .pinned, before: nil)
        updateRuntime()
    }

    func updateMenuBarLayout(_ update: (inout MenuBarLayout) -> Void) {
        update(&store.config.menuBarLayout)
        store.save()
        menuBarScanner.configureControls(
            enabled: store.config.featureToggles.menuBarManagement && !store.config.safeModeEnabled && store.config.hasCompletedOnboarding,
            hasConcealableItems: hasConfiguredMenuBarOverflowItems,
            layout: store.config.menuBarLayout
        )
    }

    func resetMenuBarLayout() {
        let visibleCandidates = menuBarScanner.detectedItems.filter { item in
            item.isHideCandidate && menuBarSection(for: item) != .pinned
        }
        for item in visibleCandidates {
            moveMenuBarItem(item, to: .pinned, before: nil)
        }
        store.config.menuBarLayout.items.removeAll()
        store.save()
        menuBarScanner.configureControls(
            enabled: store.config.featureToggles.menuBarManagement && !store.config.safeModeEnabled && store.config.hasCompletedOnboarding,
            hasConcealableItems: false,
            layout: store.config.menuBarLayout
        )
    }

    func applyMenuBarSpacing() {
        menuBarScanner.applySpacingOffset(store.config.menuBarLayout.itemSpacingOffset)
    }

    func scanMenuBarItems() {
        menuBarScanner.refresh(force: true)
        rememberDetectedMenuBarItems()
        updateRuntime()
    }

    func syncMenuBarLayoutLive() {
        if permissions.screenRecording != .granted {
            permissions.refresh()
        }
        menuBarScanner.refresh(force: true)
        rememberDetectedMenuBarItems()
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
            hasConcealableItems: hasConfiguredMenuBarOverflowItems,
            layout: store.config.menuBarLayout
        )

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

    private func rememberDetectedMenuBarItems() {
        store.rememberMenuBarItems(
            menuBarScanner.detectedItems,
            resolvesVisibleConflicts: false
        )
    }

    private func nextDetectedMenuBarItem(after itemKey: String, in section: MenuBarSection) -> DetectedMenuBarItem? {
        let layoutItems = store.config.menuBarLayout.items
        guard let currentIndex = layoutItems.firstIndex(where: { $0.bundleIdentifier == itemKey }) else {
            return nil
        }
        let followingKeys = layoutItems[layoutItems.index(after: currentIndex)...]
            .filter { $0.section == section }
            .map(\.bundleIdentifier)
        for key in followingKeys {
            if let item = menuBarScanner.detectedItems.first(where: { $0.sectionKey == key }) {
                return item
            }
        }
        return nil
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
