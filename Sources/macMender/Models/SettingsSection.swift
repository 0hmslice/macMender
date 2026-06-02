import Foundation

enum SettingsSection: String, CaseIterable, Identifiable {
    case overview
    case general
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
        case .input: "Mouse and trackpad"
        case .dockWindows: "Previews and switching"
        case .profiles: "Saved setups"
        case .privacy: "Access and settings"
        case .advanced: "Diagnostics"
        }
    }

    var symbolName: String {
        switch self {
        case .overview: "gauge.with.dots.needle.33percent"
        case .general: "gearshape"
        case .input: "computermouse"
        case .dockWindows: "dock.rectangle"
        case .profiles: "person.2.badge.gearshape"
        case .privacy: "lock.shield"
        case .advanced: "gearshape.2"
        }
    }
}
