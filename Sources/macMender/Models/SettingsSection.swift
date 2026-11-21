import Foundation

enum SettingsSection: String, CaseIterable, Hashable, Identifiable {
    case overview
    case dockPreviews
    case windowSwitcher
    case dockSettings
    case input
    case keepAwake
    case menuBarSpacing
    case general
    case profiles
    case privacy
    case advanced

    /// How the sidebar groups its sections.
    enum Group: String, CaseIterable, Identifiable {
        case start
        case features
        case app

        var id: String { rawValue }

        var title: String? {
            switch self {
            case .start: nil
            case .features: "Features"
            case .app: "macMender"
            }
        }
    }

    var id: String { rawValue }

    var group: Group {
        switch self {
        case .overview: .start
        case .dockPreviews, .windowSwitcher, .dockSettings, .input, .keepAwake, .menuBarSpacing: .features
        case .general, .profiles, .privacy, .advanced: .app
        }
    }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .dockPreviews: "Dock Previews"
        case .windowSwitcher: "Window Switcher"
        case .dockSettings: "Dock"
        case .input: "Mouse & Trackpad"
        case .keepAwake: "Keep Awake"
        case .menuBarSpacing: "Menu Bar Spacing"
        case .general: "General"
        case .profiles: "Profiles"
        case .privacy: "Privacy"
        case .advanced: "Advanced"
        }
    }

    /// One sentence shown under the page title.
    var subtitle: String {
        switch self {
        case .overview: "What macMender is doing right now, and the quickest way to change it."
        case .dockPreviews: "Rest the pointer on a Dock icon to see that app's windows, then switch, close, or arrange them."
        case .windowSwitcher: "Switch between individual windows from the keyboard, not just between apps."
        case .dockSettings: "Set the Dock's size, position, and hiding, then apply the changes when you are ready."
        case .input: "Smooth the mouse wheel, choose scroll direction for each device, and add a middle click."
        case .keepAwake: "Keep downloads, presentations, and long tasks running while you step away."
        case .menuBarSpacing: "Fit more icons in the menu bar, or give them more room."
        case .general: "How macMender starts and where it shows up."
        case .profiles: "Save different setups and switch between them."
        case .privacy: "The macOS permissions macMender uses, and what each one is for."
        case .advanced: "Pause everything, back up your settings, and look under the hood."
        }
    }

    var symbolName: String {
        switch self {
        case .overview: "rectangle.grid.2x2"
        case .dockPreviews: "dock.arrow.up.rectangle"
        case .windowSwitcher: "rectangle.on.rectangle"
        case .dockSettings: "dock.rectangle"
        case .input: "computermouse"
        case .keepAwake: "cup.and.saucer"
        case .menuBarSpacing: "arrow.left.and.right"
        case .general: "gearshape"
        case .profiles: "square.stack.3d.up"
        case .privacy: "hand.raised"
        case .advanced: "wrench.and.screwdriver"
        }
    }

    var searchTerms: String {
        switch self {
        case .overview: "status dashboard running helpers"
        case .dockPreviews: "dock preview hover thumbnail peek close minimize exclude animation live header"
        case .windowSwitcher: "window switcher option alt tab shortcut thumbnail grid strip spaces"
        case .dockSettings: "dock size magnification position auto-hide autohide recent apps indicators"
        case .input: "input scrolling smooth reverse direction speed gain middle click three finger tap app override native bypass"
        case .keepAwake: "sleep awake caffeine presentation timer display power download"
        case .menuBarSpacing: "menu bar icons spacing compact padding width"
        case .general: "startup launch login hide show dock icon appearance about version"
        case .profiles: "profile setup preset create delete custom"
        case .privacy: "privacy permissions accessibility screen recording input monitoring access"
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
