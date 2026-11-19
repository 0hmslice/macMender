import AppKit
import ApplicationServices
import Foundation

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

struct WindowDiscoveryReport: Equatable, Sendable {
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

struct WindowAppDiscoveryReport: Identifiable, Equatable, Sendable {
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

struct WindowDiscoveryEntry: Identifiable, Equatable, Sendable {
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
    /// The window lives on a Space that is not currently visible on any display.
    var isOnOtherSpace = false
    var isFullScreen = false
    var isAppHidden = false

    static func == (lhs: WindowSummary, rhs: WindowSummary) -> Bool {
        lhs.id == rhs.id &&
        lhs.title == rhs.title &&
        lhs.processIdentifier == rhs.processIdentifier &&
        lhs.frame == rhs.frame &&
        lhs.isMinimized == rhs.isMinimized &&
        lhs.stackIndex == rhs.stackIndex &&
        lhs.isOnOtherSpace == rhs.isOnOtherSpace &&
        lhs.isFullScreen == rhs.isFullScreen &&
        lhs.isAppHidden == rhs.isAppHidden
    }

    /// Width divided by height, bounded so unusual windows still lay out sensibly.
    var aspectRatio: CGFloat {
        guard frame.width > 1, frame.height > 1 else { return 1.5 }
        return frame.width / frame.height
    }
}

// Accessibility elements are immutable Core Foundation references that are safe to message from
// any thread; discovery deliberately runs off the main thread.
extension WindowSummary: @unchecked Sendable {}

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

extension WindowSummary {
    func isPreviewableAppWindow(screenFrames: [CGRect]) -> Bool {
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
