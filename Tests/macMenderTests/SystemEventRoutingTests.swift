import CoreGraphics
import Testing
@testable import macMender

@Suite("System Event Routing")
struct SystemEventRoutingTests {
    @Test("Escape passes through when Window Switcher is inactive")
    func escapePassesThroughWhenSwitcherInactive() throws {
        let shortcut = try #require(SwitcherShortcut("option+tab"))

        let decision = SwitcherKeyboardRouter.decision(
            type: .keyDown,
            keyCode: 53,
            flags: [],
            shortcut: shortcut,
            switcherSessionActive: false
        )

        #expect(decision == .passThrough)
    }

    @Test("Escape is consumed only to cancel an active Window Switcher")
    func escapeCancelsOnlyActiveSwitcherSession() throws {
        let shortcut = try #require(SwitcherShortcut("option+tab"))

        let activeDecision = SwitcherKeyboardRouter.decision(
            type: .keyDown,
            keyCode: 53,
            flags: [],
            shortcut: shortcut,
            switcherSessionActive: true
        )
        let inactiveDecision = SwitcherKeyboardRouter.decision(
            type: .keyDown,
            keyCode: 53,
            flags: [],
            shortcut: shortcut,
            switcherSessionActive: false
        )

        #expect(activeDecision == .consume(.cancel))
        #expect(inactiveDecision == .passThrough)
    }

    @Test("Unhandled keyboard events pass through by default")
    func unhandledKeyboardEventsPassThrough() throws {
        let shortcut = try #require(SwitcherShortcut("option+tab"))

        let decision = SwitcherKeyboardRouter.decision(
            type: .keyDown,
            keyCode: 0,
            flags: .maskAlternate,
            shortcut: shortcut,
            switcherSessionActive: false
        )

        #expect(decision == .passThrough)
    }

    @Test("Option Tab shortcut still consumes activation and commit events")
    func optionTabConsumesOnlyShortcutSessionEvents() throws {
        let shortcut = try #require(SwitcherShortcut("option+tab"))

        let openDecision = SwitcherKeyboardRouter.decision(
            type: .keyDown,
            keyCode: 48,
            flags: .maskAlternate,
            shortcut: shortcut,
            switcherSessionActive: false
        )
        let activeCommitDecision = SwitcherKeyboardRouter.decision(
            type: .keyUp,
            keyCode: 58,
            flags: [],
            shortcut: shortcut,
            switcherSessionActive: true
        )
        let inactiveModifierReleaseDecision = SwitcherKeyboardRouter.decision(
            type: .keyUp,
            keyCode: 58,
            flags: [],
            shortcut: shortcut,
            switcherSessionActive: false
        )

        #expect(openDecision == .consume(.showOrCycle))
        #expect(activeCommitDecision == .consume(.commit))
        #expect(inactiveModifierReleaseDecision == .passThrough)
    }

    @Test("Non-key event types pass through switcher routing")
    func nonKeyEventTypesPassThroughSwitcherRouting() throws {
        let shortcut = try #require(SwitcherShortcut("option+tab"))

        let decision = SwitcherKeyboardRouter.decision(
            type: .otherMouseDown,
            keyCode: 53,
            flags: [],
            shortcut: shortcut,
            switcherSessionActive: true
        )

        #expect(decision == .passThrough)
    }
}
