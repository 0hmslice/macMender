import AppKit
@preconcurrency import CoreGraphics
import Foundation
import MacMenderMenuBarEngine

/// macMender's Ice-derived menu-bar manager facade.
///
/// This type intentionally stays thin: discovery, delimiter controls, movement,
/// app-menu occlusion, event monitoring, and secondary-bar UI live in focused
/// `MenuBarManagement` types. The public name is preserved so the rest of the
/// app does not need to know about the implementation rewrite.
@MainActor
final class MenuBarScannerService: NSObject, ObservableObject {
    @Published private(set) var detectedItems: [DetectedMenuBarItem] = []
    @Published private(set) var lastScanDescription = "Not scanned yet"
    @Published private(set) var overflowVisible = false
    @Published private(set) var controlsInstalled = false
    @Published private(set) var hasConcealableItems = false
    @Published private(set) var shelfEnabled = false
    @Published private(set) var visibleControlItem: DetectedMenuBarItem?
    @Published private(set) var spacingStatusDescription = "Default spacing"
    @Published private(set) var isApplyingSpacing = false
    @Published private(set) var engineSnapshot = MenuBarEngineSnapshot()
    @Published private(set) var engineStatus = MenuBarEngineStatus()

    var onRequestSectionChange: ((DetectedMenuBarItem, MenuBarSection) -> Void)?

    private let discovery = MenuBarItemDiscovery()
    private let mover = MenuBarItemMover()
    private let controlItems = MenuBarControlItemController()
    private let interactions = MenuBarInteractionController()
    private let applicationMenus = MenuBarApplicationMenuController()
    private let secondaryBar = MenuBarSecondaryBarController()
    private let spacingApplier = MenuBarItemSpacingApplier()
    private let operationGate = MenuBarRuntimeOperationGate()

    private var autoRehideTask: Task<Void, Never>?
    private var lastRefresh: Date?
    private var cache = MenuBarItemCache()
    private var layout = MenuBarLayout.default
    private var mouseButtonIsDown = false
    private var isReconcilingSections = false
    private var isRestoringStoredSections = false
    private var hasScheduledStartupRestore = false

    override init() {
        super.init()
        controlItems.delegate = self
        interactions.delegate = self
        secondaryBar.delegate = self
    }

    var overflowActionTitle: String {
        guard hasConcealableItems else { return "Choose an Icon to Hide" }
        return overflowVisible ? "Hide Selected Icons" : "Reveal Hidden Icons"
    }

    var overflowStatusDescription: String {
        guard controlsInstalled else { return shelfEnabled ? "Ready to hide icons" : "Paused" }
        return overflowVisible ? "Hidden icons revealed" : "Hidden icons tucked away"
    }

    func configureControls(enabled: Bool, hasConcealableItems: Bool, layout: MenuBarLayout) {
        shelfEnabled = enabled
        self.hasConcealableItems = hasConcealableItems
        self.layout = layout
        spacingStatusDescription = layout.itemSpacingOffset == 0 ? "Default spacing" : "Spacing offset \(layout.itemSpacingOffset)"

        guard enabled else {
            self.hasConcealableItems = false
            removeRuntime()
            return
        }

        controlItems.installIfNeeded(layout: layout)
        controlItems.update(layout: layout, isExpanded: overflowVisible)
        controlsInstalled = controlItems.controlsInstalled
        interactions.start()
        if hasConcealableItems {
            hideOverflow()
            scheduleStartupRestoreIfNeeded()
        } else {
            revealInMainMenuBar()
        }
        refresh(force: true)
    }

    func toggleOverflow() {
        overflowVisible ? hideOverflow() : showOverflow()
    }

    func showOverflow() {
        if layout.showHiddenItemsInSecondaryBar {
            showSecondaryBar()
        } else {
            revealInMainMenuBar()
        }
    }

    func revealInMainMenuBar() {
        controlItems.installIfNeeded(layout: layout)
        controlsInstalled = controlItems.controlsInstalled
        autoRehideTask?.cancel()
        autoRehideTask = nil
        secondaryBar.hide()
        controlItems.showHiddenSection(
            showAlwaysHiddenDivider: layout.showSectionDividers,
            hasAlwaysHiddenItems: currentCache().alwaysHidden.isEmpty == false
        )
        overflowVisible = true
        refresh(force: true)
        applicationMenus.hideIfNeeded(visibleItems: discovery.items(onScreenOnly: true).filter { !$0.isInternalControlItem }, enabled: layout.hideApplicationMenusOnOverlap)
    }

