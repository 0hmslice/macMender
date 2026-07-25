import Foundation

enum SettingsSection: String, CaseIterable, Hashable, Identifiable {
    case overview
    case general
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
        case .menuBarSpacing: "arrow.left.and.right"
        case .input: "cursorarrow.motionlines"
        case .dockWindows: "dock.rectangle"
        case .profiles: "square.stack.3d.up"
        case .privacy: "hand.raised"
        case .advanced: "wrench.and.screwdriver"
        }
    }
}
