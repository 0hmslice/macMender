import CoreGraphics
import Foundation
import Testing
@testable import macMender

struct DockPreviewLayoutTests {
    private let roomy = CGSize(width: 1600, height: 620)
    private typealias Metrics = DockPreviewLayout.Metrics

    private func layout(
        _ ratios: [CGFloat],
        height: CGFloat = 150,
        titles: Bool = true,
        edge: DockEdge = .bottom,
        limit: CGSize? = nil
    ) -> DockPreviewLayout {
        DockPreviewLayout.compute(
            aspectRatios: ratios,
            thumbnailHeight: height,
            showTitles: titles,
            edge: edge,
            maximumContentSize: limit ?? roomy
        )
    }

    private func assertCardsInsideContentWithoutOverlap(_ layout: DockPreviewLayout) {
        let bounds = CGRect(origin: .zero, size: layout.contentSize)
        for (index, frame) in layout.cardFrames.enumerated() {
            #expect(bounds.contains(frame))
            for other in layout.cardFrames[(index + 1)...] {
                #expect(!frame.intersects(other))
            }
        }
    }

    @Test func singleWindowHugsItsThumbnail() {
        let result = layout([1.6])
        #expect(result.cardFrames.count == 1)
        #expect(result.hiddenCount == 0)
        #expect(result.thumbnailSizes[0] == CGSize(width: 240, height: 150))
        #expect(result.contentSize.width == 240 + Metrics.cardPadding * 2 + Metrics.contentPadding * 2)
        #expect(result.contentSize.height == 150 + Metrics.titleHeight + Metrics.cardPadding * 2 + Metrics.contentPadding * 2)
    }

    @Test func hidingTitlesRemovesTheirHeight() {
        #expect(layout([1.6]).contentSize.height - layout([1.6], titles: false).contentSize.height == Metrics.titleHeight)
    }

    @Test func extremeAspectRatiosAreBounded() {
        let result = layout([0.1, 12])
        #expect(result.thumbnailSizes[0].width == (150 * Metrics.minimumAspectRatio).rounded())
        #expect(result.thumbnailSizes[1].width == (150 * Metrics.maximumAspectRatio).rounded())
    }

    @Test func bottomDockUsesOneRowWhenWindowsFit() {
        let result = layout([1.5, 1.5, 1.5])
        #expect(Set(result.cardFrames.map(\.minY)).count == 1)
        #expect(result.cardFrames.map(\.minX) == result.cardFrames.map(\.minX).sorted())
        assertCardsInsideContentWithoutOverlap(result)
    }

    @Test func sideDockStacksWindowsInOneColumn() {
        let result = layout([1.5, 1.0, 1.8], edge: .left, limit: CGSize(width: 900, height: 900))
        #expect(result.cardFrames.map(\.minY) == result.cardFrames.map(\.minY).sorted())
        let centers = result.cardFrames.map(\.midX)
        #expect(centers.max()! - centers.min()! <= 1)
        assertCardsInsideContentWithoutOverlap(result)
    }

    @Test func wrappedRowsAreBalanced() {
        // Four cards fit per row; five windows should split 3 + 2, not 4 + 1.
        let cardWidth = 150 * 1.5 + Metrics.cardPadding * 2
        let limit = CGSize(width: cardWidth * 4 + Metrics.cardSpacing * 3 + Metrics.contentPadding * 2 + 1, height: 620)
        let result = layout(Array(repeating: 1.5, count: 5), limit: limit)
        let rows = Dictionary(grouping: result.cardFrames, by: \.minY).values.map(\.count).sorted()
        #expect(rows == [2, 3])
        #expect(result.thumbnailHeight == 150)
        assertCardsInsideContentWithoutOverlap(result)
    }

    @Test func thumbnailsShrinkBeforeAnyWindowIsHidden() {
        let limit = CGSize(width: 700, height: 300)
        let result = layout(Array(repeating: 1.5, count: 8), limit: limit)
        #expect(result.hiddenCount == 0)
        #expect(result.cardFrames.count == 8)
        #expect(result.thumbnailHeight < 150)
        #expect(result.thumbnailHeight >= Metrics.minimumThumbnailHeight)
        #expect(result.contentSize.width <= limit.width)
        #expect(result.contentSize.height <= limit.height)
        assertCardsInsideContentWithoutOverlap(result)
    }

