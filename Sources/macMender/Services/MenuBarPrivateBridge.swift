import AppKit
import CoreGraphics

typealias CGSConnectionID = Int32

@_silgen_name("CGSMainConnectionID")
func CGSMainConnectionID() -> CGSConnectionID

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
}
