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

    @Test("Finder desktop fake window is excluded from preview candidates")
    func finderDesktopFakeWindowIsExcludedFromPreviewCandidates() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let fakeFinderDesktop = makeWindow(
            id: "finder-desktop",
            appName: "Finder",
            bundleIdentifier: "com.apple.finder",
            title: "Untitled Window",
            rawTitle: nil,
            pid: 901,
            windowID: nil,
            axWindowID: nil,
            frame: screenFrame,
            axRole: "AXScrollArea"
        )

        #expect(!fakeFinderDesktop.isPreviewableAppWindow(screenFrames: [screenFrame]))
    }

    @Test("real Finder window is included in preview candidates")
    func realFinderWindowIsIncludedInPreviewCandidates() {
        let realFinderWindow = makeWindow(
            id: "finder-home",
            appName: "Finder",
            bundleIdentifier: "com.apple.finder",
            title: "ryan",
            rawTitle: "ryan",
            pid: 902,
            windowID: 92,
            axWindowID: 92,
            axRole: kAXWindowRole as String
        )

        #expect(realFinderWindow.isPreviewableAppWindow())
    }

    @Test("Finder window with valid identity is preserved even with unusual title")
    func finderWindowWithValidIdentityIsPreservedEvenWithUnusualTitle() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let unusualFinderWindow = makeWindow(
            id: "finder-untitled",
            appName: "Finder",
            bundleIdentifier: "com.apple.finder",
            title: "Untitled Window",
            rawTitle: nil,
            pid: 906,
            windowID: 96,
            axWindowID: 96,
            frame: screenFrame,
            axRole: kAXWindowRole as String
        )

        #expect(unusualFinderWindow.isPreviewableAppWindow(screenFrames: [screenFrame]))
    }

    @Test("Finder preview candidates keep only real windows")
    func finderPreviewCandidatesKeepOnlyRealWindows() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let realFinderWindow = makeWindow(
            id: "finder-home",
            appName: "Finder",
            bundleIdentifier: "com.apple.finder",
            title: "ryan",
            rawTitle: "ryan",
            pid: 903,
            windowID: 93,
            axWindowID: 93,
            axRole: kAXWindowRole as String
        )
        let fakeFinderDesktop = makeWindow(
            id: "finder-desktop",
            appName: "Finder",
            bundleIdentifier: "com.apple.finder",
            title: "Untitled Window",
            rawTitle: nil,
            pid: 903,
            windowID: nil,
            axWindowID: nil,
            frame: screenFrame,
            axRole: "AXScrollArea"
        )

        let filtered = [realFinderWindow, fakeFinderDesktop].filter {
            $0.isPreviewableAppWindow(screenFrames: [screenFrame])
        }

        #expect(filtered.map(\.id) == ["finder-home"])
    }

    @Test("Finder with no real windows has no preview candidates")
    func finderWithNoRealWindowsHasNoPreviewCandidates() {
        let screenFrame = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let fakeFinderDesktop = makeWindow(
            id: "finder-desktop",
            appName: "Finder",
            bundleIdentifier: "com.apple.finder",
            title: "Untitled Window",
            rawTitle: nil,
            pid: 904,
            windowID: nil,
            axWindowID: nil,
            frame: screenFrame,
            axRole: "AXScrollArea"
        )

        let filtered = [fakeFinderDesktop].filter {
            $0.isPreviewableAppWindow(screenFrames: [screenFrame])
        }

        #expect(filtered.isEmpty)
    }

    @Test("legitimate untitled non-Finder window with CG identity is preserved")
    func legitimateUntitledNonFinderWindowWithCGIdentityIsPreserved() {
        let untitledDocument = makeWindow(
            id: "editor-untitled",
            appName: "Editor",
            bundleIdentifier: "com.example.editor",
            title: "Untitled Window",
            rawTitle: nil,
            pid: 905,
            windowID: 95,
            axWindowID: nil,
            axRole: nil
        )

        #expect(untitledDocument.isPreviewableAppWindow())
    }

    private func makeWindow(
        id: String,
        appName: String? = nil,
        bundleIdentifier: String? = nil,
        title: String,
        rawTitle: String? = nil,
        pid: pid_t,
        windowID: CGWindowID?,
        axWindowID: CGWindowID? = nil,
        frame: CGRect = CGRect(x: 0, y: 0, width: 800, height: 600),
        axRole: String? = nil,
        axSubrole: String? = nil
    ) -> WindowSummary {
        WindowSummary(
            id: id,
            windowID: windowID,
            axWindowID: axWindowID,
            appName: appName ?? title,
            bundleIdentifier: bundleIdentifier ?? "com.example.\(id)",
            title: title,
            rawTitle: rawTitle ?? title,
            processIdentifier: pid,
            frame: frame,
            isMinimized: false,
            stackIndex: windowID.map(Int.init) ?? Int.max,
            axElement: nil,
            axRole: axRole,
            axSubrole: axSubrole
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
