import Foundation

struct AppConfig: Codable, Equatable {
    var schemaVersion: Int
    var hasCompletedOnboarding: Bool
    var activeProfileID: UUID
    var safeModeEnabled: Bool
    var featureToggles: FeatureToggles
    var appBehavior: AppBehavior
    var profiles: [MacMenderProfile]

    enum CodingKeys: String, CodingKey {
        case schemaVersion
        case hasCompletedOnboarding
        case activeProfileID
        case safeModeEnabled
        case featureToggles
        case appBehavior
        case profiles
    }

    init(
        schemaVersion: Int,
        hasCompletedOnboarding: Bool,
        activeProfileID: UUID,
        safeModeEnabled: Bool,
        featureToggles: FeatureToggles,
        appBehavior: AppBehavior,
        profiles: [MacMenderProfile]
    ) {
        self.schemaVersion = schemaVersion
        self.hasCompletedOnboarding = hasCompletedOnboarding
        self.activeProfileID = activeProfileID
        self.safeModeEnabled = safeModeEnabled
        self.featureToggles = featureToggles
        self.appBehavior = appBehavior
        self.profiles = profiles
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let fallback = AppConfig.default
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        hasCompletedOnboarding = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? false
        activeProfileID = try container.decodeIfPresent(UUID.self, forKey: .activeProfileID) ?? fallback.activeProfileID
        safeModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .safeModeEnabled) ?? fallback.safeModeEnabled
        featureToggles = try container.decodeIfPresent(FeatureToggles.self, forKey: .featureToggles) ?? fallback.featureToggles
        appBehavior = try container.decodeIfPresent(AppBehavior.self, forKey: .appBehavior) ?? fallback.appBehavior
        profiles = try container.decodeIfPresent([MacMenderProfile].self, forKey: .profiles) ?? fallback.profiles
    }

    static var `default`: AppConfig {
        let defaultProfile = MacMenderProfile.default
        return AppConfig(
            schemaVersion: 5,
            hasCompletedOnboarding: false,
            activeProfileID: defaultProfile.id,
            safeModeEnabled: false,
            featureToggles: .default,
            appBehavior: .default,
            profiles: [defaultProfile]
        )
    }
}

struct AppBehavior: Codable, Equatable {
    var hideDockIcon: Bool
    var menuBarSpacing: MenuBarSpacingPreference
    var menuBarSpacingCustomValue: Int

    enum CodingKeys: String, CodingKey {
        case hideDockIcon
        case menuBarSpacing
        case menuBarSpacingCustomValue
    }

    init(hideDockIcon: Bool, menuBarSpacing: MenuBarSpacingPreference, menuBarSpacingCustomValue: Int) {
        self.hideDockIcon = hideDockIcon
        self.menuBarSpacing = menuBarSpacing
        self.menuBarSpacingCustomValue = MenuBarSpacingPreference.clampedValue(menuBarSpacingCustomValue)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hideDockIcon = try container.decodeIfPresent(Bool.self, forKey: .hideDockIcon) ?? false
        if let rawPreference = try container.decodeIfPresent(String.self, forKey: .menuBarSpacing),
           let decodedPreference = MenuBarSpacingPreference(rawValue: rawPreference) {
            menuBarSpacing = decodedPreference
        } else {
            menuBarSpacing = .systemDefault
        }
        menuBarSpacingCustomValue = MenuBarSpacingPreference.clampedValue(
            try container.decodeIfPresent(Int.self, forKey: .menuBarSpacingCustomValue) ??
                menuBarSpacing.defaultsValue ??
                MenuBarSpacingPreference.systemDefaultNumericValue
        )
    }

    static let `default` = AppBehavior(
        hideDockIcon: false,
        menuBarSpacing: .systemDefault,
        menuBarSpacingCustomValue: MenuBarSpacingPreference.systemDefaultNumericValue
    )
}

enum MenuBarSpacingPreference: String, CaseIterable, Codable, Identifiable {
    case systemDefault
    case compact
    case comfortable
    case wide
    case custom

    static let minimumValue = 0
    static let maximumValue = 32
    static let systemDefaultNumericValue = 16

    var id: String { rawValue }

    var title: String {
        switch self {
        case .systemDefault: "System Default"
        case .compact: "Compact"
        case .comfortable: "Comfortable"
        case .wide: "Wide"
        case .custom: "Custom"
        }
    }

    var detail: String {
        switch self {
        case .systemDefault:
            "Remove macMender's spacing override."
        case .compact:
            "Use tighter spacing between menu bar icons."
        case .comfortable:
            "Use a balanced spacing value."
        case .wide:
            "Use extra room between menu bar icons."
        case .custom:
            "Use a precise custom spacing value."
        }
    }

