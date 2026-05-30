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

    @Test("Dock preview identity requires bundle or process")
    func dockPreviewIdentityRequiresResolvedApplication() {
        #expect(!DockAppIdentity(title: "Messages", bundleIdentifier: nil, processIdentifier: nil).hasResolvedApplicationIdentity)
        #expect(DockAppIdentity(title: "Messages", bundleIdentifier: "com.apple.MobileSMS", processIdentifier: nil).hasResolvedApplicationIdentity)
        #expect(DockAppIdentity(title: "Messages", bundleIdentifier: nil, processIdentifier: 123).hasResolvedApplicationIdentity)
    }
}
