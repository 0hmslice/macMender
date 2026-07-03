import AppKit
import Testing
@testable import macMender

@Suite("Window Switcher Activation")
@MainActor
struct WindowSwitcherActivationTests {
    @Test("keyboard commit activates highlighted window")
    func keyboardCommitActivatesHighlightedWindow() {
        let windows = [
            makeWindow(id: "browser-1", title: "Browser One", pid: 101, windowID: 1),
            makeWindow(id: "browser-2", title: "Browser Two", pid: 101, windowID: 2)
        ]
        let catalog = RecordingWindowCatalog(windows: windows)
        let service = WindowSwitcherService(catalog: catalog, presentsPanel: false)

        service.show(settings: .default)
        service.select(index: 1, source: .mouseHover)
        service.commit(source: .keyboard)

        #expect(catalog.activations.map(\.window.id) == ["browser-2"])
        #expect(catalog.activations.first?.source == .keyboard)
        #expect(catalog.activations.first?.context.selectedIndex == 1)
        #expect(catalog.activations.first?.context.highlightedIndex == 1)
    }

    @Test("mouse click activates captured card window")
    func mouseClickActivatesCapturedCardWindow() {
        let windows = [
            makeWindow(id: "notes", title: "Notes", pid: 201, windowID: 11),
            makeWindow(id: "calendar", title: "Calendar", pid: 202, windowID: 12)
        ]
        let catalog = RecordingWindowCatalog(windows: windows)
        let service = WindowSwitcherService(catalog: catalog, presentsPanel: false)

        service.show(settings: .default)
        service.select(index: 0, source: .mouseHover)
        service.activateDisplayedWindow(windows[1], displayedIndex: 1, source: .mouseClick)

        #expect(catalog.activations.map(\.window.id) == ["calendar"])
        #expect(catalog.activations.first?.source == .mouseClick)
        #expect(catalog.activations.first?.context.selectedIndex == 1)
        #expect(catalog.activations.first?.context.highlightedIndex == 1)
    }

    @Test("keyboard cycle and confirm share final activation path")
    func keyboardCycleAndConfirmShareFinalActivationPath() {
        let windows = [
            makeWindow(id: "terminal", title: "Terminal", pid: 301, windowID: 21),
            makeWindow(id: "finder", title: "Finder", pid: 302, windowID: 22)
        ]
        let catalog = RecordingWindowCatalog(windows: windows)
        let service = WindowSwitcherService(catalog: catalog, presentsPanel: false)

        service.show(settings: .default)
        service.cycle()
        service.commit(source: .keyboard)

        #expect(catalog.activations.map(\.window.id) == ["finder"])
        #expect(catalog.activations.first?.source == .keyboard)
        #expect(catalog.activations.first?.context.selectedIndex == 1)
        #expect(catalog.activations.first?.context.highlightedIndex == 1)
    }

    @Test("test Dock preview uses resolved window identity")
    func testDockPreviewUsesResolvedWindowIdentity() {
        let windows = [
            makeWindow(id: "notes", title: "Notes", pid: 401, windowID: 31),
            makeWindow(id: "terminal", title: "Terminal", pid: 402, windowID: 32)
        ]
        let catalog = RecordingWindowCatalog(windows: windows)
        let service = WindowSwitcherService(catalog: catalog, presentsPanel: false)

        service.showDockPreviewForMostRecentApp(settings: .default, anchorFrame: .zero)

        #expect(service.isShowing)
        #expect(service.isDockPreview)
        #expect(service.windows.map(\.id) == ["notes"])
        #expect(service.presentationStatus == "1 Notes windows available")
    }

    @Test("Dock preview can use catalog path that includes current app windows")
    func dockPreviewCanUseCurrentAppCatalogPath() {
        let currentWindow = makeWindow(
            id: "macmender-overview",
            title: "Overview",
            pid: ProcessInfo.processInfo.processIdentifier,
            windowID: 41
        )
        let catalog = RecordingWindowCatalog(windows: [], dockPreviewWindows: [currentWindow])
        let service = WindowSwitcherService(catalog: catalog, presentsPanel: false)

        service.showDockPreview(
            identity: DockAppIdentity(
                title: "macMender",
                bundleIdentifier: "com.ryan.macMender",
                processIdentifier: ProcessInfo.processInfo.processIdentifier
            ),
            settings: .default,
            anchorFrame: .zero
        )

        #expect(service.isShowing)
        #expect(service.isDockPreview)
        #expect(service.windows.map(\.id) == ["macmender-overview"])
    }

    @Test("Dock preview context menu classifier detects secondary interactions")
    func dockPreviewContextMenuClassifierDetectsSecondaryInteractions() {
        #expect(DockPreviewContextMenuInteraction.isTrigger(eventType: .rightMouseDown, modifierFlags: []))
        #expect(DockPreviewContextMenuInteraction.isTrigger(eventType: .otherMouseDown, modifierFlags: []))
        #expect(DockPreviewContextMenuInteraction.isTrigger(eventType: .leftMouseDown, modifierFlags: [.control]))
        #expect(!DockPreviewContextMenuInteraction.isTrigger(eventType: .leftMouseDown, modifierFlags: []))
        #expect(!DockPreviewContextMenuInteraction.isTrigger(eventType: .mouseMoved, modifierFlags: [.control]))
    }

