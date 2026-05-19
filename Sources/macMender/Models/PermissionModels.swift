import Foundation

enum PermissionState: String, Codable {
    case granted
    case missing
    case unavailable

    var title: String {
        switch self {
        case .granted: "Granted"
        case .missing: "Needs Access"
        case .unavailable: "Unavailable"
        }
    }
}

struct PermissionSnapshot: Codable, Equatable {
    var accessibility: PermissionState
    var screenRecording: PermissionState
    var loginItem: PermissionState
}
