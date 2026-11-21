import AppKit
import Testing
@testable import macMender

@MainActor
private final class FakeCatalog: WindowCatalogProviding {
    var windows: [WindowSummary]
    var closed: [String] = []
    var minimized: [String] = []
    var lastDiscoveryReport = WindowDiscoveryReport.empty

    init(count: Int) {
        windows = (0..<count).map { index in
            WindowSummary(
                id: "w\(index)", windowID: nil, axWindowID: nil, appName: "App", bundleIdentifier: nil,
                title: "Window \(index)", rawTitle: nil, processIdentifier: 1,
                frame: CGRect(x: 0, y: 0, width: 800, height: 600), isMinimized: false, stackIndex: index,
                axElement: nil, axRole: nil, axSubrole: nil
            )
        }
    }

    func visibleWindows() -> [WindowSummary] { windows }
    func activate(_ window: WindowSummary, source: WindowActivationSource, context: WindowActivationContext) -> WindowActivationOutcome {
        WindowActivationOutcome(attemptedSteps: [], success: true, reason: "test")
    }
    func minimize(_ window: WindowSummary) { minimized.append(window.id) }
    func close(_ window: WindowSummary) {
        closed.append(window.id)
        windows.removeAll { $0.id == window.id }
    }
    func thumbnails(for windows: [WindowSummary], maxSize: CGSize) async -> [WindowSummary.ID: NSImage] { [:] }
}

@MainActor
struct WindowSwitcherServiceTests {
    private func openSwitcher(count: Int) -> (WindowSwitcherService, FakeCatalog) {
        let catalog = FakeCatalog(count: count)
        let service = WindowSwitcherService(catalog: catalog, presentsPanel: false)
        var settings = WindowSwitcherSettings.default
        settings.includeOtherSpaces = false
        service.show(settings: settings)
        return (service, catalog)
    }

    @Test func sidewaysArrowsWrapLikeTab() {
        let (service, _) = openSwitcher(count: 3)
        let start = service.selectedIndex
        service.moveSelection(columns: 1, rows: 0)
        #expect(service.selectedIndex == (start + 1) % 3)
        service.moveSelection(columns: -1, rows: 0)
        service.moveSelection(columns: -1, rows: 0)
        #expect(service.selectedIndex == (start + 2) % 3)
    }

    @Test func closingTheSelectedWindowKeepsTheSwitcherOpenOnTheRest() {
        let (service, catalog) = openSwitcher(count: 3)
        let selected = service.selectedWindow?.id
        service.closeSelected()
        #expect(catalog.closed == [selected].compactMap { $0 })
        #expect(service.isShowing)
        #expect(service.windows.count == 2)
        #expect(service.selectedWindow != nil)
    }

    @Test func closingTheLastWindowDismissesTheSwitcher() {
        let (service, _) = openSwitcher(count: 1)
        service.closeSelected()
        #expect(!service.isShowing)
    }

    @Test func minimizeActsOnTheSelectedWindow() {
        let (service, catalog) = openSwitcher(count: 2)
        let selected = service.selectedWindow?.id
        service.minimizeSelected()
        #expect(catalog.minimized == [selected].compactMap { $0 })
    }

    @Test func commandsDoNothingWhenTheSwitcherIsClosed() {
        let (service, catalog) = openSwitcher(count: 2)
        service.cancel()
        service.closeSelected()
        service.minimizeSelected()
        #expect(catalog.closed.isEmpty)
        #expect(catalog.minimized.isEmpty)
    }
}
