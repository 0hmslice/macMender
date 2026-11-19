import AppKit
import ApplicationServices
import Foundation
import os
// Xcode 26 lacks complete concurrency annotations for these Objective-C snapshots.
// This main-actor service only reads the returned content.
@preconcurrency import ScreenCaptureKit

@MainActor
protocol WindowCatalogProviding {
    var lastDiscoveryReport: WindowDiscoveryReport { get }

    func visibleWindows() -> [WindowSummary]
    func activate(_ window: WindowSummary, source: WindowActivationSource, context: WindowActivationContext) -> WindowActivationOutcome
    func minimize(_ window: WindowSummary)
    func close(_ window: WindowSummary)
    func thumbnails(for windows: [WindowSummary], maxSize: CGSize) async -> [WindowSummary.ID: NSImage]
}

/// Window list and actions for the keyboard window switcher.
@MainActor
final class WindowCatalogService: WindowCatalogProviding {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.ryan.macMender", category: "WindowActivation")
    private(set) var lastDiscoveryReport = WindowDiscoveryReport.empty
    private var cachedDiscovery: CachedWindowDiscovery?
    private let discoveryCacheDuration: TimeInterval = 0.35

    func visibleWindows() -> [WindowSummary] {
        let now = Date()
        if let cachedDiscovery,
           now.timeIntervalSince(cachedDiscovery.createdAt) < discoveryCacheDuration {
            lastDiscoveryReport = cachedDiscovery.result.report
            return cachedDiscovery.result.windows
        }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let apps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.processIdentifier != currentPID }
            .map(WindowAppTarget.init)
        let result = WindowDiscoveryEngine.discover(
            apps: apps,
            scope: WindowDiscoveryScope(includeOtherSpaces: false, screenFrames: NSScreen.screens.map(\.frame))
        )
        lastDiscoveryReport = result.report
        cachedDiscovery = CachedWindowDiscovery(createdAt: now, result: result)
        logger.debug("Window discovery \(result.report.summary, privacy: .public)")
        return result.windows
    }

    @discardableResult
    func activate(
        _ window: WindowSummary,
        source: WindowActivationSource = .programmatic,
        context: WindowActivationContext = .none
    ) -> WindowActivationOutcome {
        cachedDiscovery = nil
        let outcome = WindowActions.activate(window)
        logger.debug("source=\(source.rawValue, privacy: .public) \(outcome.reason, privacy: .private)")
        return outcome
    }

    func minimize(_ window: WindowSummary) {
        cachedDiscovery = nil
        WindowActions.setMinimized(window, minimized: true)
    }

    func close(_ window: WindowSummary) {
        cachedDiscovery = nil
        WindowActions.close(window)
    }

    func thumbnails(for windows: [WindowSummary], maxSize: CGSize) async -> [WindowSummary.ID: NSImage] {
        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let requests = windows.compactMap { window -> WindowThumbnailRequest? in
            guard let windowID = window.windowID else { return nil }
            return WindowThumbnailRequest(
                id: window.id,
                windowID: windowID,
                maxPixelSize: CGSize(width: maxSize.width * scale, height: maxSize.height * scale)
            )
        }
        guard !requests.isEmpty else { return [:] }

        var images = [WindowSummary.ID: NSImage]()
        for (id, image) in await WindowThumbnailCapturer.capture(requests) {
            images[id] = NSImage(
                cgImage: image,
                size: CGSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
            )
        }

        let missing = windows.filter { images[$0.id] == nil && $0.windowID != nil && !$0.isMinimized }
        if !missing.isEmpty {
            for (id, image) in await screenCaptureKitThumbnails(for: missing, maxSize: maxSize) {
                images[id] = image
            }
        }
        return images
    }

    /// Public-API capture, used when the faster window-server capture is unavailable.
    private func screenCaptureKitThumbnails(for windows: [WindowSummary], maxSize: CGSize) async -> [WindowSummary.ID: NSImage] {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(true, onScreenWindowsOnly: false)
            let captureWindowsByID = Dictionary(content.windows.map { ($0.windowID, $0) }, uniquingKeysWith: { first, _ in first })
            var images = [WindowSummary.ID: NSImage]()

            for window in windows {
                guard let windowID = window.windowID, let captureWindow = captureWindowsByID[windowID] else {
                    continue
                }

                let sourceSize = captureWindow.frame.size
                let scale = min(maxSize.width / max(sourceSize.width, 1), maxSize.height / max(sourceSize.height, 1), 1)
                let targetSize = CGSize(width: max(1, sourceSize.width * scale), height: max(1, sourceSize.height * scale))
                let configuration = SCStreamConfiguration()
                configuration.width = max(1, Int(targetSize.width * 2))
                configuration.height = max(1, Int(targetSize.height * 2))
                configuration.showsCursor = false

                let filter = SCContentFilter(desktopIndependentWindow: captureWindow)
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
                images[window.id] = NSImage(cgImage: image, size: targetSize)
            }
            return images
        } catch {
            return [:]
        }
    }
}

