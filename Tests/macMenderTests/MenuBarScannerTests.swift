import CoreGraphics
import Foundation
import Testing
@testable import macMender

@Suite("Menu Bar Scanner")
struct MenuBarScannerTests {
    @Test("normalizes raw WindowServer item names")
    func normalizesRawTitles() {
        let numbered = DetectedMenuBarItem(
            id: "1",
            windowID: 1,
            ownerName: "Control Center",
            title: "Item-2",
            processIdentifier: 100,
            frame: .zero
        )
        let bundleLike = DetectedMenuBarItem(
            id: "2",
            windowID: 2,
            ownerName: "Control Center",
            title: "com.openai.sky.CUAService",
            processIdentifier: 100,
            frame: .zero
        )

        #expect(numbered.displayTitle == "Control Center")
        #expect(bundleLike.displayTitle == "CUAService")
    }

    @Test("source-resolved generic Control Center hosts use source app names")
    func sourceResolvedGenericHostsUseSourceNames() {
        let stats = DetectedMenuBarItem(
            id: "stats",
            windowID: 10,
            ownerName: "Stats",
            title: "CombinedModules",
            processIdentifier: 100,
            sourceProcessIdentifier: 101,
            sourceBundleIdentifier: "eu.exelban.Stats",
            frame: .zero,
            isPrivateWindowBacked: true
        )
        let weather = DetectedMenuBarItem(
            id: "weather",
            windowID: 11,
            ownerName: "WeatherMenu",
            title: "Item-0",
            processIdentifier: 100,
            sourceProcessIdentifier: 102,
            sourceBundleIdentifier: "com.apple.weather.menu",
            frame: .zero,
            isPrivateWindowBacked: true
        )
        let controlCenter = DetectedMenuBarItem(
            id: "control-center",
            windowID: 12,
            ownerName: "Control Center",
            title: "CombinedModules",
            processIdentifier: 100,
            sourceProcessIdentifier: 100,
            sourceBundleIdentifier: "com.apple.controlcenter",
            frame: .zero,
            isPrivateWindowBacked: true
        )

        #expect(stats.displayTitle == "Stats")
        #expect(weather.displayTitle == "WeatherMenu")
        #expect(controlCenter.displayTitle == "Control Center Modules")
    }

    @Test("identifies internal macMender divider items")
    func identifiesInternalItems() {
        let overflowDivider = DetectedMenuBarItem(
            id: "3",
            windowID: 3,
            ownerName: "Control Center",
            title: MenuBarControlIdentifier.hidden,
            processIdentifier: 100,
            frame: .zero
        )
        let hiddenDivider = DetectedMenuBarItem(
            id: "4",
            windowID: 4,
            ownerName: "Control Center",
            title: MenuBarControlIdentifier.alwaysHidden,
            processIdentifier: 100,
            frame: .zero
        )
        let visibleControl = DetectedMenuBarItem(
            id: "5",
            windowID: 5,
            ownerName: "Control Center",
            title: MenuBarControlIdentifier.visible,
            processIdentifier: 100,
            frame: .zero
        )

        #expect(overflowDivider.isInternalMacMenderItem)
        #expect(hiddenDivider.isInternalMacMenderItem)
        #expect(visibleControl.isInternalMacMenderItem)
    }

