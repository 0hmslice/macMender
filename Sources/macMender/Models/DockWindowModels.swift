import Foundation

struct DockAppIdentity: Equatable {
    var title: String
    var bundleIdentifier: String?
    var processIdentifier: pid_t?
    /// The Dock tile of one minimized window rather than an application icon; `title` is the window's title.
    var isMinimizedWindow = false

    /// Whether two identities name the same Dock tile, ignoring details that change while it stays put.
    func isSameDockItem(as other: DockAppIdentity) -> Bool {
        guard isMinimizedWindow == other.isMinimizedWindow else { return false }
        if isMinimizedWindow { return title == other.title }
        if let bundleIdentifier, let otherBundleIdentifier = other.bundleIdentifier {
            return bundleIdentifier == otherBundleIdentifier
        }
        return self == other
    }

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

enum DockPreviewAnimationStyle: String, CaseIterable, Codable, Identifiable {
    case system
    case fade
    case scale
    case slideUp
    case glassPop
    case genie
    case none

    var id: String { rawValue }

    static let selectableCases: [DockPreviewAnimationStyle] = [
        .system,
        .fade,
        .scale,
        .slideUp,
        .none
    ]

    var legacyMappedStyle: DockPreviewAnimationStyle {
        switch self {
        case .glassPop:
            return .system
        case .genie:
            return .scale
        case .system, .fade, .scale, .slideUp, .none:
            return self
        }
    }