    @Test func overflowIsCountedWhenWindowsCannotFit() {
        let limit = CGSize(width: 500, height: 200)
        let result = layout(Array(repeating: 1.5, count: 30), limit: limit)
        #expect(result.thumbnailHeight == Metrics.minimumThumbnailHeight)
        #expect(result.hiddenCount > 0)
        #expect(result.cardFrames.count + result.hiddenCount == 30)
        #expect(result.contentSize.width <= limit.width)
        #expect(result.contentSize.height <= limit.height)
        assertCardsInsideContentWithoutOverlap(result)
    }

    @Test func noWindowsProducesAnEmptyLayout() {
        let result = layout([])
        #expect(result.cardFrames.isEmpty)
        #expect(result.contentSize == .zero)
    }
}

struct DockPreviewPlacementTests {
    private let screen = CGRect(x: 0, y: 0, width: 1710, height: 1112)
    private let visible = CGRect(x: 0, y: 0, width: 1710, height: 1074)
    private let size = CGSize(width: 400, height: 220)

    private func frame(icon: CGRect, dock: CGRect, edge: DockEdge) -> CGRect {
        DockPreviewPlacement.contentFrame(
            contentSize: size,
            iconFrame: icon,
            dockFrame: dock,
            edge: edge,
            screenFrame: screen,
            visibleFrame: visible
        )
    }

    @Test func hiddenOrSlidingDockIsMovedToItsRestingPosition() {
        // Bottom Dock halfway through sliding in, then fully hidden.
        for hiddenBy in [CGFloat(30), 65] {
            let resting = DockPreviewPlacement.restingFrames(
                iconFrame: CGRect(x: 800, y: -4 - hiddenBy, width: 49, height: 65),
                dockFrame: CGRect(x: 35, y: -hiddenBy, width: 1640, height: 65),
                edge: .bottom,
                screenFrame: screen
            )
            #expect(resting.dockFrame == CGRect(x: 35, y: 0, width: 1640, height: 65))
            #expect(resting.iconFrame == CGRect(x: 800, y: -4, width: 49, height: 65))
            let result = frame(icon: resting.iconFrame, dock: resting.dockFrame, edge: .bottom)
            #expect(result.minY == 65 + DockPreviewLayout.Metrics.dockGap)
        }

        let left = DockPreviewPlacement.restingFrames(
            iconFrame: CGRect(x: -60, y: 500, width: 56, height: 49),
            dockFrame: CGRect(x: -65, y: 100, width: 65, height: 900),
            edge: .left,
            screenFrame: screen
        )
        #expect(left.dockFrame.minX == 0)
        #expect(left.iconFrame.minX == 5)

        let right = DockPreviewPlacement.restingFrames(
            iconFrame: CGRect(x: 1714, y: 500, width: 56, height: 49),
            dockFrame: CGRect(x: 1710, y: 100, width: 65, height: 900),
            edge: .right,
            screenFrame: screen
        )
        #expect(right.dockFrame.maxX == 1710)
        #expect(right.iconFrame.minX == 1649)
    }

    @Test func visibleDockIsLeftWhereItIs() {
        let icon = CGRect(x: 800, y: 4, width: 56, height: 60)
        let dock = CGRect(x: 40, y: 0, width: 1630, height: 69)
        let resting = DockPreviewPlacement.restingFrames(iconFrame: icon, dockFrame: dock, edge: .bottom, screenFrame: screen)
        #expect(resting.iconFrame == icon)
        #expect(resting.dockFrame == dock)
    }

    @Test func bottomDockPreviewSitsAboveTheIconAndCentersOnIt() {
        let icon = CGRect(x: 800, y: 4, width: 56, height: 60)
        let result = frame(icon: icon, dock: CGRect(x: 40, y: 0, width: 1630, height: 69), edge: .bottom)
        #expect(result.midX == icon.midX)
        #expect(result.minY == 69 + DockPreviewLayout.Metrics.dockGap)
    }

