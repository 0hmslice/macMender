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
            #expect(SwitcherKeyboardRouter.decision(type: .flagsChanged, keyCode: 58, flags: [], shortcut: shortcut, switcherSessionActive: active) == (active ? .consume(.commit) : .passThrough))
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
