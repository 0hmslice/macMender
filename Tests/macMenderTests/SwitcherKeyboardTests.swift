import CoreGraphics
import Testing
@testable import macMender

struct SwitcherKeyboardTests {
    private let shortcut = SwitcherShortcut("Option+Tab")!

    @Test func shiftReversesCycling() {
        #expect(SwitcherKeyboardRouter.decision(type: .keyDown, keyCode: 48, flags: [.maskAlternate, .maskShift], shortcut: shortcut, switcherSessionActive: true) == .consume(.showOrCycle(backwards: true)))
        #expect(SwitcherKeyboardRouter.decision(type: .keyDown, keyCode: 48, flags: .maskAlternate, shortcut: shortcut, switcherSessionActive: false) == .consume(.showOrCycle(backwards: false)))
    }

    @Test func unrelatedShortcutsPassThrough() {
        #expect(SwitcherKeyboardRouter.decision(type: .keyDown, keyCode: 48, flags: [.maskAlternate, .maskCommand], shortcut: shortcut, switcherSessionActive: false) == .passThrough)
    }

    @Test func shortcutKeyUpDoesNotLeakToApps() {
        #expect(SwitcherKeyboardRouter.decision(type: .keyUp, keyCode: 48, flags: .maskAlternate, shortcut: shortcut, switcherSessionActive: true) == .consume(.ignore))
    }

    @Test func releaseAndEscapeOnlyConsumeActiveSessions() {
        for active in [true, false] {
            // The modifier's release switches windows and is still delivered, so no app is left
            // believing the modifier is held.
            #expect(SwitcherKeyboardRouter.decision(type: .flagsChanged, keyCode: 58, flags: [], shortcut: shortcut, switcherSessionActive: active) == (active ? .observe(.commit) : .passThrough))
            #expect(SwitcherKeyboardRouter.decision(type: .keyDown, keyCode: 53, flags: [], shortcut: shortcut, switcherSessionActive: active) == (active ? .consume(.cancel) : .passThrough))
        }
    }

    @Test func releasingShiftKeepsOptionSessionOpen() {
        #expect(SwitcherKeyboardRouter.decision(type: .flagsChanged, keyCode: 56, flags: .maskAlternate, shortcut: shortcut, switcherSessionActive: true) == .passThrough)
    }

    @Test func invalidShortcutsAreRejected() {
        #expect(SwitcherShortcut("Tab") == nil)
        #expect(SwitcherShortcut("Option+Unknown") == nil)
        #expect(SwitcherShortcut("Bogus+Tab") == nil)
    }
}

struct SwitcherSessionKeyTests {
    private let shortcut = SwitcherShortcut("Option+Tab")!

    private func decision(_ type: CGEventType, _ keyCode: Int64, flags: CGEventFlags = .maskAlternate, active: Bool = true) -> SwitcherKeyboardDecision {
        SwitcherKeyboardRouter.decision(type: type, keyCode: keyCode, flags: flags, shortcut: shortcut, switcherSessionActive: active)
    }

    @Test func arrowsAndWindowKeysActOnTheSelectionWhileOpen() {
        #expect(decision(.keyDown, 123) == .consume(.move(columns: -1, rows: 0)))
        #expect(decision(.keyDown, 124) == .consume(.move(columns: 1, rows: 0)))
        #expect(decision(.keyDown, 125) == .consume(.move(columns: 0, rows: 1)))
        #expect(decision(.keyDown, 126) == .consume(.move(columns: 0, rows: -1)))
        #expect(decision(.keyDown, 13) == .consume(.closeSelected))
        #expect(decision(.keyDown, 46) == .consume(.minimizeSelected))
    }

    @Test func thoseKeysReachAppsWhenTheSwitcherIsClosed() {
        for keyCode: Int64 in [123, 124, 125, 126, 13, 46] {
            #expect(decision(.keyDown, keyCode, active: false) == .passThrough)
        }
    }

    @Test func theirKeyUpsDoNotLeakWhileOpen() {
        #expect(decision(.keyUp, 13) == .consume(.ignore))
    }
}