    @Test func magnifiedIconPushesThePreviewClear() {
        let icon = CGRect(x: 800, y: 4, width: 96, height: 110)
        let result = frame(icon: icon, dock: CGRect(x: 40, y: 0, width: 1630, height: 69), edge: .bottom)
        #expect(result.minY == icon.maxY + DockPreviewLayout.Metrics.dockGap)
    }

    @Test func previewStaysOnScreenForIconsNearTheEdges() {
        let dock = CGRect(x: 0, y: 0, width: 1710, height: 69)
        let left = frame(icon: CGRect(x: 6, y: 4, width: 56, height: 60), dock: dock, edge: .bottom)
        let right = frame(icon: CGRect(x: 1650, y: 4, width: 56, height: 60), dock: dock, edge: .bottom)
        #expect(left.minX == DockPreviewLayout.Metrics.screenMargin)
        #expect(right.maxX == screen.maxX - DockPreviewLayout.Metrics.screenMargin)
    }

    @Test func sideDocksPlaceThePreviewBesideTheIcon() {
        let leftIcon = CGRect(x: 4, y: 500, width: 60, height: 56)
        let left = frame(icon: leftIcon, dock: CGRect(x: 0, y: 100, width: 69, height: 900), edge: .left)
        #expect(left.minX == 69 + DockPreviewLayout.Metrics.dockGap)
        #expect(left.midY == leftIcon.midY)

        let rightIcon = CGRect(x: 1646, y: 500, width: 60, height: 56)
        let right = frame(icon: rightIcon, dock: CGRect(x: 1641, y: 100, width: 69, height: 900), edge: .right)
        #expect(right.maxX == 1641 - DockPreviewLayout.Metrics.dockGap)
        #expect(right.midY == rightIcon.midY)
    }
}

struct DockPreviewSafeZoneTests {
    private let zone = DockPreviewSafeZone(
        iconFrame: CGRect(x: 800, y: 4, width: 56, height: 60),
        contentFrame: CGRect(x: 400, y: 77, width: 856, height: 220),
        edge: .bottom
    )

    @Test func previewAndIconAreSafe() {
        #expect(zone.contains(CGPoint(x: 828, y: 30)))
        #expect(zone.contains(CGPoint(x: 500, y: 200)))
        #expect(zone.contains(CGPoint(x: 828, y: 0)))
    }

    @Test func gapBetweenIconAndPreviewIsSafe() {
        #expect(zone.contains(CGPoint(x: 828, y: 70)))
    }

    @Test func diagonalPathToADistantCardIsSafe() {
        // Leaving the icon's top-left corner toward the far-left card crosses neighboring icons.
        #expect(zone.contains(CGPoint(x: 700, y: 45)))
        #expect(zone.contains(CGPoint(x: 560, y: 66)))
    }

    @Test func pointsAwayFromThePreviewAreNotSafe() {
        #expect(!zone.contains(CGPoint(x: 300, y: 30)))
        #expect(!zone.contains(CGPoint(x: 600, y: 10)))
        #expect(!zone.contains(CGPoint(x: 828, y: 400)))
        #expect(!zone.contains(CGPoint(x: 1400, y: 150)))
    }

    @Test func slidingAlongTheDockIsOutsideTheCorridor() {
        #expect(!zone.isInCorridor(CGPoint(x: 740, y: 25)))
        #expect(zone.isInCorridor(CGPoint(x: 740, y: 55)))
    }

    @Test func sideDockCorridorIsSafe() {
        let side = DockPreviewSafeZone(
            iconFrame: CGRect(x: 4, y: 500, width: 60, height: 56),
            contentFrame: CGRect(x: 77, y: 200, width: 300, height: 700),
            edge: .left
        )
        #expect(side.contains(CGPoint(x: 70, y: 600)))
        #expect(side.contains(CGPoint(x: 0, y: 528)))
        #expect(!side.contains(CGPoint(x: 30, y: 880)))
        #expect(!side.contains(CGPoint(x: 500, y: 500)))
    }
}