    var title: String {
        switch self {
        case .system: "System"
        case .fade: "Fade"
        case .scale: "Scale"
        case .slideUp: "Slide"
        case .glassPop: "Glass Pop"
        case .genie: "Genie"
        case .none: "None"
        }
    }
}

enum DockPreviewAnimationSpeed: String, CaseIterable, Codable, Identifiable {
    case snappy
    case balanced
    case smooth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .snappy: "Snappy"
        case .balanced: "Balanced"
        case .smooth: "Smooth"
        }
    }

    var duration: TimeInterval {
        switch self {
        case .snappy: 0.08
        case .balanced: 0.22
        case .smooth: 0.42
        }
    }
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
    /// Seconds the pointer rests on a Dock icon before its preview appears.
    var hoverDelay: Double
    /// Seconds the preview stays after the pointer leaves it and its Dock icon.
    var dismissDelay: Double
    var animationStyle: DockPreviewAnimationStyle
    var animationDuration: Double
    /// Thumbnail height in points.
    var previewSize: Double
    var showTitles: Bool
    var showWindowControls: Bool
    var livePreviews: Bool
    var includeMinimizedWindows: Bool
    var includeHiddenApps: Bool
    var includeOtherSpaces: Bool
    /// Show the window at full size after the pointer rests on its card.
    var peekOnHover: Bool
    /// Arrow keys, Return, and Escape act on the preview while the pointer is over it.
    var keyboardNavigation: Bool

    enum CodingKeys: String, CodingKey {
        case enabled
        case hoverDelay
        case dismissDelay
        case animationStyle
        case animationDuration
        case animationSpeed
        case previewSize
        case showTitles
        case showWindowControls
        case livePreviews
        case includeMinimizedWindows
        case includeHiddenApps
        case includeOtherSpaces
        case peekOnHover
        case keyboardNavigation
    }

    init(
        enabled: Bool = true,
        hoverDelay: Double = Self.defaultHoverDelay,
        dismissDelay: Double = Self.defaultDismissDelay,
        animationStyle: DockPreviewAnimationStyle = .system,
        animationDuration: Double = Self.defaultAnimationDuration,
        previewSize: Double = Self.defaultPreviewSize,
        showTitles: Bool = true,
        showWindowControls: Bool = true,
        livePreviews: Bool = true,
        includeMinimizedWindows: Bool = true,
        includeHiddenApps: Bool = true,
        includeOtherSpaces: Bool = true,
        peekOnHover: Bool = true,
        keyboardNavigation: Bool = true
    ) {
        self.enabled = enabled
        self.hoverDelay = Self.clampedHoverDelay(hoverDelay)
        self.dismissDelay = Self.clampedDismissDelay(dismissDelay)
        self.animationStyle = animationStyle
        self.animationDuration = Self.clampedAnimationDuration(animationDuration)
        self.previewSize = Self.clampedPreviewSize(previewSize)
        self.showTitles = showTitles
        self.showWindowControls = showWindowControls
        self.livePreviews = livePreviews
        self.includeMinimizedWindows = includeMinimizedWindows
        self.includeHiddenApps = includeHiddenApps
        self.includeOtherSpaces = includeOtherSpaces
        self.peekOnHover = peekOnHover
        self.keyboardNavigation = keyboardNavigation
    }

    /// Values saved by earlier versions decode cleanly: retired keys (`previewIdleTimeout`,
    /// `layout`, `thumbnailSize`) are ignored and new keys take their defaults.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = DockPreviewSettings()
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? fallback.enabled
        hoverDelay = Self.clampedHoverDelay(try container.decodeIfPresent(Double.self, forKey: .hoverDelay) ?? fallback.hoverDelay)
        dismissDelay = Self.clampedDismissDelay(try container.decodeIfPresent(Double.self, forKey: .dismissDelay) ?? fallback.dismissDelay)
        animationStyle = (try container.decodeIfPresent(DockPreviewAnimationStyle.self, forKey: .animationStyle) ?? fallback.animationStyle).legacyMappedStyle
        if let duration = try container.decodeIfPresent(Double.self, forKey: .animationDuration) {
            animationDuration = Self.clampedAnimationDuration(duration)
        } else if let legacySpeed = try container.decodeIfPresent(DockPreviewAnimationSpeed.self, forKey: .animationSpeed) {
            animationDuration = Self.clampedAnimationDuration(legacySpeed.duration)
        } else {
            animationDuration = fallback.animationDuration
        }
        previewSize = Self.clampedPreviewSize(try container.decodeIfPresent(Double.self, forKey: .previewSize) ?? fallback.previewSize)
        showTitles = try container.decodeIfPresent(Bool.self, forKey: .showTitles) ?? fallback.showTitles
        showWindowControls = try container.decodeIfPresent(Bool.self, forKey: .showWindowControls) ?? fallback.showWindowControls
        livePreviews = try container.decodeIfPresent(Bool.self, forKey: .livePreviews) ?? fallback.livePreviews
        includeMinimizedWindows = try container.decodeIfPresent(Bool.self, forKey: .includeMinimizedWindows) ?? fallback.includeMinimizedWindows
        includeHiddenApps = try container.decodeIfPresent(Bool.self, forKey: .includeHiddenApps) ?? fallback.includeHiddenApps
        includeOtherSpaces = try container.decodeIfPresent(Bool.self, forKey: .includeOtherSpaces) ?? fallback.includeOtherSpaces
        peekOnHover = try container.decodeIfPresent(Bool.self, forKey: .peekOnHover) ?? fallback.peekOnHover
        keyboardNavigation = try container.decodeIfPresent(Bool.self, forKey: .keyboardNavigation) ?? fallback.keyboardNavigation
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(enabled, forKey: .enabled)
        try container.encode(hoverDelay, forKey: .hoverDelay)
        try container.encode(dismissDelay, forKey: .dismissDelay)
        try container.encode(animationStyle, forKey: .animationStyle)
        try container.encode(animationDuration, forKey: .animationDuration)
        try container.encode(previewSize, forKey: .previewSize)
        try container.encode(showTitles, forKey: .showTitles)
        try container.encode(showWindowControls, forKey: .showWindowControls)
        try container.encode(livePreviews, forKey: .livePreviews)
        try container.encode(includeMinimizedWindows, forKey: .includeMinimizedWindows)
        try container.encode(includeHiddenApps, forKey: .includeHiddenApps)
        try container.encode(includeOtherSpaces, forKey: .includeOtherSpaces)
        try container.encode(peekOnHover, forKey: .peekOnHover)
        try container.encode(keyboardNavigation, forKey: .keyboardNavigation)
    }

    static let `default` = DockPreviewSettings()
    static let compact = DockPreviewSettings(hoverDelay: 0.2, previewSize: 112)
    static let presentation = DockPreviewSettings(hoverDelay: 0.4, animationDuration: 0.24, previewSize: 184)

    static let defaultHoverDelay = 0.25
    static let defaultDismissDelay = 0.25
    static let defaultAnimationDuration = 0.18
    static let defaultPreviewSize = 150.0
    static let previewSizeRange = 90.0...260.0
    static let hoverDelayRange = 0.0...1.2
    static let dismissDelayRange = 0.1...2.0
    static let animationDurationRange = 0.05...0.60

    /// Defaults shipped before the preview rebuild, used to move untouched settings forward.
    static let legacyDefaultHoverDelay = 0.35
    static let legacyDefaultAnimationDuration = 0.22

    static func clampedHoverDelay(_ value: Double) -> Double {
        min(max(value, hoverDelayRange.lowerBound), hoverDelayRange.upperBound)
    }

    static func clampedDismissDelay(_ value: Double) -> Double {
        min(max(value, dismissDelayRange.lowerBound), dismissDelayRange.upperBound)
    }

    static func clampedAnimationDuration(_ value: Double) -> Double {
        min(max(value, animationDurationRange.lowerBound), animationDurationRange.upperBound)
    }

    static func clampedPreviewSize(_ value: Double) -> Double {
        min(max(value, previewSizeRange.lowerBound), previewSizeRange.upperBound)
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
