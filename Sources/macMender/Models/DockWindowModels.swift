import Foundation

struct DockAppIdentity: Equatable {
    var title: String
    var bundleIdentifier: String?
    var processIdentifier: pid_t?

    var displayName: String {
        title.isEmpty ? (bundleIdentifier ?? "Unknown App") : title
    }

    var hasResolvedApplicationIdentity: Bool {
        bundleIdentifier != nil || processIdentifier != nil
    }
}

enum SwitcherLayout: String, CaseIterable, Codable, Identifiable {
    case strip
    case grid

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct WindowSwitcherSettings: Codable, Equatable {
    var enabled: Bool
    var shortcut: String
    var layout: SwitcherLayout
    var thumbnailSize: Double
    var includeMinimizedWindows: Bool
    var includeHiddenApps: Bool

    static let `default` = WindowSwitcherSettings(
        enabled: true,
        shortcut: "Option+Tab",
        layout: .grid,
        thumbnailSize: 180,
        includeMinimizedWindows: true,
        includeHiddenApps: false
    )

    static let compact = WindowSwitcherSettings(
        enabled: true,
        shortcut: "Option+Tab",
        layout: .grid,
        thumbnailSize: 132,
        includeMinimizedWindows: false,
        includeHiddenApps: false
    )

    static let presentation = WindowSwitcherSettings(
        enabled: true,
        shortcut: "Option+Tab",
        layout: .grid,
        thumbnailSize: 180,
        includeMinimizedWindows: true,
        includeHiddenApps: false
    )
}

struct DockPreviewSettings: Codable, Equatable {
    var enabled: Bool
    var hoverDelay: Double
    var previewIdleTimeout: Double
    var layout: SwitcherLayout
    var thumbnailSize: Double

    enum CodingKeys: String, CodingKey {
        case enabled
        case hoverDelay
        case previewIdleTimeout
        case layout
        case thumbnailSize
    }

    init(
        enabled: Bool,
        hoverDelay: Double,
        previewIdleTimeout: Double,
        layout: SwitcherLayout,
        thumbnailSize: Double
    ) {
        self.enabled = enabled
        self.hoverDelay = hoverDelay
        self.previewIdleTimeout = Self.clampedPreviewIdleTimeout(previewIdleTimeout)
        self.layout = layout
        self.thumbnailSize = thumbnailSize
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = DockPreviewSettings.default
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? fallback.enabled
        hoverDelay = try container.decodeIfPresent(Double.self, forKey: .hoverDelay) ?? fallback.hoverDelay
        previewIdleTimeout = Self.clampedPreviewIdleTimeout(
            try container.decodeIfPresent(Double.self, forKey: .previewIdleTimeout) ?? fallback.previewIdleTimeout
        )
        layout = try container.decodeIfPresent(SwitcherLayout.self, forKey: .layout) ?? fallback.layout
        thumbnailSize = try container.decodeIfPresent(Double.self, forKey: .thumbnailSize) ?? fallback.thumbnailSize
    }

    static let `default` = DockPreviewSettings(
        enabled: true,
        hoverDelay: 0.35,
        previewIdleTimeout: 1.0,
        layout: .grid,
        thumbnailSize: 152
    )

    static let compact = DockPreviewSettings(
        enabled: true,
        hoverDelay: 0.2,
        previewIdleTimeout: 0.8,
        layout: .grid,
        thumbnailSize: 132
    )

    static let presentation = DockPreviewSettings(
        enabled: true,
        hoverDelay: 0.45,
        previewIdleTimeout: 1.4,
        layout: .grid,
        thumbnailSize: 180
    )

    static func clampedPreviewIdleTimeout(_ value: Double) -> Double {
        min(max(value, 0.3), 5.0)
    }

    func overlaySettings(using base: WindowSwitcherSettings) -> WindowSwitcherSettings {
        WindowSwitcherSettings(
            enabled: enabled,
            shortcut: base.shortcut,
            layout: layout,
            thumbnailSize: thumbnailSize,
            includeMinimizedWindows: base.includeMinimizedWindows,
            includeHiddenApps: base.includeHiddenApps
        )
    }
}

enum DockPosition: String, CaseIterable, Codable, Identifiable {
    case left
    case bottom
    case right

    var id: String { rawValue }
    var title: String { rawValue.capitalized }
}

struct DockSettings: Codable, Equatable {
    var size: Double
    var magnificationEnabled: Bool
    var magnificationSize: Double
    var position: DockPosition
    var autoHide: Bool
    var autoHideDelay: Double
    var autoHideAnimationSpeed: Double
    var showRecentApps: Bool
    var showIndicators: Bool

    static let work = DockSettings(size: 52, magnificationEnabled: true, magnificationSize: 74, position: .bottom, autoHide: false, autoHideDelay: 0.2, autoHideAnimationSpeed: 0.35, showRecentApps: true, showIndicators: true)
    static let minimal = DockSettings(size: 38, magnificationEnabled: false, magnificationSize: 58, position: .bottom, autoHide: true, autoHideDelay: 0, autoHideAnimationSpeed: 0.18, showRecentApps: false, showIndicators: true)
    static let gaming = DockSettings(size: 42, magnificationEnabled: false, magnificationSize: 58, position: .bottom, autoHide: true, autoHideDelay: 0, autoHideAnimationSpeed: 0.12, showRecentApps: false, showIndicators: true)
    static let presentation = DockSettings(size: 48, magnificationEnabled: false, magnificationSize: 64, position: .bottom, autoHide: true, autoHideDelay: 0.1, autoHideAnimationSpeed: 0.25, showRecentApps: false, showIndicators: false)
}
