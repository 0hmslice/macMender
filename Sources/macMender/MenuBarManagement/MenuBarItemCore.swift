import AppKit
import ApplicationServices
@preconcurrency import CoreGraphics
import Foundation

/// Ice-style stable status item names. macOS reports these windows through
/// Control Center, so code must match by title, not owner process.
enum MenuBarControlIdentifier {
    static let visible = "macMender.ControlItem.Visible"
    static let hidden = "macMender.ControlItem.Hidden"
    static let alwaysHidden = "macMender.ControlItem.AlwaysHidden"

    static func isControlTitle(_ title: String) -> Bool {
        title == visible || title == hidden || title == alwaysHidden
    }
}

/// Ice/Thaw-style stable identity for menu-bar items.
struct MenuBarItemIdentity: Hashable, CustomStringConvertible {
    struct Namespace: Hashable, RawRepresentable, CustomStringConvertible {
        var rawValue: String
        var description: String { rawValue }

        init(rawValue: String) {
            self.rawValue = rawValue
        }

        init(_ value: String?) {
            self.rawValue = value ?? "<null>"
        }
    }

    var namespace: Namespace
    var title: String
    var instanceIndex: Int = 0

    var description: String {
        if instanceIndex > 0 {
            return "\(namespace.rawValue):\(title):\(instanceIndex)"
        }
        return "\(namespace.rawValue):\(title)"
    }

    static let visibleControlItem = MenuBarItemIdentity(namespace: .macMenderApp, title: MenuBarControlIdentifier.visible)
    static let hiddenControlItem = MenuBarItemIdentity(namespace: .macMenderApp, title: MenuBarControlIdentifier.hidden)
    static let alwaysHiddenControlItem = MenuBarItemIdentity(namespace: .macMenderApp, title: MenuBarControlIdentifier.alwaysHidden)
    static let clock = MenuBarItemIdentity(namespace: .controlCenter, title: "Clock")
    static let siri = MenuBarItemIdentity(namespace: .systemUIServer, title: "Siri")
    static let controlCenterItem = MenuBarItemIdentity(namespace: .controlCenter, title: "BentoBox")
    static let audioVideoModule = MenuBarItemIdentity(namespace: .controlCenter, title: "AudioVideoModule")
    static let faceTime = MenuBarItemIdentity(namespace: .controlCenter, title: "FaceTime")
    static let musicRecognition = MenuBarItemIdentity(namespace: .controlCenter, title: "MusicRecognition")

    static let immovableItems: Set<MenuBarItemIdentity> = [
        .clock,
        .siri,
        .controlCenterItem
    ]

    static let nonHideableItems: Set<MenuBarItemIdentity> = [
        .audioVideoModule,
        .faceTime,
        .musicRecognition
    ]
}

extension MenuBarItemIdentity.Namespace {
    static let macMenderApp = Self(Bundle.main.bundleIdentifier ?? "com.ryan.macMender")
    static let controlCenter = Self("com.apple.controlcenter")
    static let systemUIServer = Self("com.apple.systemuiserver")
}

struct MenuBarWindowInfo: Hashable {
    var windowID: CGWindowID
    var frame: CGRect
    var title: String?
    var layer: Int
    var ownerPID: pid_t
    var sourcePID: pid_t?
    var ownerName: String?
    var isOnScreen: Bool

    var owningApplication: NSRunningApplication? {
        NSRunningApplication(processIdentifier: ownerPID)
    }

    var isMenuBarItem: Bool {
        layer == kCGStatusWindowLevel
    }

    init(
        windowID: CGWindowID,
        frame: CGRect,
        title: String?,
        layer: Int = Int(kCGStatusWindowLevel),
        ownerPID: pid_t,
        sourcePID: pid_t? = nil,
        ownerName: String?,
        isOnScreen: Bool = true
    ) {
        self.windowID = windowID
        self.frame = frame
        self.title = title
        self.layer = layer
        self.ownerPID = ownerPID
        self.sourcePID = sourcePID
        self.ownerName = ownerName
        self.isOnScreen = isOnScreen
    }

    init?(dictionary: [String: Any]) {
        guard let windowID = dictionary[kCGWindowNumber as String] as? CGWindowID,
              let bounds = dictionary[kCGWindowBounds as String] as? NSDictionary,
              let frame = CGRect(dictionaryRepresentation: bounds),
              let layer = dictionary[kCGWindowLayer as String] as? Int,
              let ownerPID = dictionary[kCGWindowOwnerPID as String] as? pid_t else {
            return nil
        }

        self.windowID = windowID
        self.frame = MenuBarPrivateBridge.frame(for: windowID) ?? frame
        self.title = dictionary[kCGWindowName as String] as? String
        self.layer = layer
        self.ownerPID = ownerPID
        self.sourcePID = nil
        self.ownerName = dictionary[kCGWindowOwnerName as String] as? String
        self.isOnScreen = dictionary[kCGWindowIsOnscreen as String] as? Bool ?? false
    }
}