struct DockPreviewSettingsTests {
    @Test func settingsSavedBeforeTheRebuildStillDecode() throws {
        let legacy = Data("""
        {"enabled": false, "hoverDelay": 0.5, "previewIdleTimeout": 1.8, "animationStyle": "genie",
         "animationSpeed": "smooth", "layout": "grid", "thumbnailSize": 152}
        """.utf8)
        let settings = try JSONDecoder().decode(DockPreviewSettings.self, from: legacy)
        #expect(!settings.enabled)
        #expect(settings.hoverDelay == 0.5)
        #expect(settings.animationStyle == .scale)
        #expect(settings.animationDuration == 0.42)
        #expect(settings.dismissDelay == DockPreviewSettings.defaultDismissDelay)
        #expect(settings.previewSize == DockPreviewSettings.defaultPreviewSize)
        #expect(settings.showWindowControls && settings.livePreviews && settings.includeOtherSpaces)
    }

    @Test func settingsRoundTrip() throws {
        var settings = DockPreviewSettings.default
        settings.previewSize = 200
        settings.showWindowControls = false
        settings.includeHiddenApps = false
        settings.dismissDelay = 0.6
        let decoded = try JSONDecoder().decode(DockPreviewSettings.self, from: JSONEncoder().encode(settings))
        #expect(decoded == settings)
    }

    @Test func outOfRangeValuesAreClamped() {
        let settings = DockPreviewSettings(hoverDelay: 9, dismissDelay: 0, animationDuration: 5, previewSize: 10)
        #expect(settings.hoverDelay == DockPreviewSettings.hoverDelayRange.upperBound)
        #expect(settings.dismissDelay == DockPreviewSettings.dismissDelayRange.lowerBound)
        #expect(settings.animationDuration == DockPreviewSettings.animationDurationRange.upperBound)
        #expect(settings.previewSize == DockPreviewSettings.previewSizeRange.lowerBound)
    }

    @Test func untouchedLegacyDefaultsMoveToTheNewDefaults() {
        var config = AppConfig.default
        config.schemaVersion = 6
        config.profiles[0].dockPreviews.hoverDelay = DockPreviewSettings.legacyDefaultHoverDelay
        config.profiles[0].dockPreviews.animationDuration = DockPreviewSettings.legacyDefaultAnimationDuration
        let migrated = AppConfig.normalizedForStorage(config)
        #expect(migrated.schemaVersion == 7)
        #expect(migrated.profiles[0].dockPreviews.hoverDelay == DockPreviewSettings.defaultHoverDelay)
        #expect(migrated.profiles[0].dockPreviews.animationDuration == DockPreviewSettings.defaultAnimationDuration)
    }

    @Test func customizedLegacyValuesAreKept() {
        var config = AppConfig.default
        config.schemaVersion = 6
        config.profiles[0].dockPreviews.hoverDelay = 0.8
        config.profiles[0].dockPreviews.animationDuration = 0.4
        let migrated = AppConfig.normalizedForStorage(config)
        #expect(migrated.profiles[0].dockPreviews.hoverDelay == 0.8)
        #expect(migrated.profiles[0].dockPreviews.animationDuration == 0.4)
    }
}

struct WindowDiscoveryRuleTests {
    private func facts(
        title: String = "",
        axWindowID: CGWindowID? = nil,
        matched: CGWindowID? = nil,
        role: String? = "AXWindow",
        frame: CGRect = .zero,
        minimized: Bool = false
    ) -> WindowDiscoveryCandidateFacts {
        WindowDiscoveryCandidateFacts(
            bundleIdentifier: "com.example.app",
            rawTitle: title,
            axWindowID: axWindowID,
            matchedCGWindowID: matched,
            role: role,
            subrole: nil,
            frame: frame,
            isMinimized: minimized
        )
    }

    @Test func onScreenWindowsAreIncluded() {
        #expect(WindowDiscoveryEligibility.decision(for: facts(matched: 42)).isIncluded)
    }

