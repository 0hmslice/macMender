import AppKit
import CoreGraphics

// Private CoreGraphics Services bridge adapted from Ice for macOS (GPL-3.0).
// Source: https://github.com/jordanbaird/Ice
// Ice revision used during the port: 11edd39115f3f43a83ae114b5348df6a0e1741cf.

typealias CGSConnectionID = Int32
typealias CGSSpaceID = size_t

struct CGSSpaceMask: OptionSet {
    let rawValue: UInt32

    static let includesCurrent = CGSSpaceMask(rawValue: 1 << 0)
    static let includesOthers = CGSSpaceMask(rawValue: 1 << 1)
    static let includesUser = CGSSpaceMask(rawValue: 1 << 2)
    static let includesVisible = CGSSpaceMask(rawValue: 1 << 16)
    static let allSpaces: CGSSpaceMask = [.includesUser, .includesOthers, .includesCurrent]
    static let allVisibleSpaces: CGSSpaceMask = [.includesVisible, .allSpaces]
}

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

@_silgen_name("CGSGetActiveSpace")
func CGSGetActiveSpace(_ cid: CGSConnectionID) -> CGSSpaceID

@_silgen_name("CGSCopySpacesForWindows")
func CGSCopySpacesForWindows(
    _ cid: CGSConnectionID,
    _ mask: CGSSpaceMask,
    _ windowIDs: CFArray
) -> Unmanaged<CFArray>?

@_silgen_name("CGSGetWindowCount")
func CGSGetWindowCount(
    _ cid: CGSConnectionID,
    _ targetCID: CGSConnectionID,
    _ outCount: inout Int32
) -> CGError

@_silgen_name("CGSGetProcessMenuBarWindowList")
func CGSGetProcessMenuBarWindowList(
    _ cid: CGSConnectionID,
    _ targetCID: CGSConnectionID,
    _ count: Int32,
    _ list: UnsafeMutablePointer<CGWindowID>,
    _ outCount: inout Int32
) -> CGError

@_silgen_name("CGSGetScreenRectForWindow")
func CGSGetScreenRectForWindow(
    _ cid: CGSConnectionID,
    _ wid: CGWindowID,
    _ outRect: inout CGRect
) -> CGError

enum MenuBarPrivateBridge {
    static var activeSpaceID: CGSSpaceID {
        CGSGetActiveSpace(CGSMainConnectionID())
    }

    static func menuBarWindowIDs() -> [CGWindowID] {
        var count: Int32 = 0
        guard CGSGetWindowCount(CGSMainConnectionID(), 0, &count) == .success, count > 0 else {
            return []
        }

        var list = [CGWindowID](repeating: 0, count: Int(count))
        var realCount: Int32 = 0
        let result = CGSGetProcessMenuBarWindowList(
            CGSMainConnectionID(),
            0,
            count,
            &list,
            &realCount
        )
        guard result == .success, realCount > 0 else {
            return []
        }
        return Array(list.prefix(Int(realCount)))
    }

    static func menuBarWindowIDs(onActiveSpaceOnly: Bool) -> [CGWindowID] {
        let ids = menuBarWindowIDs()
        guard onActiveSpaceOnly else { return ids }
        return ids.filter(isWindowOnActiveSpace)
    }

    static func isWindowOnActiveSpace(_ windowID: CGWindowID) -> Bool {
        getSpaceList(for: windowID, mask: .allSpaces).contains(activeSpaceID)
    }

    static func getSpaceList(for windowID: CGWindowID, mask: CGSSpaceMask) -> [CGSSpaceID] {
        let ids = [windowID] as CFArray
        guard let spaces = CGSCopySpacesForWindows(CGSMainConnectionID(), mask, ids),
              let spaceIDs = spaces.takeRetainedValue() as? [CGSSpaceID] else {
            return []
        }
        return spaceIDs
    }

    static func frame(for windowID: CGWindowID) -> CGRect? {
        var rect = CGRect.zero
        guard CGSGetScreenRectForWindow(CGSMainConnectionID(), windowID, &rect) == .success else {
            return nil
        }
        return rect
    }

    static func windowDescriptions(for windowIDs: [CGWindowID]) -> [[String: Any]] {
        guard !windowIDs.isEmpty else { return [] }
        var pointers = windowIDs.map { UnsafeRawPointer(bitPattern: Int($0)) }
        guard let array = CFArrayCreate(kCFAllocatorDefault, &pointers, pointers.count, nil),
              let descriptions = CGWindowListCreateDescriptionFromArray(array) as? [[String: Any]] else {
            return []
        }
        return descriptions
    }

    static func hasMenuBarWindowTitleAccess(currentPID: pid_t = ProcessInfo.processInfo.processIdentifier) -> Bool {
        let ids = menuBarWindowIDs(onActiveSpaceOnly: true)
        let descriptions = windowDescriptions(for: ids)
        for description in descriptions {
            guard let ownerPID = description[kCGWindowOwnerPID as String] as? pid_t,
                  ownerPID != currentPID else {
                continue
            }
            if description[kCGWindowName as String] as? String != nil {
                return true
            }
        }
        return false
    }
}
