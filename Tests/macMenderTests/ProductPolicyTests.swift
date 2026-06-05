import Foundation
import Testing
@testable import macMender

@Suite("Product Policy")
struct ProductPolicyTests {
    @Test("Accessibility is the only required permission in shared status policy")
    func accessibilityIsOnlyRequiredPermission() {
        #expect(PermissionStatusPolicy.requiredPermissionNames(accessibility: .missing) == ["Accessibility"])
        #expect(PermissionStatusPolicy.requiredPermissionNames(accessibility: .granted).isEmpty)
        #expect(PermissionStatusPolicy.needsAttention(accessibility: .missing))
        #expect(!PermissionStatusPolicy.needsAttention(accessibility: .granted))
    }

    @Test("optional permissions do not block core readiness")
    func optionalPermissionsDoNotBlockCoreReadiness() {
        let summary = PermissionStatusPolicy.permissionsSummary(
            accessibility: .granted,
            screenRecording: .missing,
            inputMonitoring: .missing
        )

        #expect(summary.title == "Ready with optional setup")
        #expect(summary.kind == .ready)
        #expect(PermissionStatusPolicy.screenRecordingSummary(.missing).title == "Icon fallback")
        #expect(PermissionStatusPolicy.screenRecordingSummary(.missing).kind == .optional)
        #expect(PermissionStatusPolicy.inputMonitoringSummary(.missing).title == "Optional")
        #expect(PermissionStatusPolicy.inputMonitoringSummary(.missing).kind == .optional)
    }

    @Test("three-finger tap status is not gated by Input Monitoring")
    func threeFingerTapStatusIsNotGatedByInputMonitoring() {
        let status = PermissionStatusPolicy.threeFingerTapStatus(
            settings: .default,
            accessibility: .granted,
            safeModeEnabled: false,
            runtimeRunning: false
        )

        #expect(status.title == "Ready")
        #expect(status.kind == .ready)
    }

    @Test("removed Menu Bar implementation symbols stay absent from active source")
    func removedMenuBarImplementationSymbolsStayAbsent() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let activeRoots = [
            root.appendingPathComponent("Sources"),
            root.appendingPathComponent("Tests"),
            root.appendingPathComponent("script")
        ]
        let forbidden = [
            "MenuBarItemMover",
            "MenuBarScanner",
            "MenuBarManagement",
            "MenuBarRuntime",
            "MenuBarEngine",
            "MacMenderMenuBarEngine",
            "MacMenderMenuBarItemService",
            "Command-drag",
            "Mark to Review",
            "Show/Tuck",
            "Always Hidden"
        ]

        for file in try swiftAndScriptFiles(under: activeRoots) {
            guard file.path != #filePath else { continue }
            let contents = try String(contentsOf: file, encoding: .utf8)
            for symbol in forbidden {
                #expect(!contents.contains(symbol), "\(symbol) found in \(file.path)")
            }
        }
    }

    @Test("package copy does not advertise removed Menu Bar management")
    func packageCopyDoesNotAdvertiseRemovedMenuBarManagement() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let packageScript = root.appendingPathComponent("script/package_brew.sh")
        let contents = try String(contentsOf: packageScript, encoding: .utf8)

        #expect(!contents.localizedCaseInsensitiveContains("menu bar"))
    }

    private func swiftAndScriptFiles(under roots: [URL]) throws -> [URL] {
        let fileManager = FileManager.default
        var files = [URL]()
        for root in roots {
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }
            for case let file as URL in enumerator {
                let values = try file.resourceValues(forKeys: [.isRegularFileKey])
                guard values.isRegularFile == true else { continue }
                if file.pathExtension == "swift" || file.pathExtension == "sh" {
                    files.append(file)
                }
            }
        }
        return files
    }
}
