import ApplicationServices
import CoreGraphics
import Foundation

/// Private window-server and Accessibility entry points used for Dock previews and window switching.
///
/// Every symbol is resolved at run time. If macOS removes or renames one, the matching wrapper
/// returns `nil`/`false` and callers fall back to public API instead of failing to launch.
enum PrivateWindowAPI {
    struct SpaceSnapshot: Sendable, Equatable {
        /// Spaces currently shown on any display.
        var currentSpaceIDs: Set<UInt64>
        /// Spaces that host a full-screen or tiled application.
        var fullScreenSpaceIDs: Set<UInt64>

        static let empty = SpaceSnapshot(currentSpaceIDs: [], fullScreenSpaceIDs: [])
    }

    private typealias MainConnectionFn = @convention(c) () -> Int32
    private typealias CopySpacesForWindowsFn = @convention(c) (Int32, Int32, CFArray) -> Unmanaged<CFArray>?
    private typealias CopyManagedDisplaySpacesFn = @convention(c) (Int32) -> Unmanaged<CFArray>?
    private typealias CaptureWindowListFn = @convention(c) (Int32, UnsafeMutablePointer<CGWindowID>, UInt32, UInt32) -> Unmanaged<CFArray>?
    private typealias GetProcessForPIDFn = @convention(c) (pid_t, UnsafeMutablePointer<ProcessSerialNumber>) -> OSStatus
    private typealias SetFrontProcessFn = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, CGWindowID, UInt32) -> CGError
    private typealias PostEventRecordFn = @convention(c) (UnsafeMutablePointer<ProcessSerialNumber>, UnsafeMutablePointer<UInt8>) -> CGError
    private typealias AXGetWindowFn = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError
    private typealias AXCreateWithRemoteTokenFn = @convention(c) (CFData) -> Unmanaged<AXUIElement>?

    private static func resolve<T>(_ names: String..., as type: T.Type) -> T? {
        // SkyLight is already loaded by AppKit; opening it again only guarantees symbol visibility.
        _ = dlopen("/System/Library/PrivateFrameworks/SkyLight.framework/SkyLight", RTLD_LAZY)
        let defaultHandle = UnsafeMutableRawPointer(bitPattern: -2) // RTLD_DEFAULT
        for name in names {
            if let pointer = dlsym(defaultHandle, name) {
                return unsafeBitCast(pointer, to: type)
            }
        }
        return nil
    }

    private static let mainConnection = resolve("CGSMainConnectionID", "SLSMainConnectionID", as: MainConnectionFn.self)
    private static let copySpacesForWindows = resolve("CGSCopySpacesForWindows", "SLSCopySpacesForWindows", as: CopySpacesForWindowsFn.self)
    private static let copyManagedDisplaySpaces = resolve("CGSCopyManagedDisplaySpaces", "SLSCopyManagedDisplaySpaces", as: CopyManagedDisplaySpacesFn.self)
    private static let captureWindowList = resolve("CGSHWCaptureWindowList", "SLSHWCaptureWindowList", as: CaptureWindowListFn.self)
    private static let getProcessForPID = resolve("GetProcessForPID", as: GetProcessForPIDFn.self)
    private static let setFrontProcess = resolve("_SLPSSetFrontProcessWithOptions", as: SetFrontProcessFn.self)
    private static let postEventRecord = resolve("SLPSPostEventRecordTo", as: PostEventRecordFn.self)
    private static let axGetWindow = resolve("_AXUIElementGetWindow", as: AXGetWindowFn.self)
    private static let axCreateWithRemoteToken = resolve("_AXUIElementCreateWithRemoteToken", as: AXCreateWithRemoteTokenFn.self)

    static var canFocusSingleWindow: Bool {
        getProcessForPID != nil && setFrontProcess != nil && postEventRecord != nil
    }

    static var canCaptureWindows: Bool {
        mainConnection != nil && captureWindowList != nil
    }

    static var canEnumerateAllSpaces: Bool {
        axCreateWithRemoteToken != nil && mainConnection != nil && copySpacesForWindows != nil
    }

    // MARK: Window identity

    static func windowID(of element: AXUIElement) -> CGWindowID? {
        guard let axGetWindow else { return nil }
        var windowID: CGWindowID = 0
        guard axGetWindow(element, &windowID) == .success, windowID != 0 else { return nil }
        return windowID
    }

    /// Accessibility only lists windows on the visible Spaces. Window elements on other Spaces can
    /// still be addressed through their remote token, so probe a bounded range of element IDs.
    static func windowElementsOnAllSpaces(pid: pid_t, probeLimit: UInt64 = 1000, timeBudget: TimeInterval = 0.12) -> [AXUIElement] {
        guard let axCreateWithRemoteToken else { return [] }
        let deadline = Date().addingTimeInterval(timeBudget)
        var elements = [AXUIElement]()
        var token = Data(count: 20)
        token.replaceSubrange(0..<4, with: withUnsafeBytes(of: pid) { Data($0) })
        token.replaceSubrange(4..<8, with: withUnsafeBytes(of: Int32(0)) { Data($0) })
        token.replaceSubrange(8..<12, with: withUnsafeBytes(of: Int32(0x636f_636f)) { Data($0) })

        for elementID in 0..<probeLimit {
            token.replaceSubrange(12..<20, with: withUnsafeBytes(of: elementID) { Data($0) })
            guard let element = axCreateWithRemoteToken(token as CFData)?.takeRetainedValue() else { continue }
            var subroleValue: CFTypeRef?
            if AXUIElementCopyAttributeValue(element, kAXSubroleAttribute as CFString, &subroleValue) == .success,
               let subrole = subroleValue as? String,
               subrole == kAXStandardWindowSubrole as String || subrole == kAXDialogSubrole as String {
                elements.append(element)
            }
            if elementID % 64 == 63, Date() > deadline { break }
        }
        return elements
    }

    // MARK: Spaces

    static func spaceIDs(for windowID: CGWindowID) -> [UInt64] {
        guard let mainConnection, let copySpacesForWindows else { return [] }
        let allSpacesMask: Int32 = 7
        guard let result = copySpacesForWindows(mainConnection(), allSpacesMask, [windowID] as CFArray)?.takeRetainedValue() else {
            return []
        }
        return (result as? [NSNumber])?.map(\.uint64Value) ?? []
    }

    static func spaceSnapshot() -> SpaceSnapshot {
        guard let mainConnection, let copyManagedDisplaySpaces,
              let displays = copyManagedDisplaySpaces(mainConnection())?.takeRetainedValue() as? [[String: Any]] else {
            return .empty
        }

        var snapshot = SpaceSnapshot.empty
        for display in displays {
            if let current = display["Current Space"] as? [String: Any],
               let identifier = (current["id64"] as? NSNumber)?.uint64Value {
                snapshot.currentSpaceIDs.insert(identifier)
            }
            for space in display["Spaces"] as? [[String: Any]] ?? [] {
                guard let identifier = (space["id64"] as? NSNumber)?.uint64Value,
                      let type = (space["type"] as? NSNumber)?.intValue else { continue }
                // 0 is a regular desktop; 4 is a full-screen or tiled application Space.
                if type == 4 {
                    snapshot.fullScreenSpaceIDs.insert(identifier)
                }
            }
        }
        return snapshot
    }

    // MARK: Capture

    /// Captures a window's current contents even when it is covered, minimized, or on another Space.
    /// Requires Screen Recording permission.
    /// `fullResolution` captures at the display's pixel density instead of one pixel per point.
    static func captureWindow(_ windowID: CGWindowID, fullResolution: Bool = false) -> CGImage? {
        guard let mainConnection, let captureWindowList else { return nil }
        let ignoreGlobalClipShape: UInt32 = 1 << 11
        let resolution: UInt32 = fullResolution ? 1 << 8 : 1 << 9
        var identifier = windowID
        guard let images = captureWindowList(mainConnection(), &identifier, 1, ignoreGlobalClipShape | resolution)?
            .takeRetainedValue() as? [CGImage] else {
            return nil
        }
        return images.first
    }

    // MARK: Focus

    /// Brings exactly one window forward and makes it key, switching Space if needed, without
    /// raising the application's other windows.
    @discardableResult
    static func focusWindow(pid: pid_t, windowID: CGWindowID) -> Bool {
        guard let getProcessForPID, let setFrontProcess, let postEventRecord else { return false }
        var psn = ProcessSerialNumber()
        guard getProcessForPID(pid, &psn) == noErr else { return false }

        let userGenerated: UInt32 = 0x200
        guard setFrontProcess(&psn, windowID, userGenerated) == .success else { return false }

        var record = [UInt8](repeating: 0, count: 0xf8)
        record[0x04] = 0xf8
        record[0x3a] = 0x10
        withUnsafeBytes(of: windowID) { bytes in
            for (offset, byte) in bytes.enumerated() {
                record[0x3c + offset] = byte
            }
        }
        for offset in 0x20..<0x30 {
            record[offset] = 0xff
        }
        record[0x08] = 0x01
        _ = postEventRecord(&psn, &record)
        record[0x08] = 0x02
        _ = postEventRecord(&psn, &record)
        return true
    }
}
