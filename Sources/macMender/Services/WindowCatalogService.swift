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

struct WindowActivationContext: Equatable {
    var selectedIndex: Int?
    var highlightedIndex: Int?

    static let none = WindowActivationContext(selectedIndex: nil, highlightedIndex: nil)
}

struct WindowActivationOutcome: Equatable {
    var attemptedSteps: [String]
    var success: Bool
    var reason: String
}

struct WindowDiscoveryReport: Equatable {
    var totalWindows: Int
    var appReports: [WindowAppDiscoveryReport]

    static let empty = WindowDiscoveryReport(totalWindows: 0, appReports: [])

    var summary: String {
        let appCount = appReports.filter { $0.axWindowCount > 0 || $0.cgOnlyWindowCount > 0 || $0.includedCount > 0 }.count
        return "\(totalWindows) windows from \(appCount) apps"
    }

    var diagnosticLines: [String] {
        appReports.flatMap { report in
            if report.entries.isEmpty {
                return [
                    "\(report.appName) bundle=\(report.bundleIdentifier ?? "nil") pid=\(report.processIdentifier) axWindows=\(report.axWindowCount) cgOnly=\(report.cgOnlyWindowCount) included=0 dropped=1 reason=\(report.appDropReason ?? "no windows")"
                ]
            }
            return report.entries.map { entry in
                "\(report.appName) bundle=\(report.bundleIdentifier ?? "nil") pid=\(report.processIdentifier) axWindows=\(report.axWindowCount) title=\"\(entry.title)\" cg=\(entry.cgWindowID.map(String.init) ?? "missing") cgMatch=\(entry.cgMatchFound ? "found" : "missing") included=\(entry.included) reason=\(entry.reason)"
            }
        }
    }
}

struct WindowAppDiscoveryReport: Identifiable, Equatable {
    var id: String { "\(processIdentifier)-\(bundleIdentifier ?? appName)" }
    var appName: String
    var bundleIdentifier: String?
    var processIdentifier: pid_t
    var axWindowCount: Int
    var cgOnlyWindowCount: Int
    var includedCount: Int
    var droppedCount: Int
    var appDropReason: String?
    var entries: [WindowDiscoveryEntry]
}

struct WindowDiscoveryEntry: Identifiable, Equatable {
    var id: String
    var title: String
    var cgWindowID: CGWindowID?
    var cgMatchFound: Bool
    var included: Bool
    var reason: String
}

struct WindowSummary: Identifiable, Equatable {
    var id: String
    var windowID: CGWindowID?
    var axWindowID: CGWindowID?
    var appName: String
    var bundleIdentifier: String?
    var title: String
    var rawTitle: String?
    var processIdentifier: pid_t
    var frame: CGRect
    var isMinimized: Bool
    var stackIndex: Int
    var axElement: AXUIElement?
    var axRole: String?
    var axSubrole: String?

    static func == (lhs: WindowSummary, rhs: WindowSummary) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.processIdentifier == rhs.processIdentifier &&
        lhs.frame == rhs.frame &&
        lhs.isMinimized == rhs.isMinimized &&
        lhs.stackIndex == rhs.stackIndex
    }
}

struct WindowDiscoveryCandidateFacts: Equatable {
    var bundleIdentifier: String?
    var rawTitle: String
    var axWindowID: CGWindowID?
    var matchedCGWindowID: CGWindowID?
    var role: String?
    var subrole: String?
    var frame: CGRect
    var isMinimized: Bool
}

enum WindowDiscoveryCandidateDecision: Equatable {
    case include(reason: String)
    case drop(reason: String)

    var isIncluded: Bool {
        if case .include = self { return true }
        return false
    }

    var reason: String {
        switch self {
        case let .include(reason), let .drop(reason):
            return reason
        }
    }
}

enum WindowDiscoveryEligibility {
    static func decision(for facts: WindowDiscoveryCandidateFacts) -> WindowDiscoveryCandidateDecision {
        if facts.matchedCGWindowID != nil {
            return .include(reason: "includedAXWindowCGMatched")
        }

        guard facts.role == kAXWindowRole as String else {
            return .drop(reason: "nonWindowAXElementNoCGMatch")
        }

        let hasTitle = !facts.rawTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasAXWindowID = facts.axWindowID != nil
        let hasAXShape = facts.frame.width >= 80 && facts.frame.height >= 60

        guard hasTitle || hasAXWindowID || hasAXShape || facts.isMinimized else {
            return .drop(reason: "emptyTitleNoCGNoAXFrame")
        }

        return .include(reason: "includedAXWindowNoCGMatch")
    }
}