    func revealAlwaysHiddenInMainMenuBar() {
        controlItems.installIfNeeded(layout: layout)
        controlsInstalled = controlItems.controlsInstalled
        autoRehideTask?.cancel()
        autoRehideTask = nil
        secondaryBar.hide()
        controlItems.showAlwaysHiddenSection()
        overflowVisible = true
        refresh(force: true)
        applicationMenus.hideIfNeeded(visibleItems: discovery.items(onScreenOnly: true).filter { !$0.isInternalControlItem }, enabled: layout.hideApplicationMenusOnOverlap)
    }

    func hideOverflow() {
        guard controlsInstalled else { return }
        secondaryBar.hide()
        if hasConcealableItems {
            controlItems.hideHiddenSection(
                hasHiddenItems: hasDesiredHiddenItems,
                hasAlwaysHiddenItems: hasDesiredAlwaysHiddenItems
            )
            overflowVisible = false
        } else {
            controlItems.hideHiddenSection(hasHiddenItems: false, hasAlwaysHiddenItems: false)
            overflowVisible = true
        }
        autoRehideTask?.cancel()
        autoRehideTask = nil
        applicationMenus.restoreIfNeeded()
        refresh(force: true)
    }

    private func scheduleStartupRestoreIfNeeded() {
        guard !hasScheduledStartupRestore else { return }
        hasScheduledStartupRestore = true

        operationGate.enqueue { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(750))
            await self.restoreStoredConcealedSections()
            if self.hasConcealableItems {
                self.hideOverflow()
            }
        }
    }

    private func alignEmptyLayoutBoundaryIfNeeded() {
        guard !hasDesiredHiddenItems, !hasDesiredAlwaysHiddenItems else { return }
        operationGate.enqueue { [weak self] in
            guard let self else { return }
            try? await Task.sleep(for: .milliseconds(120))
            var items = self.menuBarItemsIncludingControls(onScreenOnly: false)
            guard let hiddenControl = items.first(where: { $0.title == MenuBarControlIdentifier.hidden }) else { return }
            let userItems = items
                .filter { !$0.isInternalControlItem && $0.isMovable && $0.canBeHidden }
                .sorted { $0.frame.minX < $1.frame.minX }
            guard let leftmostUserItem = userItems.first else { return }
            if hiddenControl.frame.maxX <= leftmostUserItem.frame.minX + 1 {
                return
            }

            do {
                try await self.mover.move(item: hiddenControl, to: .leftOfItem(leftmostUserItem))
                try? await Task.sleep(for: .milliseconds(120))
                items = self.menuBarItemsIncludingControls(onScreenOnly: false)
                if let hiddenControl = items.first(where: { $0.title == MenuBarControlIdentifier.hidden }),
                   let alwaysHiddenControl = items.first(where: { $0.title == MenuBarControlIdentifier.alwaysHidden }),
                   alwaysHiddenControl.frame.maxX > hiddenControl.frame.minX + 1 {
                    try? await self.mover.move(item: alwaysHiddenControl, to: .leftOfItem(hiddenControl))
                }
            } catch {
                self.lastScanDescription = "Could not align menu bar dividers"
            }
            self.refresh(force: true)
        }
    }

    func refresh(force: Bool = false) {
        if !force,
           let lastRefresh,
           Date().timeIntervalSince(lastRefresh) < 1.25 {
            return
        }
        lastRefresh = Date()

        let allItems = menuBarItemsIncludingControls(onScreenOnly: false)
        visibleControlItem = allItems
            .first { $0.title == MenuBarControlIdentifier.visible }
            .map { $0.detectedItem(actualSection: .pinned) }
        cache = MenuBarSectionResolver.cache(from: allItems)
        let detected = MenuBarSectionResolver.detectedItems(from: allItems, cache: cache)
        detectedItems = detected
        engineSnapshot = MenuBarEngineSnapshot(items: detected.map(\.engineItem))
        engineStatus = MenuBarEngineStatus(
            isRunning: shelfEnabled,
            isRevealed: overflowVisible,
            description: detected.isEmpty ? "No menu bar items detected" : "Tracking \(detected.count) live menu-bar items",
            lastError: nil
        )
        lastScanDescription = detected.isEmpty ? "No menu bar items detected" : "Detected \(detected.count) menu bar items"

        if layout.showHiddenItemsInSecondaryBar, overflowVisible {
            updateSecondaryBar()
        } else if !layout.showHiddenItemsInSecondaryBar {
            secondaryBar.hide()
        }
        // Stored section repair is intentionally not run on every scan. A
        // scan can happen after harmless settings changes or menu-bar host
        // reflows, and applying persisted layout there makes the whole bar
        // reshuffle without a user gesture. Startup restore and explicit
        // section moves are the only normal paths that move physical items.
    }

    func setDetectedItemsForTesting(_ items: [DetectedMenuBarItem]) {
        detectedItems = items
    }

    func move(_ item: DetectedMenuBarItem, to section: MenuBarSection) {
        move(item, to: section, before: nil)
    }

    func move(_ item: DetectedMenuBarItem, to section: MenuBarSection, before target: DetectedMenuBarItem?) {
        guard item.isHideCandidate else { return }
        controlItems.installIfNeeded(layout: layout)
        controlsInstalled = controlItems.controlsInstalled

        operationGate.enqueue { [weak self] in
            guard let self else { return }
            await self.waitForMouseButtonRelease()
            if item.actualSection == .hidden, section != .hidden {
                self.revealAlwaysHiddenInMainMenuBar()
            } else {
                self.revealInMainMenuBar()
            }
            try? await Task.sleep(for: .milliseconds(160))
            await self.moveItem(withKey: item.sectionKey, to: section, beforeKey: target?.sectionKey)
            if self.hasConcealableItems {
                self.hideOverflow()
            } else {
                self.revealInMainMenuBar()
            }
        }
    }

    func moveVisibleControl(before target: DetectedMenuBarItem?) {
        controlItems.installIfNeeded(layout: layout)
        controlsInstalled = controlItems.controlsInstalled

        operationGate.enqueue { [weak self] in
            guard let self else { return }
            await self.waitForMouseButtonRelease()
            try? await Task.sleep(for: .milliseconds(120))
            await self.moveVisibleControlItem(beforeKey: target?.sectionKey)
            self.refresh(force: true)
        }
    }

    func reconcileDesiredSections(_ desiredSections: [String: MenuBarSection]) {
        // Intentionally not called during normal runtime startup. Applying a
        // stored model to the physical menu bar can reorder icons without an
        // explicit user gesture, which feels random when macOS has already
        // changed host layout. Keep this method for controlled repair flows only.
        guard controlsInstalled, !isReconcilingSections else { return }
        isReconcilingSections = true
        operationGate.enqueue { [weak self] in
            guard let self else { return }
            defer { self.isReconcilingSections = false }

            self.revealInMainMenuBar()
            var items = self.menuBarItemsIncludingControls(onScreenOnly: false)
            var actualSections = MenuBarSectionResolver.actualSectionMap(from: MenuBarSectionResolver.cache(from: items))

            for item in items where !item.isInternalControlItem && item.isMovable && item.canBeHidden {
                let desired = desiredSections[item.identity.description] ?? .pinned
                let actual = actualSections[item.identity.description] ?? .pinned
                guard desired != actual else { continue }
                await self.moveItem(withKey: item.identity.description, to: desired, beforeKey: nil)
                items = self.menuBarItemsIncludingControls(onScreenOnly: false)
                actualSections = MenuBarSectionResolver.actualSectionMap(from: MenuBarSectionResolver.cache(from: items))
            }

            if self.hasConcealableItems {
                self.hideOverflow()
            }
        }
    }

    func applySpacingOffset(_ offset: Int) {
        guard !isApplyingSpacing else { return }
        isApplyingSpacing = true
        spacingStatusDescription = "Applying spacing..."

        Task { [weak self] in
            let result = await self?.spacingApplier.apply(offset: offset).description ?? "Spacing update failed"
            await MainActor.run {
                self?.isApplyingSpacing = false
                self?.spacingStatusDescription = result
                self?.refresh(force: true)
            }
        }
    }

    private func removeRuntime() {
        controlItems.remove()
        controlsInstalled = false
        overflowVisible = false
        interactions.stop()
        secondaryBar.hide()
        operationGate.cancelAll()
        autoRehideTask?.cancel()
        autoRehideTask = nil
        applicationMenus.restoreIfNeeded()
        refresh(force: true)
    }

    private func showSecondaryBar() {
        controlItems.installIfNeeded(layout: layout)
        controlsInstalled = controlItems.controlsInstalled
        autoRehideTask?.cancel()
        autoRehideTask = nil
        controlItems.hideHiddenSection(
            hasHiddenItems: hasDesiredHiddenItems,
            hasAlwaysHiddenItems: hasDesiredAlwaysHiddenItems
        )
        overflowVisible = true
        refresh(force: true)
        updateSecondaryBar()
        scheduleAutoRehideIfNeeded()
    }

    private func updateSecondaryBar() {
        let hiddenItems = detectedItems.filter { item in
            item.isHideCandidate && item.actualSection == .overflow
        }
        secondaryBar.show(items: hiddenItems, anchorScreen: screenContainingMouse())
    }

    private func currentCache() -> MenuBarItemCache {
        MenuBarSectionResolver.cache(from: menuBarItemsIncludingControls(onScreenOnly: false))
    }

    private var hasDesiredHiddenItems: Bool {
        layout.items.contains { $0.section == .overflow }
    }

    private var hasDesiredAlwaysHiddenItems: Bool {
        layout.items.contains { $0.section == .hidden }
    }

    private func moveItem(withKey key: String, to section: MenuBarSection, beforeKey: String?) async {
        refresh(force: true)
        var items = menuBarItemsIncludingControls(onScreenOnly: false)
        guard let item = items.first(where: { $0.identity.description == key }),
              item.isMovable else {
            refresh(force: true)
            return
        }
        do {
            let target = beforeKey.flatMap { key in
                items.first { $0.identity.description == key }
            }
            guard let destination = mover.destination(for: section, before: target, in: items) else {
                refresh(force: true)
                return
            }
            try await mover.move(item: item, to: destination)
        } catch {
            items = menuBarItemsIncludingControls(onScreenOnly: false)
            let target = beforeKey.flatMap { key in
                items.first { $0.identity.description == key }
            }
            if let destination = mover.destination(for: section, before: target, in: items) {
                try? await mover.move(item: item, to: destination)
            }
        }
        try? await Task.sleep(for: .milliseconds(120))
        refresh(force: true)
    }

    private func moveVisibleControlItem(beforeKey: String?) async {
        var items = menuBarItemsIncludingControls(onScreenOnly: false)
        guard let item = items.first(where: { $0.title == MenuBarControlIdentifier.visible }) else {
            return
        }

        let target = beforeKey.flatMap { key in
            items.first { $0.identity.description == key && !$0.isInternalControlItem }
        }
        let destination: MenuBarMoveDestination?
        if let target {
            destination = .leftOfItem(target)
        } else {
            let visibleItems = MenuBarSectionResolver
                .cache(from: items)
                .visible
                .filter { !$0.isInternalControlItem && $0.identity != item.identity }
                .sorted { $0.frame.minX < $1.frame.minX }
            if let lastVisibleItem = visibleItems.last {
                destination = .rightOfItem(lastVisibleItem)
            } else if let hiddenControl = items.first(where: { $0.title == MenuBarControlIdentifier.hidden }) {
                destination = .rightOfItem(hiddenControl)
            } else {
                destination = nil
            }
        }

        guard let destination else { return }
        do {
            try await mover.move(item: item, to: destination)
        } catch {
            items = menuBarItemsIncludingControls(onScreenOnly: false)
            if let target = beforeKey.flatMap({ key in items.first { $0.identity.description == key && !$0.isInternalControlItem } }) {
                try? await mover.move(item: item, to: .leftOfItem(target))
            }
        }
        try? await Task.sleep(for: .milliseconds(120))
    }

    private func restoreStoredConcealedSections() async {
        guard !isRestoringStoredSections else { return }
        isRestoringStoredSections = true
        defer { isRestoringStoredSections = false }

        refresh(force: true)
        var items = menuBarItemsIncludingControls(onScreenOnly: false)
        var actualSections = MenuBarSectionResolver.actualSectionMap(from: MenuBarSectionResolver.cache(from: items))

        for item in items where item.isMovable && item.canBeHidden {
            let desired = layout.section(for: item.identity.description)
            guard desired != .pinned else { continue }
            let actual = actualSections[item.identity.description] ?? .pinned
            guard actual != desired else { continue }

            await moveItem(withKey: item.identity.description, to: desired, beforeKey: nil)
            items = menuBarItemsIncludingControls(onScreenOnly: false)
            actualSections = MenuBarSectionResolver.actualSectionMap(from: MenuBarSectionResolver.cache(from: items))
        }
    }

    private func scheduleStoredConcealmentRestoreIfNeeded(allItems: [MenuBarPhysicalItem]) {
        guard shelfEnabled, hasConcealableItems, controlsInstalled, !overflowVisible, !isRestoringStoredSections else { return }
        let actualSections = MenuBarSectionResolver.actualSectionMap(from: MenuBarSectionResolver.cache(from: allItems))
        let needsRestore = allItems.contains { item in
            guard !item.isInternalControlItem, item.isMovable, item.canBeHidden else { return false }
            let desired = layout.section(for: item.identity.description)
            guard desired != .pinned else { return false }
            let actual = actualSections[item.identity.description] ?? .pinned
            return actual != desired
        }
        guard needsRestore else { return }

        operationGate.enqueue { [weak self] in
            guard let self else { return }
            await self.restoreStoredConcealedSections()
            if self.hasConcealableItems {
                self.hideOverflow()
            }
        }
    }

    private func menuBarItemsIncludingControls(onScreenOnly: Bool) -> [MenuBarPhysicalItem] {
        var items = discovery.items(onScreenOnly: onScreenOnly)
        let controls = controlItems.physicalItems()
        guard !controls.isEmpty else { return items }
        let controlWindowIDs = Set(controls.map(\.windowID))
        items.removeAll {
            controlWindowIDs.contains($0.windowID) ||
                ($0.isInternalControlItem && $0.title != MenuBarControlIdentifier.visible) ||
                $0.title.hasPrefix("\(MenuBarControlIdentifier.hidden).Spacer.")
        }
        items.append(contentsOf: controls)
        return items
    }

    private func waitForMouseButtonRelease() async {
        for _ in 0..<80 {
            if !mouseButtonIsDown {
                try? await Task.sleep(for: .milliseconds(80))
                return
            }
            try? await Task.sleep(for: .milliseconds(25))
        }
    }

    private func scheduleAutoRehideIfNeeded() {
        guard autoRehideTask == nil else { return }
        guard layout.autoRehideEnabled, hasConcealableItems else { return }
        let delay = MenuBarRehidePolicy.clampedDelay(layout.autoRehideDelay)
        autoRehideTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(Int(delay * 1000)))
            guard !Task.isCancelled else { return }
            self?.hideOverflow()
        }
    }

    private func updateHoverRevealState() {
        guard shelfEnabled, hasConcealableItems, controlsInstalled, layout.revealOnHover else { return }
        let mouseInsideMenuBar = isMouseInsideMenuBar()
        let mouseInsideSecondaryBar = isMouseInsideSecondaryBar()

        guard mouseInsideMenuBar || mouseInsideSecondaryBar else {
            if overflowVisible {
                scheduleAutoRehideIfNeeded()
            }
            return
        }

        if isMouseOverRevealTrigger() {
            if !overflowVisible {
                showOverflow()
            }
            autoRehideTask?.cancel()
            autoRehideTask = nil
        } else if mouseInsideSecondaryBar {
            autoRehideTask?.cancel()
            autoRehideTask = nil
        } else if overflowVisible, mouseInsideMenuBar {
            scheduleAutoRehideIfNeeded()
        } else if overflowVisible, !mouseInsideMenuBar, !mouseInsideSecondaryBar {
            scheduleAutoRehideIfNeeded()
        }
    }

    private func handleRevealClick(_ event: NSEvent) {
        guard shelfEnabled, hasConcealableItems, controlsInstalled, layout.revealOnEmptyMenuBarClick else { return }
        if event.type == .rightMouseDown, isMouseInsideEmptyRevealZone() {
            return
        }
        if overflowVisible, isMouseInsideMenuBar(), !isMouseInsideRevealZone(), !isMouseInsideSecondaryBar() {
            scheduleAutoRehideIfNeeded()
            return
        }
        guard isMouseInsideEmptyRevealZone() else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.toggleOverflow()
        }
    }

    private func handleRevealScroll(_ event: NSEvent) {
        guard shelfEnabled, hasConcealableItems, controlsInstalled, layout.revealOnScroll, isMouseInsideRevealZone() else { return }
        let averageDelta = (event.scrollingDeltaX + event.scrollingDeltaY) / 2
        if averageDelta > 5 {
            showOverflow()
        } else if averageDelta < -5 {
            hideOverflow()
        }
    }

    private func isMouseOverRevealTrigger() -> Bool {
        isMouseInsideRevealZone()
    }

    private func isMouseInsideRevealZone() -> Bool {
        guard let mouseLocation = CGEvent(source: nil)?.location,
              let frame = itemFrame(forControlNamed: MenuBarControlIdentifier.visible) else {
            return false
        }
        return frame.insetBy(dx: -52, dy: -8).contains(mouseLocation)
    }

    private func isMouseInsideEmptyRevealZone() -> Bool {
        guard isMouseInsideRevealZone(),
              isMouseInsideEmptyMenuBarSpace() else {
            return false
        }
        return true
    }

    private func isMouseInsideMenuBar() -> Bool {
        guard let mouseLocation = CGEvent(source: nil)?.location else { return false }
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
            let height = screen.frame.height - screen.visibleFrame.height
            return mouseLocation.y >= screen.frame.minY && mouseLocation.y <= screen.frame.minY + max(24, height + 4)
        }
        return mouseLocation.y >= 0 && mouseLocation.y <= menuBarHeight + 4
    }

    private func isMouseInsideSecondaryBar() -> Bool {
        guard let mouseLocation = CGEvent(source: nil)?.location else { return false }
        return secondaryBar.containsMouseLocation(mouseLocation)
    }

    private func isMouseInsideEmptyMenuBarSpace() -> Bool {
        guard isMouseInsideMenuBar(),
              let mouseLocation = CGEvent(source: nil)?.location else {
            return false
        }
        if applicationMenus.isMouseInsideApplicationMenu(mouseLocation) {
            return false
        }
        let onScreenItems = discovery.items(onScreenOnly: true).filter { !$0.isInternalControlItem }
        return !onScreenItems.contains { $0.frame.insetBy(dx: -2, dy: -4).contains(mouseLocation) }
    }

    private var menuBarHeight: CGFloat {
        NSScreen.screens.map { $0.frame.height - $0.visibleFrame.height }.max() ?? 40
    }

    private func itemFrame(forControlNamed name: String) -> CGRect? {
        discovery.items(onScreenOnly: false)
            .first { $0.title == name }
            .flatMap { MenuBarPrivateBridge.frame(for: $0.windowID) ?? $0.frame }
    }

    private func screenContainingMouse() -> NSScreen? {
        guard let mouseLocation = CGEvent(source: nil)?.location else { return NSScreen.main }
        return NSScreen.screens.first { $0.frame.contains(mouseLocation) } ?? NSScreen.main
    }

}