    @Test func minimizedWindowsAreIncludedWithoutAnOnScreenMatch() {
        #expect(WindowDiscoveryEligibility.decision(for: facts(minimized: true)).isIncluded)
    }

    @Test func shapelessUntitledElementsAreDropped() {
        #expect(!WindowDiscoveryEligibility.decision(for: facts()).isIncluded)
        #expect(!WindowDiscoveryEligibility.decision(for: facts(title: "Sheet", role: "AXSheet")).isIncluded)
    }

    @Test func finderDesktopIsNotAPreviewableWindow() {
        let screen = CGRect(x: 0, y: 0, width: 1710, height: 1112)
        var desktop = WindowSummary(
            id: "1-desktop", windowID: nil, axWindowID: nil, appName: "Finder", bundleIdentifier: "com.apple.finder",
            title: "Untitled Window", rawTitle: "", processIdentifier: 1, frame: screen, isMinimized: false,
            stackIndex: 0, axElement: nil
        )
        #expect(!desktop.isPreviewableAppWindow(screenFrames: [screen]))
        desktop.windowID = 9
        desktop.axRole = "AXWindow"
        desktop.frame = CGRect(x: 100, y: 100, width: 800, height: 600)
        #expect(desktop.isPreviewableAppWindow(screenFrames: [screen]))
    }
}

struct DockPreviewInteractionTests {
    private func layout(_ count: Int, edge: DockEdge = .bottom, limit: CGSize = CGSize(width: 1600, height: 620)) -> DockPreviewLayout {
        DockPreviewLayout.compute(
            aspectRatios: Array(repeating: 1.6, count: count),
            thumbnailHeight: 150,
            showTitles: true,
            edge: edge,
            maximumContentSize: limit
        )
    }

    @Test func arrowKeysStartAtAnEndWhenNothingIsSelected() {
        let row = layout(3)
        #expect(row.cardIndex(from: nil, moving: .right, edge: .bottom) == 0)
        #expect(row.cardIndex(from: nil, moving: .left, edge: .bottom) == 2)
        #expect(layout(0).cardIndex(from: nil, moving: .right, edge: .bottom) == nil)
    }

    @Test func arrowKeysWalkARowAndWrap() {
        let row = layout(3)
        #expect(row.cardIndex(from: 0, moving: .right, edge: .bottom) == 1)
        #expect(row.cardIndex(from: 1, moving: .right, edge: .bottom) == 2)
        #expect(row.cardIndex(from: 2, moving: .right, edge: .bottom) == 0)
        #expect(row.cardIndex(from: 0, moving: .left, edge: .bottom) == 2)
        // Nothing lies above or below a single row.
        #expect(row.cardIndex(from: 1, moving: .up, edge: .bottom) == 1)
        #expect(row.cardIndex(from: 1, moving: .down, edge: .bottom) == 1)
    }

    @Test func arrowKeysMoveBetweenRows() {
        let grid = layout(6, limit: CGSize(width: 820, height: 620))
        #expect(Set(grid.cardFrames.map(\.minY)).count == 2)
        #expect(grid.cardIndex(from: 0, moving: .down, edge: .bottom) == 3)
        #expect(grid.cardIndex(from: 4, moving: .up, edge: .bottom) == 1)
        #expect(grid.cardIndex(from: 2, moving: .right, edge: .bottom) == 3)
    }

    @Test func arrowKeysFollowAColumnBesideASideDock() {
        let column = layout(3, edge: .left)
        #expect(Set(column.cardFrames.map(\.minX)).count == 1)
        #expect(column.cardIndex(from: 0, moving: .down, edge: .left) == 1)
        #expect(column.cardIndex(from: 2, moving: .down, edge: .left) == 0)
        #expect(column.cardIndex(from: 0, moving: .up, edge: .left) == 2)
        #expect(column.cardIndex(from: 1, moving: .right, edge: .left) == 1)
    }

    @Test func peekKeepsAVisibleWindowWhereItIs() {
        let visible = CGRect(x: 0, y: 0, width: 1440, height: 875)
        let window = CGRect(x: 200, y: 150, width: 900, height: 600)
        #expect(DockPreviewPeekPlacement.frame(windowFrame: window, windowSize: window.size, visibleFrame: visible) == window)
    }

