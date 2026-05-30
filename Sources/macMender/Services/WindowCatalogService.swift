import AppKit
import ApplicationServices
import Foundation
import ScreenCaptureKit

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

    func activate(_ window: WindowSummary) {
        if let axElement = window.axElement {
            if window.isMinimized {
                AXUIElementSetAttributeValue(axElement, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
            }
            AXUIElementPerformAction(axElement, kAXRaiseAction as CFString)
            AXUIElementSetAttributeValue(axElement, kAXMainAttribute as CFString, kCFBooleanTrue)
            AXUIElementSetAttributeValue(axElement, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        }
        NSRunningApplication(processIdentifier: window.processIdentifier)?.activate(options: [.activateAllWindows])
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
            let matchedCGWindow = bestCGWindow(
                for: app.processIdentifier,
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

    private func titlesMatch(_ lhs: String, _ rhs: String) -> Bool {
        guard !lhs.isEmpty, !rhs.isEmpty else { return false }
        return lhs == rhs || lhs.contains(rhs) || rhs.contains(lhs)
    }

    private func bestCGWindow(
        for processIdentifier: pid_t,
        title: String,
        frame: CGRect,
        cgWindows: [CGWindowDescription],
        usedWindowIDs: Set<CGWindowID>
    ) -> CGWindowDescription? {
        cgWindows
            .filter { $0.processIdentifier == processIdentifier && !usedWindowIDs.contains($0.windowID) }
            .compactMap { window -> (window: CGWindowDescription, score: Double)? in
                let titleScore = titlesMatch(window.title, title) ? 4.0 : 0
                let overlap = frameOverlapRatio(window.frame, frame)
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