struct MenuBarPhysicalItem: Identifiable, Hashable {
    var id: String { identity.description }
    var window: MenuBarWindowInfo
    var identity: MenuBarItemIdentity

    var windowID: CGWindowID { window.windowID }
    var frame: CGRect { window.frame }
    var ownerPID: pid_t { window.ownerPID }
    var eventTargetPID: pid_t { window.sourcePID ?? window.ownerPID }
    var sourcePID: pid_t? { window.sourcePID }
    var ownerName: String { window.owningApplication?.localizedName ?? window.ownerName ?? "Unknown" }
    var sourceApplication: NSRunningApplication? {
        window.sourcePID.flatMap(NSRunningApplication.init(processIdentifier:))
    }
    var bundleIdentifier: String? { inferredBundleIdentifier ?? sourceApplication?.bundleIdentifier ?? window.owningApplication?.bundleIdentifier }
    var title: String { window.title ?? "" }
    var isOnScreen: Bool { window.isOnScreen }
    var isOnActiveSpace: Bool { MenuBarPrivateBridge.isWindowOnActiveSpace(windowID) }
    var isMovable: Bool {
        !MenuBarItemIdentity.immovableItems.contains(identity) &&
            !title.hasPrefix("BentoBox")
    }
    var canBeHidden: Bool {
        !MenuBarItemIdentity.nonHideableItems.contains(identity) &&
            !isUnresolvedControlCenterHostItem
    }
    var isInternalControlItem: Bool { MenuBarControlIdentifier.isControlTitle(title) }

    init?(window: MenuBarWindowInfo) {
        guard window.isMenuBarItem else { return nil }
        self.window = window
        let namespaceSource = window.sourcePID.flatMap(NSRunningApplication.init(processIdentifier:))?.bundleIdentifier ??
            window.owningApplication?.bundleIdentifier
        self.identity = MenuBarItemIdentity(
            namespace: MenuBarItemIdentity.Namespace(namespaceSource),
            title: window.title ?? ""
        )
    }

    func withInstanceIndex(_ instanceIndex: Int) -> MenuBarPhysicalItem {
        var copy = self
        copy.identity.instanceIndex = instanceIndex
        return copy
    }

    init(controlWindow window: MenuBarWindowInfo) {
        self.window = window
        self.identity = MenuBarItemIdentity(
            namespace: .macMenderApp,
            title: window.title ?? ""
        )
    }

    private var isUnresolvedControlCenterHostItem: Bool {
        guard title.range(of: #"^Item-\d+$"#, options: .regularExpression) != nil else { return false }
        guard window.ownerName == "Control Center" || identity.namespace == .controlCenter else { return false }
        return sourcePID == nil || sourcePID == ownerPID
    }

    var displayName: String {
        let bestName = sourceApplication?.localizedName ??
            window.owningApplication?.localizedName ??
            window.ownerName ??
            sourceApplication?.bundleIdentifier ??
            window.owningApplication?.bundleIdentifier ??
            "Unknown"
        guard !title.isEmpty else { return bestName }

        switch identity.namespace {
        case .controlCenter:
            switch title {
            case "AccessibilityShortcuts": return "Accessibility Shortcuts"
            case "BentoBox": return bestName
            case "CombinedModules": return "Control Center Modules"
            case "FocusModes": return "Focus"
            case "KeyboardBrightness": return "Keyboard Brightness"
            case "MusicRecognition": return "Music Recognition"
            case "NowPlaying": return "Now Playing"
            case "ScreenMirroring": return "Screen Mirroring"
            case "StageManager": return "Stage Manager"
            case "UserSwitcher": return "Fast User Switching"
            case "WiFi": return "Wi-Fi"
            default: return title
            }
        case .systemUIServer:
            switch title {
            case "TimeMachine.TMMenuExtraHost", "TimeMachineMenuExtra.TMMenuExtraHost":
                return "Time Machine"
            default:
                return title
            }
        case MenuBarItemIdentity.Namespace("com.apple.Passwords.MenuBarExtra"):
            return "Passwords"
        default:
            if title.range(of: #"^Item-\d+$"#, options: .regularExpression) != nil {
                return bestName
            }
            if title.contains("."), !title.contains(" ") {
                return title.split(separator: ".").last.map(String.init) ?? bestName
            }
            return bestName
        }
    }

    private var inferredBundleIdentifier: String? {
        guard title.range(of: #"^[A-Za-z0-9_-]+(\.[A-Za-z0-9_-]+)+$"#, options: .regularExpression) != nil else {
            return nil
        }
        return title
    }

    private var detectedOwnerName: String {
        guard let inferredBundleIdentifier else { return ownerName }
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: inferredBundleIdentifier),
           let bundle = Bundle(url: url) {
            return (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String) ??
                (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String) ??
                url.deletingPathExtension().lastPathComponent
        }
        return inferredBundleIdentifier.split(separator: ".").last.map(String.init) ?? ownerName
    }

