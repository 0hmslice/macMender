import AppKit
import ApplicationServices
import Foundation

/// A running application reduced to the values discovery needs, so it can cross threads.
struct WindowAppTarget: Sendable, Equatable {
    var processIdentifier: pid_t
    var name: String
    var bundleIdentifier: String?
    var isHidden: Bool

    init(processIdentifier: pid_t, name: String, bundleIdentifier: String?, isHidden: Bool) {
        self.processIdentifier = processIdentifier
        self.name = name
        self.bundleIdentifier = bundleIdentifier
        self.isHidden = isHidden
    }

    init(_ app: NSRunningApplication) {
        self.init(
            processIdentifier: app.processIdentifier,
            name: app.localizedName ?? app.bundleIdentifier ?? "Unknown App",
            bundleIdentifier: app.bundleIdentifier,
            isHidden: app.isHidden
        )
    }
}

struct WindowDiscoveryScope: Sendable {
    /// Also find windows on Spaces that are not visible, including full-screen Spaces.
    var includeOtherSpaces: Bool
    var screenFrames: [CGRect]
}

struct WindowDiscoveryResult: Sendable {
    var windows: [WindowSummary]
    var report: WindowDiscoveryReport
}

/// Stateless window discovery. Nothing here touches the main actor, so callers may run it on a
/// background thread; a slow or unresponsive application then cannot stall macMender's interface.
enum WindowDiscoveryEngine {
    private static let offScreenStackBase = 100_000
    private static let minimizedStackBase = 200_000