@MainActor
protocol WindowCatalogProviding {
    var lastDiscoveryReport: WindowDiscoveryReport { get }

    func visibleWindows() -> [WindowSummary]
    func dockPreviewWindows(for identity: DockAppIdentity) -> [WindowSummary]
    func activate(_ window: WindowSummary, source: WindowActivationSource, context: WindowActivationContext) -> WindowActivationOutcome
    func minimize(_ window: WindowSummary)
    func close(_ window: WindowSummary)
    func thumbnail(for window: WindowSummary, maxSize: CGSize) async -> NSImage?
    func thumbnails(for windows: [WindowSummary], maxSize: CGSize) async -> [WindowSummary.ID: NSImage]
}

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
            lastDiscoveryReport = cachedDiscovery.report
            return cachedDiscovery.windows
        }

        let cgWindows = cgWindowDescriptions()
        let runningApps = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular }
            .filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }

        var reports = [WindowAppDiscoveryReport]()
        let summaries = runningApps.flatMap { app in
            let result = windows(for: app, cgWindows: cgWindows)
            reports.append(result.report)
            return result.windows
        }

        let sorted = summaries.sorted {
            if $0.stackIndex == $1.stackIndex {
                if $0.appName == $1.appName { return $0.title < $1.title }
                return $0.appName < $1.appName
            }
            return $0.stackIndex < $1.stackIndex
        }
        lastDiscoveryReport = WindowDiscoveryReport(totalWindows: sorted.count, appReports: reports)
        cachedDiscovery = CachedWindowDiscovery(createdAt: now, windows: sorted, report: lastDiscoveryReport)
        logger.debug("Window discovery \(self.lastDiscoveryReport.summary, privacy: .public)")
        return sorted
    }

    func dockPreviewWindows(for identity: DockAppIdentity) -> [WindowSummary] {
        guard identity.hasResolvedApplicationIdentity else {
            lastDiscoveryReport = WindowDiscoveryReport(totalWindows: 0, appReports: [])
            return []
        }

        let cgWindows = cgWindowDescriptions()
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let targetApps = NSWorkspace.shared.runningApplications
            .filter { appMatchesDockIdentity($0, identity: identity) }
            .filter { $0.activationPolicy == .regular || $0.processIdentifier == currentPID }

        var reports = [WindowAppDiscoveryReport]()
        var summaries = [WindowSummary]()
        for app in targetApps {
            let result = windows(for: app, cgWindows: cgWindows)
            if app.processIdentifier == currentPID {
                let filtered = filterSelfPreviewWindows(result.windows)
                reports.append(selfPreviewReport(from: result.report, filteredWindows: filtered))
                summaries.append(contentsOf: filtered)
            } else {
                reports.append(result.report)
                summaries.append(contentsOf: result.windows)
            }
        }

        let sorted = summaries.sorted {
            if $0.stackIndex == $1.stackIndex {
                if $0.appName == $1.appName { return $0.title < $1.title }
                return $0.appName < $1.appName
            }
            return $0.stackIndex < $1.stackIndex
        }
        lastDiscoveryReport = WindowDiscoveryReport(totalWindows: sorted.count, appReports: reports)
        logger.debug("Dock preview discovery \(self.lastDiscoveryReport.summary, privacy: .public) identityTitle=\(identity.displayName, privacy: .private) bundle=\(identity.bundleIdentifier ?? "nil", privacy: .private) pid=\(identity.processIdentifier.map(String.init) ?? "nil", privacy: .private)")
        return sorted
    }

    @discardableResult
    func activate(
        _ window: WindowSummary,
        source: WindowActivationSource = .programmatic,
        context: WindowActivationContext = .none
    ) -> WindowActivationOutcome {
        var steps = [String]()
        let app = NSRunningApplication(processIdentifier: window.processIdentifier)
        let activationTarget = bestActivationTarget(for: window)
        let axElement = activationTarget?.element

        if app?.isHidden == true {
            app?.unhide()
            steps.append("unhideApp")
        }

        if let axElement {
            steps.append("axMatch:\(activationTarget?.matchDescription ?? "unknown")")
            if window.isMinimized || boolAttribute(kAXMinimizedAttribute, from: axElement) {
                let result = AXUIElementSetAttributeValue(axElement, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
                steps.append("unminimize:\(result.rawValue)")
            }
            steps.append("preRaise:\(AXUIElementPerformAction(axElement, kAXRaiseAction as CFString).rawValue)")
            steps.append("preMain:\(AXUIElementSetAttributeValue(axElement, kAXMainAttribute as CFString, kCFBooleanTrue).rawValue)")
        } else {
            steps.append("noAXWindow")
        }

        if let app {
            if let bundleURL = app.bundleURL {
                let configuration = NSWorkspace.OpenConfiguration()
                configuration.activates = true
                configuration.createsNewApplicationInstance = false
                NSWorkspace.shared.openApplication(at: bundleURL, configuration: configuration)
                steps.append("openApplicationActivate")
            }
            let activated = app.activate(options: [.activateAllWindows])
            steps.append("activateAllWindows:\(activated)")
        } else {
            steps.append("missingRunningApp")
        }

        RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.12))

        if let axElement {
            steps.append("postActivateRaise:\(AXUIElementPerformAction(axElement, kAXRaiseAction as CFString).rawValue)")
            steps.append("postActivateMain:\(AXUIElementSetAttributeValue(axElement, kAXMainAttribute as CFString, kCFBooleanTrue).rawValue)")
            steps.append("postActivateFocused:\(AXUIElementSetAttributeValue(axElement, kAXFocusedAttribute as CFString, kCFBooleanTrue).rawValue)")
        }

        let focusedWindow = focusedWindowInfo(for: window.processIdentifier)
        let frontmostPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let frontmostName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "nil"
        let appMatches = frontmostPID == window.processIdentifier
        let idMatches = if let windowID = window.windowID {
            if focusedWindow?.windowID == windowID {
                true
            } else if activationTarget == nil {
                appMatches
            } else {
                false
            }
        } else if activationTarget == nil {
            focusedWindow != nil || appMatches
        } else {
            focusedWindow != nil || activationTarget != nil
        }
        let success = appMatches && idMatches
        let reason = [
            "source=\(source.rawValue)",
            "selectedIndex=\(context.selectedIndex.map(String.init) ?? "nil")",
            "highlightedIndex=\(context.highlightedIndex.map(String.init) ?? "nil")",
            "selectedTitle=\(window.title)",
            "selectedCG=\(window.windowID.map(String.init) ?? "nil")",
            "selectedPID=\(window.processIdentifier)",
            "selectedBundle=\(window.bundleIdentifier ?? "nil")",
            "axMatch=\(activationTarget?.matchDescription ?? "missing")",
            "frontmostPID=\(frontmostPID.map(String.init) ?? "nil")",
            "frontmostApp=\(frontmostName)",
            "focusedCG=\(focusedWindow?.windowID.map(String.init) ?? "nil")",
            "focusedTitle=\(focusedWindow?.title ?? "nil")",
            "appMatches=\(appMatches)",
            "idMatches=\(idMatches)"
        ].joined(separator: " ")
        logger.debug("\(reason, privacy: .private) steps=\(steps.joined(separator: ","), privacy: .private)")
        return WindowActivationOutcome(attemptedSteps: steps, success: success, reason: reason)
    }

    func minimize(_ window: WindowSummary) {
        cachedDiscovery = nil
        guard let axElement = window.axElement else { return }
        AXUIElementSetAttributeValue(axElement, kAXMinimizedAttribute as CFString, kCFBooleanTrue)
    }

    func close(_ window: WindowSummary) {
        cachedDiscovery = nil
        guard let axElement = window.axElement else { return }
        var closeButton: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(axElement, kAXCloseButtonAttribute as CFString, &closeButton)
        guard result == .success, let button = closeButton else { return }
        AXUIElementPerformAction(button as! AXUIElement, kAXPressAction as CFString)
    }

    func thumbnail(for window: WindowSummary, maxSize: CGSize) async -> NSImage? {
        await thumbnails(for: [window], maxSize: maxSize)[window.id]
    }

    func thumbnails(for windows: [WindowSummary], maxSize: CGSize) async -> [WindowSummary.ID: NSImage] {
        let windowsWithIDs = windows.compactMap { window -> (WindowSummary, CGWindowID)? in
            guard let windowID = window.windowID else { return nil }
            return (window, windowID)
        }
        guard !windowsWithIDs.isEmpty else { return [:] }

        do {
            let content = try await SCShareableContent.current
            let captureWindowsByID = Dictionary(uniqueKeysWithValues: content.windows.map { ($0.windowID, $0) })
            var images = [WindowSummary.ID: NSImage]()

            for (window, windowID) in windowsWithIDs {
                guard let screenCaptureWindow = captureWindowsByID[windowID] else {
                    continue
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
                images[window.id] = NSImage(cgImage: image, size: targetSize)
            }
            return images
        } catch {
            return [:]
        }
    }

    private func windows(for app: NSRunningApplication, cgWindows: [CGWindowDescription]) -> (windows: [WindowSummary], report: WindowAppDiscoveryReport) {
        let appName = app.localizedName ?? app.bundleIdentifier ?? "Unknown App"
        let appCGWindows = cgWindows.filter { $0.processIdentifier == app.processIdentifier }
        let element = AXUIElementCreateApplication(app.processIdentifier)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let windows = value as? [AXUIElement] else {
            let fallback = cgOnlyWindows(for: app, cgWindows: appCGWindows)
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
                appName: appName,
                bundleIdentifier: app.bundleIdentifier,
                processIdentifier: app.processIdentifier,
                axWindowCount: 0,
                cgOnlyWindowCount: fallback.count,
                includedCount: fallback.count,
                droppedCount: fallback.isEmpty ? 1 : 0,
                appDropReason: fallback.isEmpty ? "AXUnavailable:\(result.rawValue) noCGWindows" : nil,
                entries: entries
            )
            return (fallback, report)
        }

        var usedCGWindowIDs = Set<CGWindowID>()
        var summaries = [WindowSummary]()
        var entries = [WindowDiscoveryEntry]()

        for (index, window) in windows.enumerated() {
            var titleValue: CFTypeRef?
            AXUIElementCopyAttributeValue(window, kAXTitleAttribute as CFString, &titleValue)
            let rawTitle = titleValue as? String ?? ""
            let frame = frame(for: window)
            let minimized = boolAttribute(kAXMinimizedAttribute, from: window)
            let axWindowID = cgWindowID(for: window)
            let role = stringAttribute(kAXRoleAttribute, from: window)
            let subrole = stringAttribute(kAXSubroleAttribute, from: window)
            let matchedCGWindow = bestCGWindow(
                for: app.processIdentifier,
                axWindowID: axWindowID,
                title: rawTitle,
                frame: frame,
                cgWindows: cgWindows,
                usedWindowIDs: usedCGWindowIDs
            )
            if let matchedCGWindow {
                usedCGWindowIDs.insert(matchedCGWindow.windowID)
            }

            let facts = WindowDiscoveryCandidateFacts(
                bundleIdentifier: app.bundleIdentifier,
                rawTitle: rawTitle,
                axWindowID: axWindowID,
                matchedCGWindowID: matchedCGWindow?.windowID,
                role: stringAttribute(kAXRoleAttribute, from: window),
                subrole: stringAttribute(kAXSubroleAttribute, from: window),
                frame: frame,
                isMinimized: minimized
            )
            let decision = WindowDiscoveryEligibility.decision(for: facts)
            guard decision.isIncluded else {
                entries.append(WindowDiscoveryEntry(
                    id: "\(app.processIdentifier)-ax-\(index)-dropped",
                    title: rawTitle.isEmpty ? "Untitled Window" : rawTitle,
                    cgWindowID: nil,
                    cgMatchFound: false,
                    included: false,
                    reason: decision.reason
                ))
                continue
            }

            let displayTitle = rawTitle.isEmpty ? "Untitled Window" : rawTitle
            let summary = WindowSummary(
                id: "\(app.processIdentifier)-\(matchedCGWindow?.windowID ?? axWindowID ?? CGWindowID(index))-\(displayTitle)",
                windowID: matchedCGWindow?.windowID,
                axWindowID: axWindowID,
                appName: appName,
                bundleIdentifier: app.bundleIdentifier,
                title: displayTitle,
                rawTitle: rawTitle,
                processIdentifier: app.processIdentifier,
                frame: frame == .zero ? matchedCGWindow?.frame ?? .zero : frame,
                isMinimized: minimized,
                stackIndex: matchedCGWindow?.stackIndex ?? Int.max,
                axElement: window,
                axRole: role,
                axSubrole: subrole
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

        let cgFallback = appCGWindows
            .filter { !usedCGWindowIDs.contains($0.windowID) }
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

        let previewableSummaries = filterPreviewableWindows(summaries)
        let keptSummaryIDs = Set(previewableSummaries.map(\.id))
        if keptSummaryIDs.count != summaries.count {
            entries = entries.map { entry in
                guard entry.included, !keptSummaryIDs.contains(entry.id) else {
                    return entry
                }
                return WindowDiscoveryEntry(
                    id: entry.id,
                    title: entry.title,
                    cgWindowID: entry.cgWindowID,
                    cgMatchFound: entry.cgMatchFound,
                    included: false,
                    reason: "droppedFinderDesktopOrUnidentifiedWindow"
                )
            }
            summaries = previewableSummaries
        }

        let droppedCount = entries.filter { !$0.included }.count
        let report = WindowAppDiscoveryReport(
            appName: appName,
            bundleIdentifier: app.bundleIdentifier,
            processIdentifier: app.processIdentifier,
            axWindowCount: windows.count,
            cgOnlyWindowCount: cgOnlySummaries.count,
            includedCount: summaries.count,
            droppedCount: droppedCount,
            appDropReason: summaries.isEmpty && entries.isEmpty ? "noAXOrCGWindows" : nil,
            entries: entries
        )
        return (summaries, report)
    }

    private func appMatchesDockIdentity(_ app: NSRunningApplication, identity: DockAppIdentity) -> Bool {
        if let bundleIdentifier = identity.bundleIdentifier,
           app.bundleIdentifier == bundleIdentifier {
            return true
        }
        if let processIdentifier = identity.processIdentifier,
           app.processIdentifier == processIdentifier {
            return true
        }
        return false
    }

    private func filterPreviewableWindows(_ windows: [WindowSummary]) -> [WindowSummary] {
        windows.filter { $0.isPreviewableAppWindow() }
    }

    private func filterSelfPreviewWindows(_ windows: [WindowSummary]) -> [WindowSummary] {
        windows.filter { window in
            guard window.processIdentifier == ProcessInfo.processInfo.processIdentifier else { return true }
            guard !window.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
            guard window.frame.width >= 240, window.frame.height >= 160 else { return false }
            guard let axElement = window.axElement else { return true }
            let role = stringAttribute(kAXRoleAttribute, from: axElement)
            let subrole = stringAttribute(kAXSubroleAttribute, from: axElement)
            guard role == kAXWindowRole as String else { return false }
            if subrole == kAXSystemDialogSubrole as String {
                return false
            }
            return true
        }
    }

    private func selfPreviewReport(from report: WindowAppDiscoveryReport, filteredWindows: [WindowSummary]) -> WindowAppDiscoveryReport {
        let keptIDs = Set(filteredWindows.map(\.id))
        let entries = report.entries.map { entry in
            if keptIDs.contains(entry.id) || !entry.included {
                return entry
            }
            return WindowDiscoveryEntry(
                id: entry.id,
                title: entry.title,
                cgWindowID: entry.cgWindowID,
                cgMatchFound: entry.cgMatchFound,
                included: false,
                reason: "droppedSelfPreviewTransientOrPanel"
            )
        }
        let droppedCount = entries.filter { !$0.included }.count
        return WindowAppDiscoveryReport(
            appName: report.appName,
            bundleIdentifier: report.bundleIdentifier,
            processIdentifier: report.processIdentifier,
            axWindowCount: report.axWindowCount,
            cgOnlyWindowCount: report.cgOnlyWindowCount,
            includedCount: filteredWindows.count,
            droppedCount: droppedCount,
            appDropReason: filteredWindows.isEmpty ? "noPreviewableSelfWindows" : report.appDropReason,
            entries: entries
        )
    }

    private func cgOnlyWindows(for app: NSRunningApplication, cgWindows: [CGWindowDescription]) -> [WindowSummary] {
        let appName = app.localizedName ?? app.bundleIdentifier ?? "Unknown App"
        return cgWindows.map { cgWindow in
            WindowSummary(
                id: "\(app.processIdentifier)-\(cgWindow.windowID)-\(cgWindow.title)",
                windowID: cgWindow.windowID,
                axWindowID: nil,
                appName: appName,
                bundleIdentifier: app.bundleIdentifier,
                title: cgWindow.title.isEmpty ? "Untitled Window" : cgWindow.title,
                rawTitle: cgWindow.title,
                processIdentifier: app.processIdentifier,
                frame: cgWindow.frame,
                isMinimized: false,
                stackIndex: cgWindow.stackIndex,
                axElement: nil,
                axRole: nil,
                axSubrole: nil
            )
        }
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

    private func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
            return nil
        }
        return value as? String
    }

    private func cgWindowID(for window: AXUIElement) -> CGWindowID? {
        var windowID: CGWindowID = 0
        guard _AXUIElementGetWindow(window, &windowID) == .success, windowID != 0 else {
            return nil
        }
        return windowID
    }

    private func bestActivationTarget(for window: WindowSummary) -> ActivationTarget? {
        if let axElement = window.axElement,
           let matchDescription = activationMatchDescription(for: axElement, window: window, prefix: "cached") {
            return ActivationTarget(element: axElement, matchDescription: matchDescription)
        }

        let appElement = AXUIElementCreateApplication(window.processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value) == .success,
              let windows = value as? [AXUIElement] else {
            if window.windowID == nil, let axElement = window.axElement {
                return ActivationTarget(element: axElement, matchDescription: "cachedFallbackNoWindowList")
            }
            return nil
        }

        return windows
            .compactMap { candidate -> (ActivationTarget, Double)? in
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
                let description = idScore > 0 ? "resolvedCG" : "resolvedFrame"
                return (ActivationTarget(element: candidate, matchDescription: description), score)
            }
            .max { $0.1 < $1.1 }?
            .0
    }

    private func activationMatchDescription(for element: AXUIElement, window: WindowSummary, prefix: String) -> String? {
        if let windowID = window.windowID, cgWindowID(for: element) == windowID {
            return "\(prefix)CG"
        }
        if window.windowID != nil {
            return nil
        }
        if frameOverlapRatio(frame(for: element), window.frame) >= 0.70 {
            return "\(prefix)Frame"
        }
        if window.isMinimized {
            return "\(prefix)Minimized"
        }
        return nil
    }

    private func focusedWindowInfo(for processIdentifier: pid_t) -> FocusedWindowInfo? {
        let appElement = AXUIElementCreateApplication(processIdentifier)
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &value) == .success,
              let focused = value else {
            return nil
        }
        let focusedElement = focused as! AXUIElement
        var titleValue: CFTypeRef?
        AXUIElementCopyAttributeValue(focusedElement, kAXTitleAttribute as CFString, &titleValue)
        return FocusedWindowInfo(windowID: cgWindowID(for: focusedElement), title: titleValue as? String ?? "")
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

private struct ActivationTarget {
    var element: AXUIElement
    var matchDescription: String
}

private struct FocusedWindowInfo {
    var windowID: CGWindowID?
    var title: String
}

private struct CachedWindowDiscovery {
    var createdAt: Date
    var windows: [WindowSummary]
    var report: WindowDiscoveryReport
}

private struct CGWindowDescription {
    var windowID: CGWindowID
    var processIdentifier: pid_t
    var title: String
    var frame: CGRect
    var stackIndex: Int
}

extension WindowSummary {
    func isPreviewableAppWindow(screenFrames: [CGRect] = NSScreen.screens.map(\.frame)) -> Bool {
        guard isFinderWindow else { return true }

        let hasWindowIdentity = windowID != nil || axWindowID != nil
        if isDesktopLikeFinderFrame(screenFrames: screenFrames), !hasWindowIdentity, !hasUsefulRawTitle {
            return false
        }

        guard hasWindowIdentity else {
            return false
        }

        if let axRole, axRole != kAXWindowRole as String {
            return false
        }

        return true
    }

    private var isFinderWindow: Bool {
        bundleIdentifier == "com.apple.finder" || appName == "Finder"
    }

    private var hasUsefulRawTitle: Bool {
        guard let rawTitle else { return false }
        return !rawTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func isDesktopLikeFinderFrame(screenFrames: [CGRect]) -> Bool {
        screenFrames.contains { screenFrame in
            frameOverlapRatio(frame, screenFrame) >= 0.96 &&
                frame.width >= screenFrame.width * 0.96 &&
                frame.height >= screenFrame.height * 0.90
        }
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