    @Test("uses Ice-style private-backed menu extra controllability")
    func usesPreciseAppleMenuExtraControllability() {
        let wifi = DetectedMenuBarItem(
            id: "system-1",
            windowID: 1,
            ownerName: "Control Center",
            title: "WiFi",
            processIdentifier: 100,
            sourceBundleIdentifier: "com.apple.controlcenter",
            frame: .zero,
            isPrivateWindowBacked: true
        )
        let clock = DetectedMenuBarItem(
            id: "system-2",
            windowID: 2,
            ownerName: "Control Center",
            title: "Clock",
            processIdentifier: 100,
            sourceBundleIdentifier: "com.apple.controlcenter",
            frame: .zero,
            isPrivateWindowBacked: true,
            isMovableBySystem: false
        )
        let recording = DetectedMenuBarItem(
            id: "system-3",
            windowID: 3,
            ownerName: "Control Center",
            title: "AudioVideoModule",
            processIdentifier: 100,
            sourceBundleIdentifier: "com.apple.controlcenter",
            frame: .zero,
            isPrivateWindowBacked: true,
            canBeHiddenBySystem: false
        )
        let combinedModules = DetectedMenuBarItem(
            id: "system-4",
            windowID: 4,
            ownerName: "Control Center",
            title: "CombinedModules",
            processIdentifier: 100,
            sourceBundleIdentifier: "com.apple.controlcenter",
            frame: .zero,
            isPrivateWindowBacked: true
        )
        let thirdParty = DetectedMenuBarItem(
            id: "third-party-1",
            windowID: 5,
            ownerName: "Stats",
            title: "Stats",
            processIdentifier: 101,
            sourceBundleIdentifier: "eu.exelban.Stats",
            frame: .zero,
            isPrivateWindowBacked: true
        )
        let axOnlyThirdParty = DetectedMenuBarItem(
            id: "third-party-ax",
            windowID: 0,
            ownerName: "Stats",
            title: "Stats",
            processIdentifier: 101,
            sourceBundleIdentifier: "eu.exelban.Stats",
            frame: .zero,
            isPrivateWindowBacked: false
        )

        #expect(!wifi.isSystemManaged)
        #expect(wifi.isHideCandidate)
        #expect(clock.isSystemManaged)
        #expect(!clock.isHideCandidate)
        #expect(recording.isSystemManaged)
        #expect(!recording.isHideCandidate)
        #expect(!combinedModules.isSystemManaged)
        #expect(combinedModules.isHideCandidate)
        #expect(!thirdParty.isSystemManaged)
        #expect(thirdParty.isHideCandidate)
        #expect(axOnlyThirdParty.isSystemManaged)
        #expect(!axOnlyThirdParty.isHideCandidate)
    }

    @Test("Control Center menu itself is fixed when reported with BentoBox suffix")
    func controlCenterMenuItselfIsFixedWithSuffix() throws {
        let window = MenuBarWindowInfo(
            windowID: 55,
            frame: CGRect(x: 100, y: 0, width: 28, height: 24),
            title: "BentoBox-0",
            ownerPID: ProcessInfo.processInfo.processIdentifier,
            sourcePID: ProcessInfo.processInfo.processIdentifier,
            ownerName: "Control Center"
        )

        let item = try #require(MenuBarPhysicalItem(window: window))

        #expect(!item.isMovable)
        #expect(!item.detectedItem().isHideCandidate)
    }

    @Test("resolves Ice-style visible hidden and always-hidden sections")
    func resolvesMenuBarSectionsFromDividerFrames() throws {
        let items = [
            try physicalItem(title: MenuBarControlIdentifier.hidden, x: 100),
            try physicalItem(title: MenuBarControlIdentifier.alwaysHidden, x: 70),
            try physicalItem(title: "VisibleTool", x: 120),
            try physicalItem(title: "HiddenTool", x: 85),
            try physicalItem(title: "AlwaysTool", x: 45)
        ]

        let cache = MenuBarSectionResolver.cache(from: items)
        let sections = MenuBarSectionResolver.actualSectionMap(from: cache)

        #expect(sections["<null>:VisibleTool"] == .pinned)
        #expect(sections["<null>:HiddenTool"] == .overflow)
        #expect(sections["<null>:AlwaysTool"] == .hidden)
    }

    @Test("rehide policy clamps delays to Ice-like safe bounds")
    func clampsRehideDelay() {
        #expect(MenuBarRehidePolicy.clampedDelay(0.1) == 0.4)
        #expect(MenuBarRehidePolicy.clampedDelay(2.5) == 2.5)
        #expect(MenuBarRehidePolicy.clampedDelay(12) == 8)
    }

    @Test("collapses duplicate transient windows by identity")
    func collapsesDuplicateTransientWindows() throws {
        let narrow = try physicalItem(title: "DuplicateTool", x: 20, width: 4)
        let wide = try physicalItem(title: "DuplicateTool", x: 40, width: 24)
        let unique = try physicalItem(title: "UniqueTool", x: 80, width: 12)

        let normalized = MenuBarDiscoveryNormalizer.collapseDuplicateTransientWindows(in: [narrow, wide, unique])

        #expect(normalized.count == 2)
        #expect(normalized.contains { $0.identity.description == "<null>:DuplicateTool" && $0.frame.width == 24 })
        #expect(normalized.contains { $0.identity.description == "<null>:UniqueTool" })
    }

