import Foundation

enum KeepAwakeDuration: Int, CaseIterable, Identifiable {
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60
    case twoHours = 120
    case untilStopped = 0

    var id: Int { rawValue }
    var seconds: TimeInterval? { self == .untilStopped ? nil : Double(rawValue * 60) }
    var title: String {
        switch self {
        case .fifteenMinutes: "15 minutes"
        case .thirtyMinutes: "30 minutes"
        case .oneHour: "1 hour"
        case .twoHours: "2 hours"
        case .untilStopped: "Until stopped"
        }
    }
}

struct KeepAwakeSession: Equatable {
    let endsAt: Date?
    let keepsDisplayAwake: Bool
}