    @Test("Dock context menu suppression dismisses active preview")
    func dockContextMenuSuppressionDismissesActivePreview() {
        let windows = [
            makeWindow(id: "terminal", title: "Terminal", pid: 501, windowID: 51)
        ]
        let catalog = RecordingWindowCatalog(windows: windows)
        let service = WindowSwitcherService(catalog: catalog, presentsPanel: false)

        service.showDockPreview(
            identity: DockAppIdentity(title: "Terminal", bundleIdentifier: "com.example.terminal", processIdentifier: 501),
            settings: .default,
            anchorFrame: .zero
        )

        #expect(service.isShowing)

        service.suppressDockPreviewPresentation(until: Date().addingTimeInterval(10))

        #expect(!service.isShowing)
        #expect(service.presentationStatus == "Dock preview suppressed during Dock context menu")
    }

    @Test("Dock preview does not re-present during context menu suppression")
    func dockPreviewDoesNotRepresentDuringContextMenuSuppression() {
        let windows = [
            makeWindow(id: "terminal", title: "Terminal", pid: 601, windowID: 61)
        ]
        let catalog = RecordingWindowCatalog(windows: windows)
        let service = WindowSwitcherService(catalog: catalog, presentsPanel: false)
        let identity = DockAppIdentity(title: "Terminal", bundleIdentifier: "com.example.terminal", processIdentifier: 601)

        service.suppressDockPreviewPresentation(until: Date().addingTimeInterval(10))
        service.showDockPreview(identity: identity, settings: .default, anchorFrame: .zero)

        #expect(!service.isShowing)
        #expect(service.presentationStatus == "Dock preview suppressed during Dock context menu")
    }

    @Test("Dock preview can present after context menu suppression expires")
    func dockPreviewCanPresentAfterContextMenuSuppressionExpires() {
        let windows = [
            makeWindow(id: "terminal", title: "Terminal", pid: 701, windowID: 71)
        ]
        let catalog = RecordingWindowCatalog(windows: windows)
        let service = WindowSwitcherService(catalog: catalog, presentsPanel: false)

        service.suppressDockPreviewPresentation(until: Date().addingTimeInterval(-1))
        service.showDockPreview(
            identity: DockAppIdentity(title: "Terminal", bundleIdentifier: "com.example.terminal", processIdentifier: 701),
            settings: .default,
            anchorFrame: .zero
        )

        #expect(service.isShowing)
        #expect(service.isDockPreview)
        #expect(service.windows.map(\.id) == ["terminal"])
    }

    @Test("normal Dock preview dismiss still hides preview")
    func normalDockPreviewDismissStillHidesPreview() {
        let windows = [
            makeWindow(id: "terminal", title: "Terminal", pid: 801, windowID: 81)
        ]
        let catalog = RecordingWindowCatalog(windows: windows)
        let service = WindowSwitcherService(catalog: catalog, presentsPanel: false)

        service.showDockPreview(
            identity: DockAppIdentity(title: "Terminal", bundleIdentifier: "com.example.terminal", processIdentifier: 801),
            settings: .default,
            anchorFrame: .zero
        )
        service.cancel()

        #expect(!service.isShowing)
    }

    private func makeWindow(id: String, title: String, pid: pid_t, windowID: CGWindowID) -> WindowSummary {
        WindowSummary(
            id: id,
            windowID: windowID,
            appName: title,
            bundleIdentifier: "com.example.\(id)",
            title: title,
            processIdentifier: pid,
            frame: CGRect(x: 0, y: 0, width: 800, height: 600),
            isMinimized: false,
            stackIndex: Int(windowID),
            axElement: nil
        )
    }
}

@MainActor
private final class RecordingWindowCatalog: WindowCatalogProviding {
    struct Activation {
        var window: WindowSummary
        var source: WindowActivationSource
        var context: WindowActivationContext
    }

    var windows: [WindowSummary]
    var dockPreviewWindows: [WindowSummary]?
    var lastDiscoveryReport = WindowDiscoveryReport.empty
    private(set) var activations: [Activation] = []

    init(windows: [WindowSummary], dockPreviewWindows: [WindowSummary]? = nil) {
        self.windows = windows
        self.dockPreviewWindows = dockPreviewWindows
    }

    func visibleWindows() -> [WindowSummary] {
        lastDiscoveryReport = WindowDiscoveryReport(totalWindows: windows.count, appReports: [])
        return windows
    }

    func dockPreviewWindows(for identity: DockAppIdentity) -> [WindowSummary] {
        let candidates = dockPreviewWindows ?? windows
        let matched = candidates.filter { window in
            if let bundleIdentifier = identity.bundleIdentifier,
               window.bundleIdentifier == bundleIdentifier {
                return true
            }
            if let processIdentifier = identity.processIdentifier,
               window.processIdentifier == processIdentifier {
                return true
            }
            return false
        }
        lastDiscoveryReport = WindowDiscoveryReport(totalWindows: matched.count, appReports: [])
        return matched
    }

    func activate(
        _ window: WindowSummary,
        source: WindowActivationSource,
        context: WindowActivationContext
    ) -> WindowActivationOutcome {
        activations.append(Activation(window: window, source: source, context: context))
        return WindowActivationOutcome(attemptedSteps: ["recorded"], success: true, reason: "recorded")
    }

    func minimize(_ window: WindowSummary) {}

    func close(_ window: WindowSummary) {}

    func thumbnail(for window: WindowSummary, maxSize: CGSize) async -> NSImage? {
        nil
    }

    func thumbnails(for windows: [WindowSummary], maxSize: CGSize) async -> [WindowSummary.ID: NSImage] {
        [:]
    }
}