private struct CachedWindowDiscovery {
    var createdAt: Date
    var result: WindowDiscoveryResult
}

/// Actions on another application's window. These are single, user-initiated requests.
@MainActor
enum WindowActions {
    /// Brings one window forward. Other windows of the same application keep their place.
    @discardableResult
    static func activate(_ window: WindowSummary) -> WindowActivationOutcome {
        var steps = [String]()
        guard let app = NSRunningApplication(processIdentifier: window.processIdentifier), !app.isTerminated else {
            return WindowActivationOutcome(attemptedSteps: ["missingRunningApp"], success: false, reason: "application is no longer running")
        }

        if app.isHidden {
            app.unhide()
            steps.append("unhideApp")
        }

        let element = WindowDiscoveryEngine.resolveElement(for: window)
        if let element, window.isMinimized || WindowDiscoveryEngine.boolAttribute(kAXMinimizedAttribute, from: element) {
            let result = AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            steps.append("unminimize:\(result.rawValue)")
        }

        var focused = false
        if let windowID = window.windowID ?? element.flatMap(PrivateWindowAPI.windowID(of:)) {
            focused = PrivateWindowAPI.focusWindow(pid: window.processIdentifier, windowID: windowID)
            steps.append("focusWindow:\(focused)")
        }
        if !focused {
            focused = app.activate()
            steps.append("activateApp:\(focused)")
        }

        if let element {
            steps.append("raise:\(AXUIElementPerformAction(element, kAXRaiseAction as CFString).rawValue)")
            AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        } else {
            steps.append("noAXWindow")
        }

        let reason = "title=\(window.title) cg=\(window.windowID.map(String.init) ?? "nil") pid=\(window.processIdentifier) steps=\(steps.joined(separator: ","))"
        return WindowActivationOutcome(attemptedSteps: steps, success: focused, reason: reason)
    }

    @discardableResult
    static func close(_ window: WindowSummary) -> Bool {
        guard let element = WindowDiscoveryEngine.resolveElement(for: window),
              let button = WindowDiscoveryEngine.copyAttribute(kAXCloseButtonAttribute, from: element),
              CFGetTypeID(button) == AXUIElementGetTypeID() else {
            return false
        }
        return AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString) == .success
    }

    @discardableResult
    static func setMinimized(_ window: WindowSummary, minimized: Bool) -> Bool {
        guard let element = WindowDiscoveryEngine.resolveElement(for: window) else { return false }
        let value: CFBoolean = minimized ? kCFBooleanTrue : kCFBooleanFalse
        return AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, value) == .success
    }

    @discardableResult
    static func toggleFullScreen(_ window: WindowSummary) -> Bool {
        guard let element = WindowDiscoveryEngine.resolveElement(for: window) else { return false }
        let isFullScreen = WindowDiscoveryEngine.boolAttribute("AXFullScreen", from: element)
        let value: CFBoolean = isFullScreen ? kCFBooleanFalse : kCFBooleanTrue
        return AXUIElementSetAttributeValue(element, "AXFullScreen" as CFString, value) == .success
    }

    static func canClose(_ window: WindowSummary) -> Bool {
        guard let element = window.axElement else { return false }
        return WindowDiscoveryEngine.copyAttribute(kAXCloseButtonAttribute, from: element) != nil
    }
}