enum MenuBarRehidePolicy {
    static func clampedDelay(_ value: Double) -> Double {
        max(0.4, min(8, value))
    }
}

extension MenuBarScannerService: MenuBarControlItemControllerDelegate {
    func menuBarControlItemControllerDidToggleHiddenSection(_ controller: MenuBarControlItemController) {
        toggleOverflow()
    }

    func menuBarControlItemControllerDidToggleAlwaysHiddenSection(_ controller: MenuBarControlItemController) {
        revealAlwaysHiddenInMainMenuBar()
    }
}

extension MenuBarScannerService: MenuBarInteractionControllerDelegate {
    func menuBarInteractionControllerDidMovePointer(_ controller: MenuBarInteractionController) {
        mover.noteMouseMoved()
        updateHoverRevealState()
    }

    func menuBarInteractionControllerDidPressMouse(_ controller: MenuBarInteractionController, event: NSEvent) {
        mouseButtonIsDown = true
        handleRevealClick(event)
    }

    func menuBarInteractionControllerDidReleaseMouse(_ controller: MenuBarInteractionController, event: NSEvent) {
        mouseButtonIsDown = false
    }

    func menuBarInteractionControllerDidScroll(_ controller: MenuBarInteractionController, event: NSEvent) {
        handleRevealScroll(event)
    }

