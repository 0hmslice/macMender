import CoreGraphics
import Foundation

private let escapeKeyCode: Int64 = 53

enum SwitcherKeyboardAction: Equatable {
    case showOrCycle(backwards: Bool)
    case commit
    case cancel
    case ignore
    /// Moves the selection by whole cards: `columns` sideways, `rows` up or down.
    case move(columns: Int, rows: Int)
    case closeSelected
    case minimizeSelected
}

enum SwitcherKeyboardDecision: Equatable {
    case passThrough
    case consume(SwitcherKeyboardAction)
    /// Act on the event and still deliver it. Used for the modifier's release: every app saw
    /// the modifier go down, so each must see it come up or it stays "held".
    case observe(SwitcherKeyboardAction)
}

struct SwitcherKeyboardRouter {
    private static let sessionCommands: [Int64: SwitcherKeyboardAction] = [
        123: .move(columns: -1, rows: 0),
        124: .move(columns: 1, rows: 0),
        125: .move(columns: 0, rows: 1),
        126: .move(columns: 0, rows: -1),
        13: .closeSelected,
        46: .minimizeSelected
    ]

    static func decision(
        type: CGEventType,
        keyCode: Int64,
        flags: CGEventFlags,
        shortcut: SwitcherShortcut,
        switcherSessionActive: Bool
    ) -> SwitcherKeyboardDecision {
        let shortcutHeld = shortcut.flags.allSatisfy { flags.contains($0) }

        let allowedFlags = shortcut.flags.reduce(CGEventFlags.maskShift) { $0.union($1) }
        let shortcutFlags: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
        let hasExtraModifier = !flags.intersection(shortcutFlags).subtracting(allowedFlags).isEmpty

        if type == .keyDown, keyCode == shortcut.keyCode, shortcutHeld, !hasExtraModifier {
            return .consume(.showOrCycle(backwards: flags.contains(.maskShift) && !shortcut.flags.contains(.maskShift)))
        }

        if type == .keyUp, keyCode == shortcut.keyCode, switcherSessionActive {
            return .consume(.ignore)
        }

        if (type == .keyUp || type == .flagsChanged), !shortcutHeld {
            guard switcherSessionActive else { return .passThrough }
            return type == .flagsChanged ? .observe(.commit) : .consume(.commit)
        }

        // While the switcher is open and the shortcut's modifier is held, a few more keys act on
        // the selection instead of reaching the app in front.
        if switcherSessionActive, shortcutHeld, let command = sessionCommands[keyCode] {
            return .consume(type == .keyDown ? command : .ignore)
        }

        if type == .keyDown, keyCode == escapeKeyCode {
            return switcherSessionActive ? .consume(.cancel) : .passThrough
        }

        return .passThrough
    }
}

struct SwitcherShortcut {
    var keyCode: Int64
    var flags: [CGEventFlags]
    var modifierKeyCodes: Set<CGKeyCode>

    init?(_ rawShortcut: String) {
        let tokens = rawShortcut
            .replacingOccurrences(of: " ", with: "")
            .split(separator: "+")
            .map { String($0).lowercased() }

        guard let keyToken = tokens.last else { return nil }

        switch keyToken {
        case "tab":
            keyCode = 48
        case "space":
            keyCode = 49
        case "escape", "esc":
            keyCode = escapeKeyCode
        default:
            return nil
        }

        var parsedFlags: [CGEventFlags] = []
        var parsedModifierKeys = Set<CGKeyCode>()

        for token in tokens.dropLast() {
            switch token {
            case "option", "alt":
                parsedFlags.append(.maskAlternate)
                parsedModifierKeys.formUnion([58, 61])
            case "control", "ctrl":
                parsedFlags.append(.maskControl)
                parsedModifierKeys.formUnion([59, 62])
            case "command", "cmd":
                parsedFlags.append(.maskCommand)
                parsedModifierKeys.formUnion([55, 54])
            case "shift":
                parsedFlags.append(.maskShift)
                parsedModifierKeys.formUnion([56, 60])
            default:
                return nil
            }
        }

        guard !parsedFlags.isEmpty else { return nil }
        flags = parsedFlags
        modifierKeyCodes = parsedModifierKeys
    }
}
