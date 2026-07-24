#!/usr/bin/env swift

import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

private let spacingKeys = [
    "NSStatusItemSpacing",
    "NSStatusItemSelectionPadding"
]

private let knownMenuBarBundleIdentifiers = [
    "com.apple.MenuBarAgent",
    "com.apple.controlcenter",
    "com.apple.systemuiserver",
    "eu.exelban.Stats",
    "com.ryan.macMender"
]

private func preferenceValue(
    for key: String,
    applicationID: CFString,
    host: CFString
) -> String {
    guard let value = CFPreferencesCopyValue(
        key as CFString,
        applicationID,
        kCFPreferencesCurrentUser,
        host
    ) else {
        return "missing"
    }
    return String(describing: value)
}

private func attributeValue(_ attribute: String, of element: AXUIElement) -> CFTypeRef? {
    var value: CFTypeRef?
    guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else {
        return nil
    }
    return value
}

private func stringAttribute(_ attribute: String, of element: AXUIElement) -> String? {
    attributeValue(attribute, of: element) as? String
}

private func pointAttribute(_ attribute: String, of element: AXUIElement) -> CGPoint? {
    guard let value = attributeValue(attribute, of: element),
          CFGetTypeID(value) == AXValueGetTypeID() else {
        return nil
    }
    var point = CGPoint.zero
    guard AXValueGetValue(value as! AXValue, .cgPoint, &point) else { return nil }
    return point
}

private func sizeAttribute(_ attribute: String, of element: AXUIElement) -> CGSize? {
    guard let value = attributeValue(attribute, of: element),
          CFGetTypeID(value) == AXValueGetTypeID() else {
        return nil
    }
    var size = CGSize.zero
    guard AXValueGetValue(value as! AXValue, .cgSize, &size) else { return nil }
    return size
}

private func childElements(of element: AXUIElement) -> [AXUIElement] {
    attributeValue(kAXChildrenAttribute, of: element) as? [AXUIElement] ?? []
}

private struct AXRecord {
    var depth: Int
    var role: String
    var title: String
    var identifier: String
    var frame: CGRect?
}

private func observableMenuBarRecords(for application: NSRunningApplication) -> [AXRecord] {
    let root = AXUIElementCreateApplication(application.processIdentifier)
    var records: [AXRecord] = []
    var pending: [(AXUIElement, Int)] = [(root, 0)]
    var visited = Set<CFHashCode>()

    while let (element, depth) = pending.popLast() {
        guard depth <= 12 else { continue }
        let hash = CFHash(element)
        guard visited.insert(hash).inserted else { continue }

        let role = stringAttribute(kAXRoleAttribute, of: element) ?? "unknown"
        let title = stringAttribute(kAXTitleAttribute, of: element) ??
            stringAttribute(kAXDescriptionAttribute, of: element) ?? ""
        let identifier = stringAttribute(kAXIdentifierAttribute, of: element) ?? ""
        let position = pointAttribute(kAXPositionAttribute, of: element)
        let size = sizeAttribute(kAXSizeAttribute, of: element)
        let frame = position.flatMap { origin in size.map { CGRect(origin: origin, size: $0) } }
        let isVisibleMenuBarItem = role == (kAXMenuBarItemRole as String) &&
            (frame.map { $0.minY <= 44 && $0.width > 0 && $0.height > 0 } ?? false)

        if depth > 0, isVisibleMenuBarItem {
            records.append(AXRecord(
                depth: depth,
                role: role,
                title: title,
                identifier: identifier,
                frame: frame
            ))
        }

        for child in childElements(of: element).reversed() {
            pending.append((child, depth + 1))
        }
    }

    var seenRecords = Set<String>()
    let uniqueRecords = records.filter { record in
        let key = "\(record.role)|\(record.title)|\(record.identifier)|\(format(record.frame))"
        return seenRecords.insert(key).inserted
    }

    return uniqueRecords.sorted {
        switch ($0.frame, $1.frame) {
        case let (left?, right?):
            if left.minY != right.minY { return left.minY < right.minY }
            return left.minX < right.minX
        case (.some, .none):
            return true
        case (.none, .some):
            return false
        case (.none, .none):
            return $0.role < $1.role
        }
    }
}

private func format(_ frame: CGRect?) -> String {
    guard let frame else { return "unavailable" }
    return String(
        format: "x=%.1f y=%.1f w=%.1f h=%.1f",
        frame.origin.x,
        frame.origin.y,
        frame.size.width,
        frame.size.height
    )
}

private func printWindowServerMenuBarWindows() {
    let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
    guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
        print("  unavailable")
        return
    }

    let menuBarWindows = windows.compactMap { window -> (String, Int, Int, CGRect, String)? in
        guard let bounds = window[kCGWindowBounds as String] as? [String: Any],
              let x = bounds["X"] as? Double,
              let y = bounds["Y"] as? Double,
              let width = bounds["Width"] as? Double,
              let height = bounds["Height"] as? Double,
              y <= 44,
              height <= 80 else {
            return nil
        }
        let owner = window[kCGWindowOwnerName as String] as? String ?? "unknown"
        let pid = window[kCGWindowOwnerPID as String] as? Int ?? -1
        let layer = window[kCGWindowLayer as String] as? Int ?? -1
        let name = window[kCGWindowName as String] as? String ?? ""
        return (owner, pid, layer, CGRect(x: x, y: y, width: width, height: height), name)
    }.sorted { $0.3.minX < $1.3.minX }

    if menuBarWindows.isEmpty {
        print("  none exposed")
    } else {
        for window in menuBarWindows {
            print("  owner=\(window.0) pid=\(window.1) layer=\(window.2) frame=[\(format(window.3))] name=\(window.4)")
        }
    }
}

let processInfo = ProcessInfo.processInfo
let osVersion = processInfo.operatingSystemVersion
let osBuild = processInfo.operatingSystemVersionString

print("macMender Menu Bar Spacing Diagnostic")
print("Read-only: this tool does not write preferences or restart processes.")
print("OS: \(osVersion.majorVersion).\(osVersion.minorVersion).\(osVersion.patchVersion) (\(osBuild))")
print("Architecture: \(processInfo.machineArchitecture)")
print("Accessibility trusted: \(AXIsProcessTrusted())")

print("\nSpacing preferences")
for key in spacingKeys {
    let byHost = preferenceValue(
        for: key,
        applicationID: kCFPreferencesAnyApplication,
        host: kCFPreferencesCurrentHost
    )
    let global = preferenceValue(
        for: key,
        applicationID: kCFPreferencesAnyApplication,
        host: kCFPreferencesAnyHost
    )
    print("  \(key): current-host=\(byHost), any-host=\(global)")
}

print("\nKnown menu bar processes")
for bundleIdentifier in knownMenuBarBundleIdentifiers {
    let applications = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
    if applications.isEmpty {
        print("  \(bundleIdentifier): not running")
        continue
    }

    for application in applications {
        print("  \(bundleIdentifier): pid=\(application.processIdentifier) name=\(application.localizedName ?? "unknown")")
        let records = observableMenuBarRecords(for: application)
        if records.isEmpty {
            print("    no menu-bar item frames exposed through Accessibility")
        } else {
            for record in records {
                print("    role=\(record.role) title=\(record.title) id=\(record.identifier) frame=[\(format(record.frame))]")
            }
        }
    }
}

print("\nWindowServer top-edge windows")
printWindowServerMenuBarWindows()

private extension ProcessInfo {
    var machineArchitecture: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        return withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
}
