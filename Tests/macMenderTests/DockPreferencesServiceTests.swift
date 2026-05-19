import Testing
@testable import macMender

@Suite("Dock Preferences")
struct DockPreferencesServiceTests {
    @MainActor
    @Test("diff lists changed fields")
    func diffListsChangedFields() {
        let service = DockPreferencesService()
        let changes = service.diff(from: .work, to: .minimal)
        #expect(changes.contains { $0.starts(with: "Size:") })
        #expect(changes.contains { $0.starts(with: "Auto-hide:") })
    }
}