    @Test("normalization preserves live menu bar window order")
    func normalizationPreservesLiveMenuBarWindowOrder() throws {
        let rightmost = try physicalItem(title: "Rightmost", x: 180, width: 12)
        let middle = try physicalItem(title: "Middle", x: 120, width: 12)
        let leftmost = try physicalItem(title: "Leftmost", x: 60, width: 12)

        let normalized = MenuBarDiscoveryNormalizer.collapseDuplicateTransientWindows(in: [rightmost, middle, leftmost])

        #expect(normalized.map(\.identity.description) == [
            "<null>:Rightmost",
            "<null>:Middle",
            "<null>:Leftmost"
        ])
    }

    @Test("section resolver preserves live order in detected items")
    func sectionResolverPreservesLiveOrderInDetectedItems() throws {
        let hidden = try physicalItem(title: MenuBarControlIdentifier.hidden, x: 100)
        let first = try physicalItem(title: "First", x: 160)
        let second = try physicalItem(title: "Second", x: 140)
        let third = try physicalItem(title: "Third", x: 120)
        let cache = MenuBarSectionResolver.cache(from: [hidden, first, second, third])

        let detected = MenuBarSectionResolver.detectedItems(from: [hidden, first, second, third], cache: cache)

        #expect(detected.map(\.displayTitle) == ["First", "Second", "Third"])
    }

    @MainActor
    @Test("drop target destinations move before row target when available")
    func dropTargetDestinationMovesBeforeTarget() throws {
        let hidden = try physicalItem(title: MenuBarControlIdentifier.hidden, x: 100)
        let first = try physicalItem(title: "First", x: 120)
        let second = try physicalItem(title: "Second", x: 140)
        let mover = MenuBarItemMover()

        let destination = try #require(mover.destination(for: .pinned, before: second, in: [hidden, first, second]))

        switch destination {
        case .leftOfItem(let target):
            #expect(target.identity.description == "<null>:Second")
        case .rightOfItem:
            Issue.record("Expected drop target to move before the row target")
        }
    }

    @MainActor
    @Test("hidden destination prefers Thaw always-hidden divider right edge")
    func hiddenDestinationUsesAlwaysHiddenDividerRightEdge() throws {
        let alwaysHidden = try physicalItem(title: MenuBarControlIdentifier.alwaysHidden, x: 80)
        let hidden = try physicalItem(title: MenuBarControlIdentifier.hidden, x: 100)
        let mover = MenuBarItemMover()

        let destination = try #require(mover.destination(for: .overflow, in: [alwaysHidden, hidden]))

        switch destination {
        case .rightOfItem(let target):
            #expect(target.identity.description == "<null>:macMender.ControlItem.AlwaysHidden")
        case .leftOfItem:
            Issue.record("Expected Hidden items to land to the right of the Always Hidden divider when available")
        }
    }

    @MainActor
    @Test("hidden destination falls back to hidden divider left edge")
    func hiddenDestinationFallsBackToHiddenDividerLeftEdge() throws {
        let hidden = try physicalItem(title: MenuBarControlIdentifier.hidden, x: 100)
        let mover = MenuBarItemMover()

        let destination = try #require(mover.destination(for: .overflow, in: [hidden]))

        switch destination {
        case .leftOfItem(let target):
            #expect(target.identity.description == "<null>:macMender.ControlItem.Hidden")
        case .rightOfItem:
            Issue.record("Expected Hidden items to fall back to the hidden divider when Always Hidden is unavailable")
        }
    }

    @MainActor
    @Test("visible destination restores before macMender menu-bar trigger")
    func visibleDestinationRestoresBeforeMacMenderTrigger() throws {
        let hidden = try physicalItem(title: MenuBarControlIdentifier.hidden, x: 100)
        let visible = try physicalItem(title: MenuBarControlIdentifier.visible, x: 160)
        let mover = MenuBarItemMover()

        let destination = try #require(mover.destination(for: .pinned, in: [hidden, visible]))

        switch destination {
        case .rightOfItem(let target):
            #expect(target.identity.description == "<null>:macMender.ControlItem.Visible")
        case .leftOfItem:
            Issue.record("Expected Visible restores to use the macMender trigger edge")
        }
    }

    @Test("generic unresolved Control Center item is not hideable")
    func genericUnresolvedControlCenterItemIsReadOnly() throws {
        let window = MenuBarWindowInfo(
            windowID: 56,
            frame: CGRect(x: 100, y: 0, width: 24, height: 24),
            title: "Item-0",
            ownerPID: ProcessInfo.processInfo.processIdentifier,
            ownerName: "Control Center"
        )

        let item = try #require(MenuBarPhysicalItem(window: window))

        #expect(!item.canBeHidden)
        #expect(!item.detectedItem().isHideCandidate)
    }

    @Test("source-resolved combined module host is hideable")
    func sourceResolvedCombinedModuleHostIsHideable() throws {
        let window = MenuBarWindowInfo(
            windowID: 57,
            frame: CGRect(x: 100, y: 0, width: 270, height: 24),
            title: "CombinedModules",
            ownerPID: 100,
            sourcePID: 101,
            ownerName: "Control Center"
        )

        let item = try #require(MenuBarPhysicalItem(window: window))

        #expect(item.canBeHidden)
        #expect(item.detectedItem().isHideCandidate)
    }

    @Test("assigns stable instance indices for duplicate app items")
    func assignsStableInstanceIndicesForDuplicateAppItems() throws {
        var items = [
            try physicalItem(title: "CombinedModules", x: 120, width: 24, windowID: 200),
            try physicalItem(title: "CombinedModules", x: 80, width: 24, windowID: 100)
        ]

        MenuBarDiscoveryNormalizer.assignStableInstanceIndices(to: &items)

        let sorted = items.sorted { $0.windowID < $1.windowID }
        #expect(sorted[0].identity.description == "<null>:CombinedModules")
        #expect(sorted[1].identity.description == "<null>:CombinedModules:1")
    }

    @MainActor
    @Test("layout view sections are driven by live physical section state")
    func layoutSectionsUseLivePhysicalState() {
        let physicallyVisibleStats = DetectedMenuBarItem(
            id: "eu.exelban.Stats:CombinedModules",
            windowID: 42,
            ownerName: "Stats",
            title: "CombinedModules",
            processIdentifier: 100,
            sourceProcessIdentifier: 200,
            sourceBundleIdentifier: "eu.exelban.Stats",
            frame: CGRect(x: 800, y: 0, width: 48, height: 24),
            isPrivateWindowBacked: true,
            infoKey: "eu.exelban.Stats:CombinedModules",
            actualSection: .pinned
        )

        #expect(MenuBarLayoutSectionSource.displayedSection(for: physicallyVisibleStats) == .pinned)
        #expect(!MenuBarLayoutSectionSource.isHiddenInLiveLayout(physicallyVisibleStats))
    }

    @MainActor
    @Test("physically visible items are not counted as hidden selections")
    func physicallyVisibleItemsAreNotCountedAsHiddenSelections() {
        let scanner = MenuBarScannerService()
        let model = AppModel(menuBarScanner: scanner)
        model.store.config.menuBarLayout.items = []
        model.store.config.menuBarLayout.setMenuBarItemSection(
            itemKey: "eu.exelban.Stats:CombinedModules",
            title: "Stats",
            section: .hidden
        )

        let physicallyVisibleStats = DetectedMenuBarItem(
            id: "eu.exelban.Stats:CombinedModules",
            windowID: 42,
            ownerName: "Stats",
            title: "CombinedModules",
            processIdentifier: 100,
            sourceProcessIdentifier: 200,
            sourceBundleIdentifier: "eu.exelban.Stats",
            frame: CGRect(x: 800, y: 0, width: 48, height: 24),
            isPrivateWindowBacked: true,
            infoKey: "eu.exelban.Stats:CombinedModules",
            actualSection: .pinned
        )

        scanner.setDetectedItemsForTesting([physicallyVisibleStats])

        #expect(model.hiddenMenuBarSelections.isEmpty)
        #expect(model.hiddenMenuBarItemCount == 0)
    }

    private func physicalItem(title: String, x: CGFloat) throws -> MenuBarPhysicalItem {
        try physicalItem(title: title, x: x, width: 10)
    }

    private func physicalItem(title: String, x: CGFloat, width: CGFloat) throws -> MenuBarPhysicalItem {
        try physicalItem(title: title, x: x, width: width, windowID: CGWindowID(Int.random(in: 10...9999)))
    }

    private func physicalItem(title: String, x: CGFloat, width: CGFloat, windowID: CGWindowID) throws -> MenuBarPhysicalItem {
        let window = MenuBarWindowInfo(
            windowID: windowID,
            frame: CGRect(x: x, y: 0, width: width, height: 24),
            title: title,
            ownerPID: 999_999,
            ownerName: "Test"
        )
        return try #require(MenuBarPhysicalItem(window: window))
    }
}