    func menuBarInteractionControllerDidTick(_ controller: MenuBarInteractionController) {
        updateHoverRevealState()
    }
}

extension MenuBarScannerService: MenuBarSecondaryBarControllerDelegate {
    func menuBarSecondaryBarControllerDidRequestRevealInMenuBar(_ controller: MenuBarSecondaryBarController) {
        revealInMainMenuBar()
    }

    func menuBarSecondaryBarController(_ controller: MenuBarSecondaryBarController, didRequestSection section: MenuBarSection, for item: DetectedMenuBarItem) {
        if let onRequestSectionChange {
            onRequestSectionChange(item, section)
        } else {
            move(item, to: section)
        }
    }
}

extension MenuBarScannerService: MenuBarEngineProtocol {
    var snapshot: MenuBarEngineSnapshot {
        let engineItems = detectedItems.map { item in
            let section = engineSection(for: item)
            return MenuBarEngineItem(
                id: item.sectionKey,
                displayName: item.displayTitle,
                sourceBundleIdentifier: item.sourceBundleIdentifier,
                sourceProcessIdentifier: item.sourceProcessIdentifier,
                windowID: item.windowID,
                frame: item.frame,
                section: section,
                canHide: item.canBeHiddenBySystem && item.isHideCandidate,
                canMove: item.isMovableBySystem && item.isHideCandidate
            )
        }

        return MenuBarEngineSnapshot(items: engineItems)
    }

