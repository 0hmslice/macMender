import Foundation

enum PermissionState: String, Codable {
    case granted
    case missing
    case unavailable

    var title: String {
        switch self {
        case .granted: "Granted"
        case .missing: "Needs Access"
        case .unavailable: "Unavailable"
        }
    }
}

enum FeatureStatusKind: Equatable {
    case active
    case ready
    case paused
    case off
    case needsAttention
    case optional
}

struct FeatureStatusSummary: Equatable {
    var title: String
    var detail: String
    var kind: FeatureStatusKind
}

enum PermissionStatusPolicy {
    static func needsAttention(accessibility: PermissionState) -> Bool {
        accessibility != .granted
    }

    static func requiredPermissionNames(accessibility: PermissionState) -> [String] {
        accessibility == .granted ? [] : ["Accessibility"]
    }

    static func permissionsSummary(
        accessibility: PermissionState,
        screenRecording: PermissionState
    ) -> FeatureStatusSummary {
        if accessibility != .granted {
            return FeatureStatusSummary(
                title: "Needs Accessibility",
                detail: "Accessibility is required for shortcuts, Dock previews, and window actions.",
                kind: .needsAttention
            )
        }

        if screenRecording != .granted {
            return FeatureStatusSummary(
                title: "Ready with optional setup",
                detail: "Screen Recording is off, so previews show app icons instead of windows.",
                kind: .ready
            )
        }

        return FeatureStatusSummary(
            title: "Ready",
            detail: "Everything macMender needs is allowed.",
            kind: .active
        )
    }

    static func threeFingerTapStatus(
        settings: MiddleClickSettings,
        accessibility: PermissionState,
        safeModeEnabled: Bool,
        runtimeRunning: Bool
    ) -> FeatureStatusSummary {
        guard settings.enabled, settings.trigger == .experimentalThreeFinger else {
            return FeatureStatusSummary(title: "Off", detail: "Turned off.", kind: .off)
        }
        guard accessibility == .granted else {
            return FeatureStatusSummary(title: "Needs Accessibility", detail: "Needs Accessibility access to middle-click.", kind: .needsAttention)
        }
        guard !safeModeEnabled else {
            return FeatureStatusSummary(title: "Paused", detail: "macMender is paused.", kind: .paused)
        }
        return runtimeRunning
            ? FeatureStatusSummary(title: "Active", detail: "Tap the trackpad with three fingers to middle-click.", kind: .active)
            : FeatureStatusSummary(title: "Ready", detail: "Starting up.", kind: .ready)
    }

    static func dockPreviewStatus(
        settings: DockPreviewSettings,
        accessibility: PermissionState,
        safeModeEnabled: Bool,
        runtimeRunning: Bool
    ) -> FeatureStatusSummary {
        guard settings.enabled else {
            return FeatureStatusSummary(title: "Off", detail: "Turned off.", kind: .off)
        }
        guard accessibility == .granted else {
            return FeatureStatusSummary(title: "Needs Accessibility", detail: "Needs Accessibility access to see the Dock.", kind: .needsAttention)
        }
        guard !safeModeEnabled else {
            return FeatureStatusSummary(title: "Paused", detail: "macMender is paused.", kind: .paused)
        }
        return runtimeRunning
            ? FeatureStatusSummary(title: "Active", detail: "Hover a Dock icon to see its windows.", kind: .active)
            : FeatureStatusSummary(title: "Ready", detail: "Starting up.", kind: .ready)
    }

    static func windowSwitcherStatus(
        settings: WindowSwitcherSettings,
        featureEnabled: Bool,
        accessibility: PermissionState,
        safeModeEnabled: Bool
    ) -> FeatureStatusSummary {
        guard featureEnabled, settings.enabled else {
            return FeatureStatusSummary(title: "Off", detail: "Turned off.", kind: .off)
        }
        guard accessibility == .granted else {
            return FeatureStatusSummary(title: "Needs Accessibility", detail: "Needs Accessibility access to switch windows.", kind: .needsAttention)
        }
        guard !safeModeEnabled else {
            return FeatureStatusSummary(title: "Paused", detail: "macMender is paused.", kind: .paused)
        }
        return FeatureStatusSummary(title: "Ready", detail: "Press \(settings.shortcut.replacingOccurrences(of: "Option+", with: "⌥ ").replacingOccurrences(of: "Control+", with: "⌃ ")) to switch windows.", kind: .active)
    }
}

struct PermissionSnapshot: Codable, Equatable {
    var accessibility: PermissionState
    var screenRecording: PermissionState
    var loginItem: PermissionState
}
