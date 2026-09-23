import Foundation

enum SettingsSection: String, CaseIterable, Hashable, Identifiable {
    case overview
    case general
    case keepAwake
    case menuBarSpacing
    case input
    case dockWindows
    case profiles
    case privacy
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .general: "General"
        case .keepAwake: "Keep Awake"
        case .menuBarSpacing: "Menu Bar Spacing"
        case .input: "Input"
        case .dockWindows: "Dock & Windows"
        case .profiles: "Profiles"
        case .privacy: "Privacy"
        case .advanced: "Advanced"
        }
    }

    var subtitle: String {
        switch self {
        case .overview: "At a glance"
        case .general: "App settings"
        case .keepAwake: "Timed sleep prevention"
        case .menuBarSpacing: "Icon spacing"
        case .input: "Mouse and trackpad"
        case .dockWindows: "Previews and switching"
        case .profiles: "Saved setups"
        case .privacy: "Access and settings"
        case .advanced: "Diagnostics"
        }
    }

    var symbolName: String {
        switch self {
        case .overview: "rectangle.grid.2x2"
        case .general: "gearshape"
        case .keepAwake: "cup.and.saucer"
        case .menuBarSpacing: "arrow.left.and.right"
        case .input: "cursorarrow.motionlines"
        case .dockWindows: "dock.rectangle"
        case .profiles: "square.stack.3d.up"
        case .privacy: "hand.raised"
        case .advanced: "wrench.and.screwdriver"
        }
    }

    var searchTerms: String {
        switch self {
        case .overview: "status dashboard running helpers"
        case .general: "startup launch login hide dock icon"
        case .keepAwake: "sleep awake caffeine presentation timer display power download"
        case .menuBarSpacing: "menu bar icons spacing compact padding width"
        case .input: "mouse trackpad scrolling smooth reverse direction speed gain middle click three finger tap app override native bypass"
        case .dockWindows: "dock preview window switcher option alt tab shortcut thumbnail animation hover"
        case .profiles: "profile setup preset create delete custom"
        case .privacy: "privacy permissions accessibility screen recording access"
        case .advanced: "safe mode pause diagnostics import export backup configuration save reset"
        }
    }

    static func matching(_ query: String) -> [SettingsSection] {
        let terms = query.split(whereSeparator: \.isWhitespace).map(String.init)
        return allCases.filter { section in
            let text = "\(section.title) \(section.subtitle) \(section.searchTerms)"
            return terms.allSatisfy { text.localizedStandardContains($0) }
        }
    }
}