    var status: MenuBarEngineStatus {
        MenuBarEngineStatus(
            isRunning: shelfEnabled,
            isRevealed: overflowVisible,
            description: "\(overflowStatusDescription) (Thaw Port, \(MenuBarEngineMovementPolicy.description))"
        )
    }

    func start(configuration: MenuBarEngineConfiguration) {
        let layout = MenuBarLayout(
            items: layout.items,
            itemSpacingOffset: configuration.itemSpacing,
            showSectionDividers: configuration.showSectionDividers,
            autoRehideEnabled: configuration.autoRehideEnabled,
            autoRehideDelay: configuration.autoRehideDelay,
            revealOnHover: configuration.revealOnHover,
            revealOnEmptyMenuBarClick: configuration.revealOnEmptyMenuBarClick,
            revealOnScroll: configuration.revealOnScroll,
            hideApplicationMenusOnOverlap: configuration.hideApplicationMenusOnOverlap,
            showHiddenItemsInSecondaryBar: configuration.useSecondaryBar
        )
        configureControls(enabled: true, hasConcealableItems: hasConcealableItems, layout: layout)
    }

    func stop() {
        configureControls(enabled: false, hasConcealableItems: false, layout: layout)
    }

    func refresh() async {
        refresh(force: true)
    }

    func setSection(itemID: MenuBarEngineItemID, section: MenuBarEngineSection) async throws {
        guard let item = detectedItems.first(where: { $0.sectionKey == itemID }) else { return }
        move(item, to: MenuBarSection(engineSection: section), before: nil)
    }

