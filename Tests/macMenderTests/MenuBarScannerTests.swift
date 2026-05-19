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

    @Test("identifies internal macMender divider items")
    func identifiesInternalItems() {
        let overflowDivider = DetectedMenuBarItem(
            id: "3",
            windowID: 3,
            ownerName: "Control Center",
            title: "HItem",
            processIdentifier: 100,
            frame: .zero
        )
        let hiddenDivider = DetectedMenuBarItem(
            id: "4",
            windowID: 4,
            ownerName: "Control Center",
            title: "AHItem",
            processIdentifier: 100,
            frame: .zero
        )
        let visibleControl = DetectedMenuBarItem(
            id: "5",
            windowID: 5,
            ownerName: "Control Center",
            title: "SItem",
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
}