    /// Bounds how long any single Accessibility request may block. The default is six seconds.
    static func configureAccessibilityTimeout() {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 1.5)
    }

    static func discover(apps: [WindowAppTarget], scope: WindowDiscoveryScope) -> WindowDiscoveryResult {
        let onScreen = cgWindowDescriptions(onScreenOnly: true)
        let allWindows = scope.includeOtherSpaces && PrivateWindowAPI.canEnumerateAllSpaces
            ? cgWindowDescriptions(onScreenOnly: false)
            : nil
        let context = Context(
            onScreen: onScreen,
            allByID: allWindows.map { Dictionary($0.map { ($0.windowID, $0) }, uniquingKeysWith: { first, _ in first }) },
            spaces: PrivateWindowAPI.spaceSnapshot(),
            screenFrames: scope.screenFrames
        )

        var reports = [WindowAppDiscoveryReport]()
        var summaries = [WindowSummary]()
        for app in apps {
            let result = windows(for: app, context: context)
            reports.append(result.report)
            summaries.append(contentsOf: result.windows)
        }

        let sorted = summaries.sorted {
            if $0.stackIndex == $1.stackIndex {
                if $0.appName == $1.appName { return $0.title < $1.title }
                return $0.appName < $1.appName
            }
            return $0.stackIndex < $1.stackIndex
        }
        return WindowDiscoveryResult(
            windows: sorted,
            report: WindowDiscoveryReport(totalWindows: sorted.count, appReports: reports)
        )
    }

    /// Finds the Accessibility element for a window that was discovered without one.
    static func resolveElement(for window: WindowSummary) -> AXUIElement? {
        if let element = window.axElement { return element }
        let appElement = AXUIElementCreateApplication(window.processIdentifier)
        guard let candidates = copyAttribute(kAXWindowsAttribute, from: appElement) as? [AXUIElement] else {
            return nil
        }
        if let windowID = window.windowID,
           let exact = candidates.first(where: { PrivateWindowAPI.windowID(of: $0) == windowID }) {
            return exact
        }
        return candidates
            .map { ($0, frameOverlapRatio(frame(of: $0), window.frame)) }
            .filter { $0.1 >= 0.70 }
            .max { $0.1 < $1.1 }?
            .0
    }

    // MARK: Per-application discovery

    private struct Context {
        var onScreen: [CGWindowDescription]
        var allByID: [CGWindowID: CGWindowDescription]?
        var spaces: PrivateWindowAPI.SpaceSnapshot
        var screenFrames: [CGRect]
    }

    private struct Candidate {
        var element: AXUIElement
        var foundByProbe: Bool
    }

    private static func windows(
        for app: WindowAppTarget,
        context: Context
    ) -> (windows: [WindowSummary], report: WindowAppDiscoveryReport) {
        let pid = app.processIdentifier
        let appOnScreen = context.onScreen.filter { $0.processIdentifier == pid }
        let appElement = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let listedWindows = value as? [AXUIElement] else {
            let fallback = cgOnlyWindows(for: app, cgWindows: appOnScreen)
            let entries = fallback.map { summary in
                WindowDiscoveryEntry(
                    id: summary.id,
                    title: summary.title,
                    cgWindowID: summary.windowID,
                    cgMatchFound: true,
                    included: true,
                    reason: "includedCGOnlyAXUnavailable:\(result.rawValue)"
                )
            }
            let report = WindowAppDiscoveryReport(
                appName: app.name,
                bundleIdentifier: app.bundleIdentifier,
                processIdentifier: pid,
                axWindowCount: 0,
                cgOnlyWindowCount: fallback.count,
                includedCount: fallback.count,
                droppedCount: fallback.isEmpty ? 1 : 0,
                appDropReason: fallback.isEmpty ? "AXUnavailable:\(result.rawValue) noCGWindows" : nil,
                entries: entries
            )
            return (fallback, report)
        }

        var candidates = listedWindows.map { Candidate(element: $0, foundByProbe: false) }
        if let allByID = context.allByID {
            let listedIDs = Set(listedWindows.compactMap { PrivateWindowAPI.windowID(of: $0) })
            var probedIDs = Set<CGWindowID>()
            for element in PrivateWindowAPI.windowElementsOnAllSpaces(pid: pid) {
                guard let windowID = PrivateWindowAPI.windowID(of: element),
                      !listedIDs.contains(windowID),
                      !probedIDs.contains(windowID),
                      allByID[windowID]?.processIdentifier == pid else {
                    continue
                }
                probedIDs.insert(windowID)
                candidates.append(Candidate(element: element, foundByProbe: true))
            }
        }

        var usedCGWindowIDs = Set<CGWindowID>()
        var summaries = [WindowSummary]()
        var entries = [WindowDiscoveryEntry]()

        for (index, candidate) in candidates.enumerated() {
            let window = candidate.element
            let rawTitle = copyAttribute(kAXTitleAttribute, from: window) as? String ?? ""
            let axFrame = frame(of: window)
            let minimized = boolAttribute(kAXMinimizedAttribute, from: window)
            let axWindowID = PrivateWindowAPI.windowID(of: window)
            let role = copyAttribute(kAXRoleAttribute, from: window) as? String
            let subrole = copyAttribute(kAXSubroleAttribute, from: window) as? String
            let displayTitle = rawTitle.isEmpty ? "Untitled Window" : rawTitle

            func drop(_ reason: String) {
                entries.append(WindowDiscoveryEntry(
                    id: "\(pid)-ax-\(index)-dropped",
                    title: displayTitle,
                    cgWindowID: axWindowID,
                    cgMatchFound: false,
                    included: false,
                    reason: reason
                ))
            }

            let spaceIDs = axWindowID.map(PrivateWindowAPI.spaceIDs(for:)) ?? []
            if candidate.foundByProbe, spaceIDs.isEmpty, !minimized {
                drop("probedWindowNotOnAnySpace")
                continue
            }
            // Applications occasionally keep Accessibility elements for windows the window
            // server has already destroyed.
            if let allByID = context.allByID, let axWindowID, allByID[axWindowID] == nil,
               !appOnScreen.contains(where: { $0.windowID == axWindowID }) {
                drop("staleWindowNotInWindowServer")
                continue
            }

            let matchedCGWindow = bestCGWindow(
                for: pid,
                axWindowID: axWindowID,
                title: rawTitle,
                frame: axFrame,
                cgWindows: context.onScreen,
                usedWindowIDs: usedCGWindowIDs
            )
            if let matchedCGWindow {
                usedCGWindowIDs.insert(matchedCGWindow.windowID)
            }

            let decision: WindowDiscoveryCandidateDecision = candidate.foundByProbe
                ? .include(reason: "includedOtherSpaceWindow")
                : WindowDiscoveryEligibility.decision(for: WindowDiscoveryCandidateFacts(
                    bundleIdentifier: app.bundleIdentifier,
                    rawTitle: rawTitle,
                    axWindowID: axWindowID,
                    matchedCGWindowID: matchedCGWindow?.windowID,
                    role: role,
                    subrole: subrole,
                    frame: axFrame,
                    isMinimized: minimized
                ))
            guard decision.isIncluded else {
                drop(decision.reason)
                continue
            }

            let windowID = matchedCGWindow?.windowID ?? axWindowID
            let offScreenFrame = windowID.flatMap { context.allByID?[$0]?.frame }
            let isOnOtherSpace = !minimized &&
                !spaceIDs.isEmpty &&
                !context.spaces.currentSpaceIDs.isEmpty &&
                context.spaces.currentSpaceIDs.isDisjoint(with: spaceIDs)
            let stackIndex: Int
            if let matchedCGWindow {
                stackIndex = matchedCGWindow.stackIndex
            } else if minimized {
                stackIndex = minimizedStackBase + index
            } else {
                stackIndex = offScreenStackBase + index
            }

            let summary = WindowSummary(
                id: windowID.map { "\(pid)-\($0)" } ?? "\(pid)-ax\(index)-\(displayTitle)",
                windowID: windowID,
                axWindowID: axWindowID,
                appName: app.name,
                bundleIdentifier: app.bundleIdentifier,
                title: displayTitle,
                rawTitle: rawTitle,
                processIdentifier: pid,
                frame: axFrame == .zero ? matchedCGWindow?.frame ?? offScreenFrame ?? .zero : axFrame,
                isMinimized: minimized,
                stackIndex: stackIndex,
                axElement: window,
                axRole: role,
                axSubrole: subrole,
                isOnOtherSpace: isOnOtherSpace,
                isFullScreen: boolAttribute("AXFullScreen", from: window) ||
                    !context.spaces.fullScreenSpaceIDs.isDisjoint(with: spaceIDs),
                isAppHidden: app.isHidden
            )
            summaries.append(summary)
            entries.append(WindowDiscoveryEntry(
                id: summary.id,
                title: summary.title,
                cgWindowID: summary.windowID,
                cgMatchFound: matchedCGWindow != nil,
                included: true,
                reason: decision.reason
            ))
        }

        let knownIDs = Set(summaries.compactMap(\.windowID))
        let cgFallback = appOnScreen
            .filter { !usedCGWindowIDs.contains($0.windowID) && !knownIDs.contains($0.windowID) }
            .filter { cgWindow in
                !summaries.contains { summary in
                    frameOverlapRatio(summary.frame, cgWindow.frame) >= 0.72 || titlesMatch(summary.title, cgWindow.title)
                }
            }
        let cgOnlySummaries = cgOnlyWindows(for: app, cgWindows: cgFallback)
        summaries.append(contentsOf: cgOnlySummaries)
        entries.append(contentsOf: cgOnlySummaries.map { summary in
            WindowDiscoveryEntry(
                id: summary.id,
                title: summary.title,
                cgWindowID: summary.windowID,
                cgMatchFound: true,
                included: true,
                reason: "includedCGOnlyNoAXDuplicate"
            )
        })

        let previewable = summaries.filter { $0.isPreviewableAppWindow(screenFrames: context.screenFrames) }
        if previewable.count != summaries.count {
            let keptIDs = Set(previewable.map(\.id))
            entries = entries.map { entry in
                guard entry.included, !keptIDs.contains(entry.id) else { return entry }
                var dropped = entry
                dropped.included = false
                dropped.reason = "droppedFinderDesktopOrUnidentifiedWindow"
                return dropped
            }
            summaries = previewable
        }

        let report = WindowAppDiscoveryReport(
            appName: app.name,
            bundleIdentifier: app.bundleIdentifier,
            processIdentifier: pid,
            axWindowCount: listedWindows.count,
            cgOnlyWindowCount: cgOnlySummaries.count,
            includedCount: summaries.count,
            droppedCount: entries.filter { !$0.included }.count,
            appDropReason: summaries.isEmpty && entries.isEmpty ? "noAXOrCGWindows" : nil,
            entries: entries
        )
        return (summaries, report)
    }

    private static func cgOnlyWindows(for app: WindowAppTarget, cgWindows: [CGWindowDescription]) -> [WindowSummary] {
        cgWindows.map { cgWindow in
            WindowSummary(
                id: "\(app.processIdentifier)-\(cgWindow.windowID)",
                windowID: cgWindow.windowID,
                axWindowID: nil,
                appName: app.name,
                bundleIdentifier: app.bundleIdentifier,
                title: cgWindow.title.isEmpty ? "Untitled Window" : cgWindow.title,
                rawTitle: cgWindow.title,
                processIdentifier: app.processIdentifier,
                frame: cgWindow.frame,
                isMinimized: false,
                stackIndex: cgWindow.stackIndex,
                axElement: nil,
                axRole: nil,
                axSubrole: nil,
                isAppHidden: app.isHidden
            )
        }
    }

    // MARK: Window server

    private struct CGWindowDescription {
        var windowID: CGWindowID
        var processIdentifier: pid_t
        var title: String
        var frame: CGRect
        var stackIndex: Int
    }

    private static func cgWindowDescriptions(onScreenOnly: Bool) -> [CGWindowDescription] {
        let options: CGWindowListOption = onScreenOnly
            ? [.excludeDesktopElements, .optionOnScreenOnly]
            : [.excludeDesktopElements, .optionAll]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
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

    private static func bestCGWindow(
        for processIdentifier: pid_t,
        axWindowID: CGWindowID?,
        title: String,
        frame: CGRect,
        cgWindows: [CGWindowDescription],
        usedWindowIDs: Set<CGWindowID>
    ) -> CGWindowDescription? {
        if let axWindowID {
            // A known window ID either matches exactly or the window is not on screen.
            return cgWindows.first {
                $0.processIdentifier == processIdentifier && $0.windowID == axWindowID && !usedWindowIDs.contains($0.windowID)
            }
        }

        return cgWindows
            .filter { $0.processIdentifier == processIdentifier && !usedWindowIDs.contains($0.windowID) }
            .compactMap { window -> (window: CGWindowDescription, score: Double)? in
                let overlap = frameOverlapRatio(window.frame, frame)
                guard overlap >= 0.72 else { return nil }
                let score = (titlesMatch(window.title, title) ? 0.5 : 0) + overlap * 3.0
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

    // MARK: Accessibility helpers

    static func copyAttribute(_ attribute: String, from element: AXUIElement) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value
    }

    static func boolAttribute(_ attribute: String, from element: AXUIElement) -> Bool {
        (copyAttribute(attribute, from: element) as? Bool) ?? false
    }

    static func frame(of element: AXUIElement) -> CGRect {
        guard let positionValue = copyAttribute(kAXPositionAttribute, from: element),
              let sizeValue = copyAttribute(kAXSizeAttribute, from: element),
              CFGetTypeID(positionValue) == AXValueGetTypeID(),
              CFGetTypeID(sizeValue) == AXValueGetTypeID() else {
            return .zero
        }

        var position = CGPoint.zero
        var size = CGSize.zero
        AXValueGetValue(positionValue as! AXValue, .cgPoint, &position)
        AXValueGetValue(sizeValue as! AXValue, .cgSize, &size)
        return CGRect(origin: position, size: size)
    }

    private static func titlesMatch(_ lhs: String, _ rhs: String) -> Bool {
        guard !lhs.isEmpty, !rhs.isEmpty else { return false }
        return lhs == rhs || lhs.contains(rhs) || rhs.contains(lhs)
    }

    static func frameOverlapRatio(_ lhs: CGRect, _ rhs: CGRect) -> Double {
        guard lhs != .zero, rhs != .zero else { return 0 }
        let intersection = lhs.intersection(rhs)
        guard !intersection.isNull, intersection.width > 0, intersection.height > 0 else { return 0 }
        let intersectionArea = intersection.width * intersection.height
        let smallerArea = min(lhs.width * lhs.height, rhs.width * rhs.height)
        guard smallerArea > 0 else { return 0 }
        return intersectionArea / smallerArea
    }
}
