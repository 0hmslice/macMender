import Foundation
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

    @Test("Dock preview linger clamps to runtime dismissal range")
    func dockPreviewLingerClampsToRuntimeDismissalRange() {
        #expect(DockPreviewSettings.default.previewIdleTimeout == 1.8)
        #expect(DockPreviewSettings.clampedPreviewIdleTimeout(-1) == 0)
        #expect(DockPreviewSettings.clampedPreviewIdleTimeout(4.2) == 4.2)
        #expect(DockPreviewSettings.clampedPreviewIdleTimeout(12) == 10)
    }

    @Test("Dock preview animation defaults are persisted profile settings")
    func dockPreviewAnimationDefaultsArePersistedProfileSettings() {
        #expect(DockPreviewSettings.default.animationStyle == .system)
        #expect(DockPreviewSettings.default.animationSpeed == .balanced)
        #expect(DockPreviewAnimationStyle.allCases.map(\.title).contains("Glass Pop"))
        #expect(DockPreviewAnimationSpeed.allCases.map(\.title) == ["Snappy", "Balanced", "Smooth"])
    }

    @Test("Dock preview code does not use title-only display eligibility")
    func dockPreviewCodeDoesNotUseTitleOnlyDisplayEligibility() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let dockHover = try String(
            contentsOf: root.appendingPathComponent("Sources/macMender/Services/DockHoverService.swift"),
            encoding: .utf8
        )
        let switcher = try String(
            contentsOf: root.appendingPathComponent("Sources/macMender/Services/WindowSwitcherService.swift"),
            encoding: .utf8
        )

        #expect(!dockHover.contains("app.localizedName == title"))
        #expect(!dockHover.contains("deletingPathExtension().lastPathComponent == title"))
        #expect(!switcher.contains("localizedCaseInsensitiveCompare(identity.displayName)"))
    }
}
