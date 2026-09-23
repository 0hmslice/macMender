import Foundation

enum SmoothingPreset: String, CaseIterable, Codable, Identifiable {
    case off
    case subtle
    case balanced
    case smooth
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .off: "Off"
        case .subtle: "Subtle"
        case .balanced: "Balanced"
        case .smooth: "Smooth"
        case .custom: "Custom"
        }
    }
}

enum DeviceKind: String, CaseIterable, Codable, Identifiable {
    case builtInTrackpad
    case magicTrackpad
    case magicMouse
    case externalMouse
    case unknown

    var id: String { rawValue }

    var title: String {
        switch self {
        case .builtInTrackpad: "Built-in Trackpad"
        case .magicTrackpad: "Magic Trackpad"
        case .magicMouse: "Magic Mouse"
        case .externalMouse: "External Mouse"
        case .unknown: "Unknown Device"
        }
    }
}

struct ScrollSettings: Codable, Equatable {
    var preset: SmoothingPreset
    var verticalSmoothingEnabled: Bool
    var horizontalSmoothingEnabled: Bool
    var reverseVertical: Bool
    var reverseHorizontal: Bool
    var step: Double
    var gain: Double
    var duration: Double
    var deviceRules: [DeviceScrollRule]
    var appRules: [AppScrollRule]

    static let raw = ScrollSettings(
        preset: .off,
        verticalSmoothingEnabled: false,
        horizontalSmoothingEnabled: false,
        reverseVertical: false,
        reverseHorizontal: false,
        step: 1,
        gain: 1,
        duration: 0,
        deviceRules: DeviceScrollRule.defaults,
        appRules: []
    )

    static let subtle = ScrollSettings(
        preset: .subtle,
        verticalSmoothingEnabled: true,
        horizontalSmoothingEnabled: false,
        reverseVertical: false,
        reverseHorizontal: false,
        step: 1,
        gain: 1.05,
        duration: 0.10,
        deviceRules: DeviceScrollRule.defaults,
        appRules: []
    )

    static let balanced = ScrollSettings(
        preset: .balanced,
        verticalSmoothingEnabled: true,
        horizontalSmoothingEnabled: true,
        reverseVertical: false,
        reverseHorizontal: false,
        step: 1,
        gain: 1.18,
        duration: 0.16,
        deviceRules: DeviceScrollRule.defaults,
        appRules: [
            AppScrollRule(bundleIdentifier: "com.apple.Terminal", appName: "Terminal", smoothingOverride: false, reverseVerticalOverride: nil)
        ]
    )
}

struct DeviceScrollRule: Identifiable, Codable, Equatable {
    var id: UUID
    var deviceKind: DeviceKind
    var displayName: String
    var reverseVertical: Bool
    var reverseHorizontal: Bool
    var smoothingEnabled: Bool
    var isPhysicalDeviceSpecific: Bool

    static let defaults: [DeviceScrollRule] = [
        DeviceScrollRule(id: UUID(), deviceKind: .builtInTrackpad, displayName: "Built-in Trackpad", reverseVertical: false, reverseHorizontal: false, smoothingEnabled: false, isPhysicalDeviceSpecific: false),
        DeviceScrollRule(id: UUID(), deviceKind: .externalMouse, displayName: "External Mouse", reverseVertical: true, reverseHorizontal: false, smoothingEnabled: true, isPhysicalDeviceSpecific: false),
        DeviceScrollRule(id: UUID(), deviceKind: .magicMouse, displayName: "Magic Mouse", reverseVertical: false, reverseHorizontal: false, smoothingEnabled: true, isPhysicalDeviceSpecific: false)
    ]
}

struct AppScrollRule: Identifiable, Codable, Equatable {
    var id: UUID
    var bundleIdentifier: String
    var appName: String
    var smoothingOverride: Bool?
    var reverseVerticalOverride: Bool?
    var reverseHorizontalOverride: Bool?
    var bypassScrolling: Bool

    init(
        id: UUID = UUID(),
        bundleIdentifier: String,
        appName: String,
        smoothingOverride: Bool?,
        reverseVerticalOverride: Bool?,
        reverseHorizontalOverride: Bool? = nil,
        bypassScrolling: Bool = false
    ) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.smoothingOverride = smoothingOverride
        self.reverseVerticalOverride = reverseVerticalOverride
        self.reverseHorizontalOverride = reverseHorizontalOverride
        self.bypassScrolling = bypassScrolling
    }

    private enum CodingKeys: String, CodingKey {
        case id, bundleIdentifier, appName, smoothingOverride
        case reverseVerticalOverride, reverseHorizontalOverride, bypassScrolling
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        bundleIdentifier = try values.decode(String.self, forKey: .bundleIdentifier)
        appName = try values.decode(String.self, forKey: .appName)
        smoothingOverride = try values.decodeIfPresent(Bool.self, forKey: .smoothingOverride)
        reverseVerticalOverride = try values.decodeIfPresent(Bool.self, forKey: .reverseVerticalOverride)
        reverseHorizontalOverride = try values.decodeIfPresent(Bool.self, forKey: .reverseHorizontalOverride)
        bypassScrolling = try values.decodeIfPresent(Bool.self, forKey: .bypassScrolling) ?? false
    }
}

enum MiddleClickTrigger: String, CaseIterable, Codable, Identifiable {
    case disabled
    case modifierClick
    case extraMouseButton
    case experimentalThreeFinger

    var id: String { rawValue }

    var title: String {
        switch self {
        case .disabled: "Disabled"
        case .modifierClick: "Control + Click"
        case .extraMouseButton: "Extra Mouse Button"
        case .experimentalThreeFinger: "Three-Finger Tap"
        }
    }

    static let runtimeSupportedCases: [MiddleClickTrigger] = [
        .modifierClick,
        .extraMouseButton,
        .experimentalThreeFinger
    ]
}

enum MiddleClickAction: String, CaseIterable, Codable, Identifiable {
    case middleClick
    case openBackgroundTab
    case closeTab
    case customShortcut

    var id: String { rawValue }

    var title: String {
        switch self {
        case .middleClick: "Middle Click"
        case .openBackgroundTab: "Open Background Tab"
        case .closeTab: "Close Tab"
        case .customShortcut: "Middle Click"
        }
    }

    static let runtimeSupportedCases: [MiddleClickAction] = [
        .middleClick,
        .openBackgroundTab,
        .closeTab
    ]
}

struct MiddleClickSettings: Codable, Equatable {
    var enabled: Bool
    var trigger: MiddleClickTrigger
    var action: MiddleClickAction

    static let `default` = MiddleClickSettings(enabled: true, trigger: .experimentalThreeFinger, action: .middleClick)
    static let disabled = MiddleClickSettings(enabled: false, trigger: .disabled, action: .middleClick)
}