    func detectedItem(actualSection: MenuBarSection = .pinned) -> DetectedMenuBarItem {
        DetectedMenuBarItem(
            id: identity.description,
            windowID: windowID,
            ownerName: displayName,
            title: title,
            processIdentifier: ownerPID,
            sourceProcessIdentifier: sourcePID,
            sourceBundleIdentifier: bundleIdentifier,
            frame: frame,
            isPrivateWindowBacked: true,
            infoKey: identity.description,
            isMovableBySystem: isMovable,
            canBeHiddenBySystem: canBeHidden,
            actualSection: actualSection
        )
    }
}

struct DetectedMenuBarItem: Identifiable, Equatable {
    var id: String
    var windowID: CGWindowID
    var ownerName: String
    var title: String
    var processIdentifier: pid_t
    var sourceProcessIdentifier: pid_t?
    var sourceBundleIdentifier: String?
    var frame: CGRect
    var isPrivateWindowBacked: Bool = false
    var infoKey: String?
    var isMovableBySystem: Bool = true
    var canBeHiddenBySystem: Bool = true
    var actualSection: MenuBarSection = .pinned

    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if sourceBundleIdentifier == "com.apple.controlcenter" {
            switch trimmedTitle {
            case "AccessibilityShortcuts": return "Accessibility Shortcuts"
            case "BentoBox": return ownerName
            case "CombinedModules": return "Control Center Modules"
            case "FocusModes": return "Focus"
            case "KeyboardBrightness": return "Keyboard Brightness"
            case "MusicRecognition": return "Music Recognition"
            case "NowPlaying": return "Now Playing"
            case "ScreenMirroring": return "Screen Mirroring"
            case "StageManager": return "Stage Manager"
            case "UserSwitcher": return "Fast User Switching"
            case "WiFi": return "Wi-Fi"
            default: break
            }
        }
        if sourceBundleIdentifier == "com.apple.systemuiserver" {
            switch trimmedTitle {
            case "TimeMachine.TMMenuExtraHost", "TimeMachineMenuExtra.TMMenuExtraHost":
                return "Time Machine"
            default:
                break
            }
        }
        if sourceBundleIdentifier != "com.apple.controlcenter",
           ["CombinedModules", "Item-0"].contains(trimmedTitle),
           !ownerName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return ownerName
        }
        if trimmedTitle.range(of: #"^Item-\d+$"#, options: .regularExpression) != nil {
            return ownerName
        }
        if trimmedTitle.contains("."), !trimmedTitle.contains(" ") {
            return trimmedTitle.split(separator: ".").last.map(String.init) ?? ownerName
        }
        if !trimmedTitle.isEmpty { return trimmedTitle }
        return ownerName
    }

    var isInternalMacMenderItem: Bool {
        MenuBarControlIdentifier.isControlTitle(title) ||
            title.hasPrefix("macMender.") ||
            title.contains("macMender.OverflowDivider") ||
            title.contains("macMender.AlwaysHiddenDivider")
    }

    var sectionKey: String {
        infoKey ?? "\(sourceBundleIdentifier ?? ownerName):\(title)"
    }

    var isSystemManaged: Bool {
        !isHideCandidate
    }

    var isHideCandidate: Bool {
        isPrivateWindowBacked && isMovableBySystem && canBeHiddenBySystem && !isInternalMacMenderItem
    }

    var controllabilityDescription: String {
        if !isPrivateWindowBacked { return "Not exposed as a movable menu-bar item" }
        if !isMovableBySystem { return "Fixed by macOS" }
        if !canBeHiddenBySystem { return "Can move, but cannot be hidden reliably" }
        return "Can be moved into macMender sections"
    }
}

enum MenuBarLayoutSectionSource {
    static func displayedSection(for item: DetectedMenuBarItem) -> MenuBarSection {
        guard item.isHideCandidate else { return .pinned }
        return item.actualSection
    }

    static func isHiddenInLiveLayout(_ item: DetectedMenuBarItem) -> Bool {
        displayedSection(for: item) != .pinned
    }
}

struct MenuBarItemCache: Equatable {
    var visible: [MenuBarPhysicalItem] = []
    var hidden: [MenuBarPhysicalItem] = []
    var alwaysHidden: [MenuBarPhysicalItem] = []

    var allManaged: [MenuBarPhysicalItem] {
        visible + hidden + alwaysHidden
    }
}
