import Foundation

enum SettingsSection: String, CaseIterable, Identifiable {
    case overview
    case input
    case menuBar
    case dockWindows
    case profiles
    case privacy
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: "Overview"
        case .input: "Input"
        case .menuBar: "Menu Bar"
        case .dockWindows: "Dock & Windows"
        case .profiles: "Profiles"
        case .privacy: "Privacy"
        case .advanced: "Advanced"
        }
    }

    var subtitle: String {
        switch self {
        case .overview: "At a glance"
        case .input: "Mouse and trackpad"
        case .menuBar: "Clean up with confidence"
        case .dockWindows: "Previews and switching"
        case .profiles: "Saved setups"
        case .privacy: "Access and settings"
        case .advanced: "Diagnostics"
        }
    }

    var symbolName: String {
        switch self {
        case .overview: "gauge.with.dots.needle.33percent"
        case .input: "computermouse"
        case .menuBar: "menubar.rectangle"
        case .dockWindows: "dock.rectangle"
        case .profiles: "person.2.badge.gearshape"
        case .privacy: "lock.shield"
        case .advanced: "gearshape.2"
        }
    }
}