    var defaultsValue: Int? {
        switch self {
        case .systemDefault:
            nil
        case .compact:
            8
        case .comfortable:
            16
        case .wide:
            24
        case .custom:
            nil
        }
    }

    func resolvedDefaultsValue(customValue: Int) -> Int? {
        defaultsValue ?? (self == .custom ? Self.clampedValue(customValue) : nil)
    }

    static func preference(matching value: Int) -> MenuBarSpacingPreference {
        let clamped = clampedValue(value)
        return [.compact, .comfortable, .wide].first { $0.defaultsValue == clamped } ?? .custom
    }

    static func clampedValue(_ value: Int) -> Int {
        min(maximumValue, max(minimumValue, value))
    }
}

struct FeatureToggles: Codable, Equatable {
    var scrolling: Bool
    var windowSwitcher: Bool
    var dockProfiles: Bool

    static let `default` = FeatureToggles(
        scrolling: true,
        windowSwitcher: true,
        dockProfiles: true
    )
}

struct MacMenderProfile: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var symbolName: String
    var summary: String
    var scroll: ScrollSettings
    var middleClick: MiddleClickSettings
    var windowSwitcher: WindowSwitcherSettings
    var dockPreviews: DockPreviewSettings
    var dock: DockSettings

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case symbolName
        case summary
        case scroll
        case middleClick
        case windowSwitcher
        case dockPreviews
        case dock
    }

    init(
        id: UUID,
        name: String,
        symbolName: String,
        summary: String,
        scroll: ScrollSettings,
        middleClick: MiddleClickSettings,
        windowSwitcher: WindowSwitcherSettings,
        dockPreviews: DockPreviewSettings = .default,
        dock: DockSettings
    ) {
        self.id = id
        self.name = name
        self.symbolName = symbolName
        self.summary = summary
        self.scroll = scroll
        self.middleClick = middleClick
        self.windowSwitcher = windowSwitcher
        self.dockPreviews = dockPreviews
        self.dock = dock
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        symbolName = try container.decode(String.self, forKey: .symbolName)
        summary = try container.decode(String.self, forKey: .summary)
        scroll = try container.decode(ScrollSettings.self, forKey: .scroll)
        middleClick = try container.decode(MiddleClickSettings.self, forKey: .middleClick)
        windowSwitcher = try container.decode(WindowSwitcherSettings.self, forKey: .windowSwitcher)
        dockPreviews = try container.decodeIfPresent(DockPreviewSettings.self, forKey: .dockPreviews) ?? .default
        dock = try container.decode(DockSettings.self, forKey: .dock)
    }

    static let `default` = MacMenderProfile(
        id: UUID(uuidString: "1BA904A0-5404-47F1-9349-A9B5F101C001")!,
        name: "Default",
        symbolName: "wrench.and.screwdriver",
        summary: "A balanced setup for everyday mouse, window, and Dock behavior.",
        scroll: .balanced,
        middleClick: .default,
        windowSwitcher: .default,
        dockPreviews: .default,
        dock: .work
    )

    static func customCopy(from profile: MacMenderProfile, name: String) -> MacMenderProfile {
        MacMenderProfile(
            id: UUID(),
            name: name,
            symbolName: "slider.horizontal.3",
            summary: "Custom settings copied from \(profile.name).",
            scroll: profile.scroll,
            middleClick: profile.middleClick,
            windowSwitcher: profile.windowSwitcher,
            dockPreviews: profile.dockPreviews,
            dock: profile.dock
        )
    }

    static let minimal = MacMenderProfile(
        id: UUID(uuidString: "1BA904A0-5404-47F1-9349-A9B5F101C002")!,
        name: "Minimal",
        symbolName: "circle.grid.cross",
        summary: "Reduced Dock, quiet switching, and conservative input changes.",
        scroll: .subtle,
        middleClick: .default,
        windowSwitcher: .compact,
        dockPreviews: .compact,
        dock: .minimal
    )

    static let gaming = MacMenderProfile(
        id: UUID(uuidString: "1BA904A0-5404-47F1-9349-A9B5F101C003")!,
        name: "Gaming",
        symbolName: "gamecontroller",
        summary: "Raw scrolling and minimal overlays for latency-sensitive apps.",
        scroll: .raw,
        middleClick: .disabled,
        windowSwitcher: .compact,
        dockPreviews: .compact,
        dock: .gaming
    )

    static let presentation = MacMenderProfile(
        id: UUID(uuidString: "1BA904A0-5404-47F1-9349-A9B5F101C004")!,
        name: "Presentation",
        symbolName: "rectangle.on.rectangle.angled",
        summary: "Clean desktop behavior for external displays and demos.",
        scroll: .subtle,
        middleClick: .default,
        windowSwitcher: .presentation,
        dockPreviews: .presentation,
        dock: .presentation
    )
}
