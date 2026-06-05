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
        screenRecording: PermissionState,
        inputMonitoring: PermissionState
    ) -> FeatureStatusSummary {
        if accessibility != .granted {
            return FeatureStatusSummary(
                title: "Needs Accessibility",
                detail: "Accessibility is required for shortcuts, Dock previews, and window actions.",
                kind: .needsAttention
            )
        }

        if screenRecording != .granted || inputMonitoring != .granted {
            return FeatureStatusSummary(
                title: "Ready with optional setup",
                detail: "Core helpers can run. Optional permissions improve thumbnails or listen-event diagnostics.",
                kind: .ready
            )
        }

        return FeatureStatusSummary(
            title: "Ready",
            detail: "Required and optional permissions are granted.",
            kind: .active
        )
    }

    static func screenRecordingSummary(_ state: PermissionState) -> FeatureStatusSummary {
        switch state {
        case .granted:
            FeatureStatusSummary(title: "Thumbnails available", detail: "Window thumbnails can be captured locally.", kind: .active)
        case .missing:
            FeatureStatusSummary(title: "Icon fallback", detail: "Dock previews and the switcher can fall back to app icons.", kind: .optional)
        case .unavailable:
            FeatureStatusSummary(title: "Unavailable", detail: "Window thumbnail capture is unavailable on this Mac.", kind: .optional)
        }
    }

    static func inputMonitoringSummary(_ state: PermissionState) -> FeatureStatusSummary {
        switch state {
        case .granted:
            FeatureStatusSummary(title: "Granted", detail: "macOS listen-event access is granted.", kind: .active)
        case .missing:
            FeatureStatusSummary(title: "Optional", detail: "Three-Finger Tap runtime status is tracked separately.", kind: .optional)
        case .unavailable:
            FeatureStatusSummary(title: "Unavailable", detail: "macOS listen-event access is unavailable.", kind: .optional)
        }
    }

    static func threeFingerTapStatus(
        settings: MiddleClickSettings,
        accessibility: PermissionState,
        safeModeEnabled: Bool,
        runtimeRunning: Bool
    ) -> FeatureStatusSummary {
        guard settings.enabled, settings.trigger == .experimentalThreeFinger else {
            return FeatureStatusSummary(title: "Off", detail: "Off in the active profile.", kind: .off)
        }
        guard accessibility == .granted else {
            return FeatureStatusSummary(title: "Needs Accessibility", detail: "Accessibility is required before middle-click actions can run.", kind: .needsAttention)
        }
        guard !safeModeEnabled else {
            return FeatureStatusSummary(title: "Paused", detail: "Paused by Safe Mode.", kind: .paused)
        }
        return runtimeRunning
            ? FeatureStatusSummary(title: "Active", detail: "Watching three-finger taps.", kind: .active)
            : FeatureStatusSummary(title: "Ready", detail: "Ready to start when the runtime is active.", kind: .ready)
    }

    static func dockPreviewStatus(
        settings: DockPreviewSettings,
        accessibility: PermissionState,
        safeModeEnabled: Bool,
        runtimeRunning: Bool
    ) -> FeatureStatusSummary {
        guard settings.enabled else {
            return FeatureStatusSummary(title: "Off", detail: "Off in the active profile.", kind: .off)
        }
        guard accessibility == .granted else {
            return FeatureStatusSummary(title: "Needs Accessibility", detail: "Accessibility is required to inspect Dock hover state.", kind: .needsAttention)
        }
        guard !safeModeEnabled else {
            return FeatureStatusSummary(title: "Paused", detail: "Paused by Safe Mode.", kind: .paused)
        }
        return runtimeRunning
            ? FeatureStatusSummary(title: "Active", detail: "Watching Dock item hover.", kind: .active)
            : FeatureStatusSummary(title: "Ready", detail: "Ready to watch Dock item hover.", kind: .ready)
    }

    static func windowSwitcherStatus(
        settings: WindowSwitcherSettings,
        featureEnabled: Bool,
        accessibility: PermissionState,
        safeModeEnabled: Bool
    ) -> FeatureStatusSummary {
        guard featureEnabled, settings.enabled else {
            return FeatureStatusSummary(title: "Off", detail: "Off in the active profile.", kind: .off)
        }
        guard accessibility == .granted else {
            return FeatureStatusSummary(title: "Needs Accessibility", detail: "Accessibility is required to switch windows.", kind: .needsAttention)
        }
        guard !safeModeEnabled else {
            return FeatureStatusSummary(title: "Paused", detail: "Paused by Safe Mode.", kind: .paused)
        }
        return FeatureStatusSummary(title: "Ready", detail: "Ready for Option+Tab.", kind: .active)
    }
}

struct PermissionSnapshot: Codable, Equatable {
    var accessibility: PermissionState
    var screenRecording: PermissionState
    var loginItem: PermissionState
}