    func move(itemID: MenuBarEngineItemID, to destination: MenuBarEngineMoveDestination) async throws {
        guard let item = detectedItems.first(where: { $0.sectionKey == itemID }) else { return }
        switch destination {
        case .section(let section):
            move(item, to: MenuBarSection(engineSection: section), before: nil)
        case .beforeItem(let targetID, let section):
            let target = detectedItems.first { $0.sectionKey == targetID }
            move(item, to: MenuBarSection(engineSection: section), before: target)
        case .afterItem(_, let section):
            move(item, to: MenuBarSection(engineSection: section), before: nil)
        }
    }

    func revealHidden(trigger _: MenuBarRevealTrigger) async {
        showOverflow()
    }

    func revealAlwaysHidden() async {
        revealAlwaysHiddenInMainMenuBar()
    }

    func hideRevealed() async {
        hideOverflow()
    }

    func applySpacing(_ value: Int) async throws {
        applySpacingOffset(value)
    }

    private func engineSection(for item: DetectedMenuBarItem) -> MenuBarEngineSection {
        guard item.isHideCandidate else { return .visible }
        return MenuBarEngineSection(menuBarSection: item.actualSection)
    }
}

private extension MenuBarEngineSection {
    init(menuBarSection: MenuBarSection) {
        switch menuBarSection {
        case .pinned:
            self = .visible
        case .overflow:
            self = .hidden
        case .hidden:
            self = .alwaysHidden
        }
    }
}

private extension MenuBarSection {
    init(engineSection: MenuBarEngineSection) {
        switch engineSection {
        case .visible:
            self = .pinned
        case .hidden:
            self = .overflow
        case .alwaysHidden:
            self = .hidden
        }
    }
}
