import AppKit
import ApplicationServices
import Foundation
import os
import ScreenCaptureKit

@_silgen_name("_AXUIElementGetWindow")
@discardableResult
private func _AXUIElementGetWindow(_ element: AXUIElement, _ windowID: inout CGWindowID) -> AXError

enum WindowActivationSource: String {
    case keyboard
    case mouseHover
    case mouseClick
    case contextMenu
    case programmatic
}

struct WindowActivationOutcome: Equatable {
    var attemptedSteps: [String]
    var success: Bool
    var reason: String
}

struct WindowSummary: Identifiable, Equatable {
    var id: String
    var windowID: CGWindowID?
    var appName: String
    var bundleIdentifier: String?
    var title: String
    var processIdentifier: pid_t
    var frame: CGRect
    var isMinimized: Bool
    var stackIndex: Int
    var axElement: AXUIElement?

    static func == (lhs: WindowSummary, rhs: WindowSummary) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.processIdentifier == rhs.processIdentifier &&
        lhs.frame == rhs.frame &&
        lhs.isMinimized == rhs.isMinimized &&
        lhs.stackIndex == rhs.stackIndex
    }
}

@MainActor
final class WindowCatalogService {
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.ryan.macMender", category: "WindowActivation")

    func visibleWindows() -> [WindowSummary] {
        let cgWindows = cgWindowDescriptions()
        let runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }

        let summaries = runningApps.flatMap { app in
            windows(for: app, cgWindows: cgWindows)
        }

