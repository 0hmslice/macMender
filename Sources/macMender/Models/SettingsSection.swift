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
        case .input: "Input and Scrolling"
        case .menuBar: "Menu Bar"
        case .dockWindows: "Dock and Windows"
        case .profiles: "Profiles"
        case .privacy: "Privacy and Permissions"
        case .advanced: "Advanced"
        }
    }

    var subtitle: String {
        switch self {
        case .overview: "Status and quick actions"
        case .input: "Mouse, trackpad, scrolling"
        case .menuBar: "Hide and reveal icons"
        case .dockWindows: "Switcher, previews, Dock"
        case .profiles: "Saved setups"
        case .privacy: "Local data and access"
        case .advanced: "Diagnostics and recovery"
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
