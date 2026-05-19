import AppKit
import Testing
@testable import macMender

@Suite("Symbol Assets")
struct SymbolAssetTests {
    @Test("sidebar symbols resolve on the target macOS SDK")
    func sidebarSymbolsResolve() {
        for section in SettingsSection.allCases {
            #expect(
                NSImage(systemSymbolName: section.symbolName, accessibilityDescription: nil) != nil,
                "Missing SF Symbol for \(section.title): \(section.symbolName)"
            )
        }
    }

    @Test("common view symbols resolve on the target macOS SDK")
    func commonViewSymbolsResolve() {
        let symbols = [
            "accessibility",
            "app.connected.to.app.below.fill",
            "arrow.counterclockwise",
            "bolt",
            "checkmark.circle",
            "checkmark.circle.fill",
            "checkmark.shield",
            "chevron.left",
            "circle.dashed",
            "circle.grid.cross",
            "clock.badge.checkmark",
            "clock.badge.questionmark",
            "computermouse",
            "dock.arrow.up.rectangle",
            "dock.rectangle",
            "dot.radiowaves.left.and.right",
            "exclamationmark.circle",
            "exclamationmark.triangle.fill",
            "eye",
            "eye.slash",
            "gamecontroller",
            "gearshape.fill",
            "hand.draw",
            "hand.raised",
            "hand.tap",
            "list.bullet.rectangle",
            "lock",
            "lock.shield",
            "lock.trianglebadge.exclamationmark",
            "macwindow",
            "menubar.rectangle",
            "pause.circle",
            "pause.circle.fill",
            "pin",
            "plus",
            "plus.rectangle.on.rectangle",
            "power",
            "rectangle.3.group",
            "rectangle.3.group.fill",
            "rectangle.and.hand.point.up.left",
            "rectangle.on.rectangle",
            "rectangle.on.rectangle.angled",
            "rectangle.portrait",
            "scroll",
            "sensor",
            "slider.horizontal.3",
            "square.stack.3d.up",
            "square.stack.3d.up.slash",
            "sparkles",
            "stethoscope",
            "tray",
            "wrench.and.screwdriver",
            "wrench.and.screwdriver.fill"
        ]

        for symbol in symbols {
            #expect(
                NSImage(systemSymbolName: symbol, accessibilityDescription: nil) != nil,
                "Missing SF Symbol: \(symbol)"
            )
        }
    }

    @Test("Mendy resources are bundled")
    func mendyResourcesResolve() {
        for asset in [MendyAssets.avatar, MendyAssets.menuBarColor, MendyAssets.menuBarTemplate, MendyAssets.appIcon] {
            #expect(
                MendyAssets.image(named: asset) != nil,
                "Missing Mendy resource: \(asset)"
            )
        }
    }
}