        return summaries.sorted {
            if $0.stackIndex == $1.stackIndex {
                if $0.appName == $1.appName { return $0.title < $1.title }
                return $0.appName < $1.appName
            }
            return $0.stackIndex < $1.stackIndex
        }
    }

    @discardableResult
    func activate(_ window: WindowSummary, source: WindowActivationSource = .programmatic) -> WindowActivationOutcome {
        var steps = [String]()
        let app = NSRunningApplication(processIdentifier: window.processIdentifier)
        let axElement = bestActivationElement(for: window)

        if app?.isHidden == true {
            app?.unhide()
            steps.append("unhideApp")
        }

        if let axElement {
            if window.isMinimized || boolAttribute(kAXMinimizedAttribute, from: axElement) {
                let result = AXUIElementSetAttributeValue(axElement, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                steps.append("unminimize:\(result.rawValue)")
            }
            steps.append("raise:\(AXUIElementPerformAction(axElement, kAXRaiseAction as CFString).rawValue)")
            steps.append("main:\(AXUIElementSetAttributeValue(axElement, kAXMainAttribute as CFString, kCFBooleanTrue).rawValue)")
            steps.append("focused:\(AXUIElementSetAttributeValue(axElement, kAXFocusedAttribute as CFString, kCFBooleanTrue).rawValue)")
        } else {
            steps.append("noAXWindow")
        }

        if let app {
            let activated = app.activate()
            steps.append("activateApp:\(activated)")
        } else {
            steps.append("missingRunningApp")
        }

        if let axElement {
            steps.append("postActivateRaise:\(AXUIElementPerformAction(axElement, kAXRaiseAction as CFString).rawValue)")
            steps.append("postActivateMain:\(AXUIElementSetAttributeValue(axElement, kAXMainAttribute as CFString, kCFBooleanTrue).rawValue)")
            steps.append("postActivateFocused:\(AXUIElementSetAttributeValue(axElement, kAXFocusedAttribute as CFString, kCFBooleanTrue).rawValue)")
        }

        let focusedWindowID = focusedWindowID(for: window.processIdentifier)
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let idMatches = window.windowID == nil || focusedWindowID == nil || focusedWindowID == window.windowID
        let appMatches = frontmostPID == window.processIdentifier
        let success = appMatches && idMatches
        let reason = "source=\(source.rawValue) selectedTitle=\(window.title) selectedCG=\(window.windowID.map(String.init) ?? "nil") focusedCG=\(focusedWindowID.map(String.init) ?? "nil") pid=\(window.processIdentifier) bundle=\(window.bundleIdentifier ?? "nil") appMatches=\(appMatches) idMatches=\(idMatches)"
        logger.debug("\(reason, privacy: .public) steps=\(steps.joined(separator: ","), privacy: .public)")
        return WindowActivationOutcome(attemptedSteps: steps, success: success, reason: reason)
    }

    func minimize(_ window: WindowSummary) {
        guard let axElement = window.axElement else { return }
        AXUIElementSetAttributeValue(axElement, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
    }

    func close(_ window: WindowSummary) {
        guard let axElement = window.axElement else { return }
        var closeButton: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axElement, kAXCloseButtonAttribute as CFString, &closeButton)
        guard result == .success, let button = closeButton else { return }
        AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
    }

    func thumbnail(for window: WindowSummary, maxSize: CGSize) async -> NSImage? {
        guard let windowID = window.windowID else { return nil }
        do {
            let content = try await SCShareableContent.current
            guard let screenCaptureWindow = content.windows.first(where: { $0.windowID == windowID }) else {
                return nil
            }

            let sourceSize = screenCaptureWindow.frame.size
            let scale = min(
                maxSize.width / max(sourceSize.width, 1),
                maxSize.height / max(sourceSize.height, 1),
                1
            )
            let targetSize = CGSize(
                width: max(1, sourceSize.width * scale),
                height: max(1, sourceSize.height * scale)
            )
            let configuration = SCStreamConfiguration()
            configuration.width = max(1, Int(targetSize.width * 2))
            configuration.height = max(1, Int(targetSize.height * 2))
            configuration.showsCursor = false

            let filter = SCContentFilter(desktopIndependentWindow: screenCaptureWindow)
            let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
            return NSImage(cgImage: image, size: targetSize)
        } catch {
            return nil
        }
    }

    private func windows(for app: NSRunningApplication, cgWindows: [CGWindowDescription]) -> [WindowSummary] {
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let windows = value as? [AXUIElement] else { return [] }

        var usedCGWindowIDs = Set<CGWindowID>()
        var summaries = [WindowSummary]()

        for (index, window) in windows.enumerated() {
            var titleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
            let title = titleValue as? String ?? "Untitled Window"
            let frame = frame(for: window)
            let minimized = boolAttribute(kAXMinimizedAttribute, from: window)
            let axWindowID = cgWindowID(for: window)
            let matchedCGWindow = bestCGWindow(
                for: app.processIdentifier,
                axWindowID: axWindowID,
                title: title,
                frame: frame,
                cgWindows: cgWindows,
                usedWindowIDs: usedCGWindowIDs
            )
            if let matchedCGWindow {
                usedCGWindowIDs.insert(matchedCGWindow.windowID)
            }

            guard !title.isEmpty || matchedCGWindow != nil || frame.width > 0 else {
                continue
            }

            summaries.append(WindowSummary(
                id: "\(app.processIdentifier)-\(matchedCGWindow?.windowID ?? CGWindowID(index))-\(title)",
                windowID: matchedCGWindow?.windowID,
                appName: app.localizedName ?? app.bundleIdentifier ?? "Unknown App",
                bundleIdentifier: app.bundleIdentifier,
                title: title.isEmpty ? "Untitled Window" : title,
                processIdentifier: app.processIdentifier,
                frame: frame == .zero ? matchedCGWindow?.frame ?? .zero : frame,
                isMinimized: minimized,
                stackIndex: matchedCGWindow?.stackIndex ?? Int.max,
                axElement: window
            ))
        }

        return summaries
    }

    private func cgWindowDescriptions() -> [CGWindowDescription] {
        guard let list = CGWindowListCopyWindowInfo([.excludeDesktopElements, .optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        return list.enumerated().compactMap { stackIndex, dictionary in
            guard let windowID = dictionary[kCGWindowNumber as String] as? CGWindowID,
                  let ownerPID = dictionary[kCGWindowOwnerPID as String] as? pid_t,
                  let layer = dictionary[kCGWindowLayer as String] as? Int,
                  layer == 0 else {
                return nil
            }

            let title = dictionary[kCGWindowName as String] as? String ?? ""
            var rect = CGRect.zero
            if let bounds = dictionary[kCGWindowBounds as String] as? NSDictionary {
                CGRectMakeWithDictionaryRepresentation(bounds, &rect)
            }

            guard rect.width >= 80, rect.height >= 60 else { return nil }
            return CGWindowDescription(windowID: windowID, processIdentifier: ownerPID, title: title, frame: rect, stackIndex: stackIndex)
        }
    }

    private func frame(for window: AXUIElement) -> CGRect {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue) == .success,
              AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue) == .success,
              let positionValue,
              let sizeValue else {
            return .zero
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: position, size: size)
    }

    private func boolAttribute(_ attribute: String, from element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return false
        }
        return (value as? Bool) ?? false
    }

    private func cgWindowID(for window: AXUIElement) -> CGWindowID? {
        var windowID: CGWindowID = 0
        guard _AXUIElementGetWindow(window, &windowID) == .success, windowID != 0 else {
            return nil
        }
        return windowID
    }

    private func bestActivationElement(for window: WindowSummary) -> AXUIElement? {
        if let axElement = window.axElement, activationElement(axElement, matches: window) {
            return axElement
        }

        let appElement = AXUIElementCreateApplication(window.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else {
            return window.axElement
        }

        return windows
            .compactMap { candidate -> (AXUIElement, Double)? in
                let candidateID = cgWindowID(for: candidate)
                let candidateFrame = frame(for: candidate)
                let idScore = candidateID != nil && candidateID == window.windowID ? 100.0 : 0
                let frameScore = frameOverlapRatio(candidateFrame, window.frame) * 20.0
                let titleScore: Double = {
                    var titleValue: CFTypeRef?
                    AXUIElementCopyAttributeValue(candidate, kAXTitleAttribute as CFString, &titleValue)
                    let candidateTitle = titleValue as? String ?? ""
                    return titlesMatch(candidateTitle, window.title) ? 1.0 : 0
                }()
                let score = idScore + frameScore + titleScore
                guard idScore > 0 || frameScore >= 12 else { return nil }
                return (candidate, score)
            }
            .max { $0.1 < $1.1 }?
            .0 ?? window.axElement
    }

    private func activationElement(_ element: AXUIElement, matches window: WindowSummary) -> Bool {
        if let windowID = window.windowID, cgWindowID(for: element) == windowID {
            return true
        }
        return frameOverlapRatio(frame(for: element), window.frame) >= 0.70
    }

    private func focusedWindowID(for processIdentifier: pid_t) -> CGWindowID? {
        let appElement = AXUIElementCreateApplication(processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let focused = value else {
            return nil
        }
        return cgWindowID(for: focused as! AXUIElement)
    }

    private func titlesMatch(_ lhs: String, _ rhs: String) -> Bool {
        guard !lhs.isEmpty, !rhs.isEmpty else { return false }
        return lhs == rhs || lhs.contains(rhs) || rhs.contains(lhs)
    }

    private func bestCGWindow(
        for processIdentifier: pid_t,
        axWindowID: CGWindowID?,
        title: String,
        frame: CGRect,
        cgWindows: [CGWindowDescription],
        usedWindowIDs: Set<CGWindowID>
    ) -> CGWindowDescription? {
        if let axWindowID,
           let exact = cgWindows.first(where: { $0.processIdentifier == processIdentifier && $0.windowID == axWindowID && !usedWindowIDs.contains($0.windowID) }) {
            return exact
        }

        return cgWindows
            .filter { $0.processIdentifier == processIdentifier && !usedWindowIDs.contains($0.windowID) }
            .compactMap { window -> (window: CGWindowDescription, score: Double)? in
                let overlap = frameOverlapRatio(window.frame, frame)
                guard overlap >= 0.72 else { return nil }
                let titleScore = titlesMatch(window.title, title) ? 0.5 : 0
                let frameScore = overlap >= 0.72 ? overlap * 3.0 : 0
                let score = titleScore + frameScore
                guard score >= 3 else { return nil }
                return (window, score)
            }
            .max {
                if $0.score == $1.score {
                    return $0.window.stackIndex > $1.window.stackIndex
                }
                return $0.score < $1.score
            }?
            .window
    }

    private func frameOverlapRatio(_ lhs: CGRect, _ rhs: CGRect) -> Double {
        guard lhs != .zero, rhs != .zero else { return 0 }
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else { return 0 }
        let intersectionArea = intersection.width * intersection.height
        let smallerArea = min(lhs.width * lhs.height, rhs.width * rhs.height)
        guard smallerArea > 0 else { return 0 }
        return intersectionArea / smallerArea
    }
}

private struct CGWindowDescription {
    var windowID: CGWindowID
    var processIdentifier: pid_t
    var title: String
    var frame: CGRect
    var stackIndex: Int
}
