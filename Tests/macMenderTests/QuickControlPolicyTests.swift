import CoreGraphics
import Testing
@testable import macMender

@Suite("Quick Controls and Strip Layout")
struct QuickControlPolicyTests {
    @Test("three-finger quick control restores its concrete trigger")
    func threeFingerQuickControlRestoresTrigger() {
        var profile = MacMenderProfile.default
        profile.middleClick = .disabled

        profile.setThreeFingerTapEnabled(true)

        #expect(profile.isThreeFingerTapEnabled)
        #expect(profile.middleClick.trigger == .experimentalThreeFinger)
    }

    @Test("external mouse quick control changes only vertical mouse direction")
    func externalMouseQuickControlIsNarrow() {
        var profile = MacMenderProfile.default
        let trackpadBefore = profile.scroll.deviceRules.first { $0.deviceKind == .builtInTrackpad }
        let mouseHorizontalBefore = profile.scroll.deviceRules.first { $0.deviceKind == .externalMouse }?.reverseHorizontal

        profile.setExternalMouseReverseScrollingEnabled(false)

        #expect(!profile.isExternalMouseReverseScrollingEnabled)
        #expect(profile.scroll.deviceRules.first { $0.deviceKind == .builtInTrackpad } == trackpadBefore)
        #expect(profile.scroll.deviceRules.first { $0.deviceKind == .externalMouse }?.reverseHorizontal == mouseHorizontalBefore)
    }

    @Test("strip layout is a bounded single-row presentation")
    func stripLayoutUsesOneRow() {
        let visibleSize = CGSize(width: 1440, height: 900)
        let strip = WindowSwitcherPresentationMetrics.calculate(
            layout: .strip,
            windowCount: 8,
            requestedThumbnailSize: 180,
            visibleSize: visibleSize,
            isDockPreview: false
        )
        let grid = WindowSwitcherPresentationMetrics.calculate(
            layout: .grid,
            windowCount: 8,
            requestedThumbnailSize: 180,
            visibleSize: visibleSize,
            isDockPreview: false
        )

        #expect(strip.gridColumnCount == 8)
        #expect(strip.panelSize.width <= visibleSize.width * 0.82)
        #expect(strip.panelSize.height < grid.panelSize.height)
        #expect(strip.thumbnailSize == 180)
    }

    @Test("strip layout keeps small requested thumbnails usable")
    func stripLayoutClampsSmallThumbnails() {
        let metrics = WindowSwitcherPresentationMetrics.calculate(
            layout: .strip,
            windowCount: 2,
            requestedThumbnailSize: 72,
            visibleSize: CGSize(width: 1000, height: 700),
            isDockPreview: false
        )

        #expect(metrics.thumbnailSize == 112)
        #expect(metrics.panelSize.width >= 420)
        #expect(metrics.panelSize.height >= 220)
    }
}