    @Test func peekCentersAndShrinksWindowsThatAreNotOnScreen() {
        let visible = CGRect(x: 0, y: 25, width: 1440, height: 850)
        let small = DockPreviewPeekPlacement.frame(windowFrame: nil, windowSize: CGSize(width: 600, height: 400), visibleFrame: visible)
        #expect(small.size == CGSize(width: 600, height: 400))
        #expect(abs(small.midX - visible.midX) <= 1)
        #expect(abs(small.midY - visible.midY) <= 1)

        let large = DockPreviewPeekPlacement.frame(windowFrame: nil, windowSize: CGSize(width: 2880, height: 1800), visibleFrame: visible)
        #expect(large.width <= visible.width * 0.8 + 1)
        #expect(large.height <= visible.height * 0.8 + 1)
        #expect(abs(large.width / large.height - 1.6) < 0.01)
        #expect(visible.contains(large))

        // A window on a display that is not showing the preview is centered on the one that is.
        let elsewhere = CGRect(x: 3000, y: 0, width: 800, height: 600)
        let moved = DockPreviewPeekPlacement.frame(windowFrame: elsewhere, windowSize: elsewhere.size, visibleFrame: visible)
        #expect(visible.contains(moved))
    }

    @Test func dockItemsMatchByBundleOrMinimizedTitle() {
        let safari = DockAppIdentity(title: "Safari", bundleIdentifier: "com.apple.Safari", processIdentifier: 10)
        let relaunched = DockAppIdentity(title: "Safari", bundleIdentifier: "com.apple.Safari", processIdentifier: 99)
        let notes = DockAppIdentity(title: "Notes", bundleIdentifier: "com.apple.Notes", processIdentifier: 11)
        #expect(safari.isSameDockItem(as: relaunched))
        #expect(!safari.isSameDockItem(as: notes))

        let tile = DockAppIdentity(title: "Report.txt", bundleIdentifier: nil, processIdentifier: nil, isMinimizedWindow: true)
        let otherTile = DockAppIdentity(title: "Notes.txt", bundleIdentifier: nil, processIdentifier: nil, isMinimizedWindow: true)
        #expect(tile.isSameDockItem(as: tile))
        #expect(!tile.isSameDockItem(as: otherTile))
        #expect(!tile.isSameDockItem(as: safari))
    }

    @Test func settingsSavedBeforePeekAndKeyboardKeepThemOn() throws {
        let json = #"{"enabled": true, "hoverDelay": 0.3, "previewSize": 140}"#
        let decoded = try JSONDecoder().decode(DockPreviewSettings.self, from: Data(json.utf8))
        #expect(decoded.peekOnHover)
        #expect(decoded.keyboardNavigation)

        var changed = decoded
        changed.peekOnHover = false
        changed.keyboardNavigation = false
        let roundTripped = try JSONDecoder().decode(DockPreviewSettings.self, from: JSONEncoder().encode(changed))
        #expect(roundTripped == changed)
    }
}

struct DockPreviewFeatureTests {
    private let visible = CGRect(x: 0, y: 25, width: 1440, height: 850)

    @Test func headerSitsAboveTheCardsWithoutMovingThemSideways() {
        let limit = CGSize(width: 1600, height: 620)
        let plain = DockPreviewLayout.compute(aspectRatios: [1.6, 1.6], thumbnailHeight: 150, showTitles: true, edge: .bottom, maximumContentSize: limit)
        let headed = DockPreviewLayout.compute(aspectRatios: [1.6, 1.6], thumbnailHeight: 150, showTitles: true, showHeader: true, edge: .bottom, maximumContentSize: limit)
        #expect(plain.headerHeight == 0)
        #expect(headed.headerHeight == DockPreviewLayout.Metrics.headerHeight)
        #expect(headed.contentSize.width == plain.contentSize.width)
        #expect(headed.contentSize.height > plain.contentSize.height)
        for (card, original) in zip(headed.cardFrames, plain.cardFrames) {
            #expect(card.minY >= headed.headerHeight)
            #expect(card.minX == original.minX)
            #expect(card.maxY <= headed.contentSize.height)
        }
    }

