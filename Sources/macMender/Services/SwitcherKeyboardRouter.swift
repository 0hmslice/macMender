import CoreGraphics
import Foundation

private let escapeKeyCode: Int64 = 53

enum SwitcherKeyboardAction: Equatable {
    case showOrCycle(backwards: Bool)
    case commit
    case cancel
    case ignore
}

enum SwitcherKeyboardDecision: Equatable {
    case passThrough
    case consume(SwitcherKeyboardAction)
}

struct SwitcherKeyboardRouter {
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
            return switcherSessionActive ? .consume(.commit) : .passThrough
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
