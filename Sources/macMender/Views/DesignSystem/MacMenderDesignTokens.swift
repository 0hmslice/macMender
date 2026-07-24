import SwiftUI

enum MacMenderSpacing {
    static let compact: CGFloat = 6
    static let small: CGFloat = 8
    static let standard: CGFloat = 12
    static let section: CGFloat = 16
    static let page: CGFloat = 24
    static let spacious: CGFloat = 32
}

enum MacMenderRadius {
    static let control: CGFloat = 7
    static let content: CGFloat = 10
    static let prominent: CGFloat = 14
}

enum MacMenderMotion {
    static let quickDuration = 0.14
    static let stateDuration = 0.20

    static func feedback(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeOut(duration: quickDuration)
    }

    static func stateChange(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: stateDuration)
    }
}

enum MacMenderStatusTone: Sendable {
    case active
    case attention
    case paused
    case unavailable
    case neutral

    var color: Color {
        switch self {
        case .active:
            .green
        case .attention:
            .orange
        case .paused:
            .yellow
        case .unavailable:
            .red
        case .neutral:
            .secondary
        }
    }

    var defaultSymbol: String {
        switch self {
        case .active:
            "checkmark.circle.fill"
        case .attention:
            "exclamationmark.triangle.fill"
        case .paused:
            "pause.circle.fill"
        case .unavailable:
            "xmark.circle.fill"
        case .neutral:
            "circle.fill"
        }
    }

    var accessibilityTitle: String {
        switch self {
        case .active:
            "Active"
        case .attention:
            "Attention"
        case .paused:
            "Paused"
        case .unavailable:
            "Unavailable"
        case .neutral:
            "Information"
        }
    }
}

extension MacMenderStatusTone {
    init(capabilityTone: CapabilityBadge.Tone) {
        switch capabilityTone {
        case .active:
            self = .active
        case .warning:
            self = .attention
        case .neutral:
            self = .neutral
        }
    }
}