    @Test func headerWidensANarrowPreviewAndCentersItsCard() {
        let layout = DockPreviewLayout.compute(
            aspectRatios: [0.72],
            thumbnailHeight: 90,
            showTitles: true,
            showHeader: true,
            edge: .bottom,
            maximumContentSize: CGSize(width: 1600, height: 620)
        )
        #expect(layout.contentSize.width == DockPreviewLayout.Metrics.minimumHeaderWidth)
        #expect(abs(layout.cardFrames[0].midX - layout.contentSize.width / 2) <= 1)
    }

    @Test func headerStillFitsWithinTheAvailableHeight() {
        let limit = CGSize(width: 900, height: 420)
        let layout = DockPreviewLayout.compute(
            aspectRatios: Array(repeating: 1.6, count: 9),
            thumbnailHeight: 180,
            showTitles: true,
            showHeader: true,
            edge: .bottom,
            maximumContentSize: limit
        )
        #expect(layout.contentSize.height <= limit.height)
        #expect(layout.contentSize.width <= limit.width)
    }

    @Test func halvesSplitTheScreenAndFillCoversIt() {
        let size = CGSize(width: 800, height: 600)
        let left = WindowArrangement.leftHalf.frame(windowSize: size, in: visible)
        let right = WindowArrangement.rightHalf.frame(windowSize: size, in: visible)
        #expect(left == CGRect(x: 0, y: 25, width: 720, height: 850))
        #expect(right == CGRect(x: 720, y: 25, width: 720, height: 850))
        #expect(WindowArrangement.fill.frame(windowSize: size, in: visible) == visible)
    }

    @Test func centerKeepsSizeUnlessTheWindowIsTooLarge() {
        let centered = WindowArrangement.center.frame(windowSize: CGSize(width: 800, height: 600), in: visible)
        #expect(centered.size == CGSize(width: 800, height: 600))
        #expect(abs(centered.midX - visible.midX) <= 1)
        #expect(abs(centered.midY - visible.midY) <= 1)

        let oversized = WindowArrangement.center.frame(windowSize: CGSize(width: 3000, height: 2000), in: visible)
        #expect(oversized == visible)
    }

    @Test func movingToAnotherDisplayKeepsRelativePlaceAndFits() {
        let source = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let destination = CGRect(x: 1440, y: 0, width: 1920, height: 1080)
        let topRight = CGRect(x: 1440 - 600, y: 0, width: 600, height: 400)
        let moved = WindowArrangement.frame(moving: topRight, from: source, to: destination)
        #expect(moved.size == topRight.size)
        #expect(moved.maxX == destination.maxX)
        #expect(moved.minY == destination.minY)

        let small = CGRect(x: 2000, y: 0, width: 1024, height: 700)
        let large = CGRect(x: 100, y: 50, width: 1800, height: 1000)
        let shrunk = WindowArrangement.frame(moving: large, from: destination, to: small)
        #expect(small.contains(shrunk))
    }

    @Test func settingsSavedEarlierGainNewOptionsWithDefaults() throws {
        let preview = try JSONDecoder().decode(DockPreviewSettings.self, from: Data(#"{"enabled": true}"#.utf8))
        #expect(preview.showAppHeader)
        #expect(preview.excludedBundleIdentifiers.isEmpty)

        var changed = preview
        changed.showAppHeader = false
        changed.excludedBundleIdentifiers = ["com.example.app"]
        #expect(try JSONDecoder().decode(DockPreviewSettings.self, from: JSONEncoder().encode(changed)) == changed)

        let legacySwitcher = #"{"enabled": true, "shortcut": "Option+Tab", "layout": "grid", "thumbnailSize": 180, "includeMinimizedWindows": true, "includeHiddenApps": false}"#
        let switcher = try JSONDecoder().decode(WindowSwitcherSettings.self, from: Data(legacySwitcher.utf8))
        #expect(switcher.includeOtherSpaces)
    }
}
