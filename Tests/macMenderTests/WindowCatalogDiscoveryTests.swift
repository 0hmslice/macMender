import AppKit
import ApplicationServices
import Testing
@testable import macMender

@Suite("Window Catalog Discovery")
struct WindowCatalogDiscoveryTests {
    @Test("Finder desktop AX element without window identity is excluded")
    func finderDesktopAXElementWithoutWindowIdentityIsExcluded() {
        let decision = WindowDiscoveryEligibility.decision(for: WindowDiscoveryCandidateFacts(
            bundleIdentifier: "com.apple.finder",
            rawTitle: "",
            axWindowID: nil,
            matchedCGWindowID: nil,
            role: kAXScrollAreaRole as String,
            subrole: nil,
            frame: CGRect(x: 0, y: 0, width: 1710, height: 1112),
            isMinimized: false
        ))

        #expect(decision == .drop(reason: "nonWindowAXElementNoCGMatch"))
    }

    @Test("real Finder window with CG identity is included")
    func realFinderWindowWithCGIdentityIsIncluded() {
        let decision = WindowDiscoveryEligibility.decision(for: WindowDiscoveryCandidateFacts(
            bundleIdentifier: "com.apple.finder",
            rawTitle: "Downloads",
            axWindowID: 3431,
            matchedCGWindowID: 3431,
            role: kAXWindowRole as String,
            subrole: kAXStandardWindowSubrole as String,
            frame: CGRect(x: 95, y: 301, width: 919, height: 481),
            isMinimized: false
        ))

        #expect(decision == .include(reason: "includedAXWindowCGMatched"))
    }

    @Test("legitimate untitled non-Finder CG window is included")
    func legitimateUntitledNonFinderCGWindowIsIncluded() {
        let decision = WindowDiscoveryEligibility.decision(for: WindowDiscoveryCandidateFacts(
            bundleIdentifier: "com.example.editor",
            rawTitle: "",
            axWindowID: 87,
            matchedCGWindowID: 87,
            role: kAXWindowRole as String,
            subrole: kAXStandardWindowSubrole as String,
            frame: CGRect(x: 20, y: 40, width: 900, height: 700),
            isMinimized: false
        ))

        #expect(decision == .include(reason: "includedAXWindowCGMatched"))
    }

    @Test("normal AX-only app window remains discoverable")
    func normalAXOnlyAppWindowRemainsDiscoverable() {
        let decision = WindowDiscoveryEligibility.decision(for: WindowDiscoveryCandidateFacts(
            bundleIdentifier: "com.example.axonly",
            rawTitle: "Preferences",
            axWindowID: nil,
            matchedCGWindowID: nil,
            role: kAXWindowRole as String,
            subrole: kAXStandardWindowSubrole as String,
            frame: CGRect(x: 120, y: 160, width: 640, height: 420),
            isMinimized: false
        ))

        #expect(decision == .include(reason: "includedAXWindowNoCGMatch"))
    }
}
