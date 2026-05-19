import Foundation

@MainActor
final class DiagnosticsService: ObservableObject {
    @Published private(set) var latestMessages: [String] = [
        "macMender stores configuration locally.",
        "Input event modification is disabled while Safe Mode is on.",
        "Window thumbnails require Screen Recording permission."
    ]

    func record(_ message: String) {
        latestMessages.insert(message, at: 0)
        latestMessages = Array(latestMessages.prefix(20))
    }
}
