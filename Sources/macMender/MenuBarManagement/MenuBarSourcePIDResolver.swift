import AppKit
import ApplicationServices
@preconcurrency import CoreGraphics
import Foundation
import MacMenderMenuBarEngine

// Adapted from Thaw's SourcePIDCache (GPL-3.0).
// Source: https://github.com/stonerl/Thaw
// Thaw revision used during the port: 2a8301cda7fdfbabe3723442036b293b8a490504.

/// Resolves the application that originally created a menu bar item window.
///
/// On recent macOS releases, many status item windows are hosted by Control
/// Center even when the item belongs to another app. Thaw resolves the source
/// process by matching WindowServer item window frames to Accessibility
/// children in each app's extras menu bar. macMender asks its bundled XPC
/// service first, matching Thaw's architecture, and keeps the in-process path
/// as a development fallback if the helper cannot be launched.
final class MenuBarSourcePIDResolver: @unchecked Sendable {
    static let shared = MenuBarSourcePIDResolver()

    private struct CachedApplication {
        var app: NSRunningApplication
        var extrasMenuBar: AXUIElement?
        var checkedWithNoResult = false
    }

    private let lock = NSLock()
    private var cachedApps: [pid_t: CachedApplication] = [:]
    private var pidsByWindowID: [CGWindowID: pid_t] = [:]

    private init() {}

    func sourcePIDs(for windows: [MenuBarWindowInfo]) -> [CGWindowID: pid_t] {
        guard AXIsProcessTrusted() else { return [:] }

        if let resolvedByService = sourcePIDsFromXPC(for: windows) {
            return resolvedByService
        }

        lock.lock()
        let cached = pidsByWindowID
        lock.unlock()

        if windows.allSatisfy({ cached[$0.windowID] != nil }) {
            return cached.filter { key, _ in windows.contains { $0.windowID == key } }
        }

        let resolved = resolveAllMenuBarWindows()
        lock.lock()
        for (windowID, pid) in resolved {
            pidsByWindowID[windowID] = pid
        }
        let result = pidsByWindowID.filter { key, _ in windows.contains { $0.windowID == key } }
        lock.unlock()
        return result
    }

    private func sourcePIDsFromXPC(for windows: [MenuBarWindowInfo]) -> [CGWindowID: pid_t]? {
        guard !windows.isEmpty else { return [:] }

        let payload = windows.map { window -> NSDictionary in
            [
                "windowID": NSNumber(value: window.windowID),
                "x": NSNumber(value: Double(window.frame.origin.x)),
                "y": NSNumber(value: Double(window.frame.origin.y)),
                "width": NSNumber(value: Double(window.frame.size.width)),
                "height": NSNumber(value: Double(window.frame.size.height))
            ] as NSDictionary
        } as NSArray

        let connection = NSXPCConnection(serviceName: MacMenderMenuBarItemServiceConstants.serviceName)
        connection.remoteObjectInterface = NSXPCInterface(with: MacMenderMenuBarItemServiceProtocol.self)

        let semaphore = DispatchSemaphore(value: 0)
        let lock = NSLock()
        var response: NSDictionary?
        var didFail = false
        var didReceiveResponse = false

        connection.interruptionHandler = {
            lock.lock()
            if !didReceiveResponse {
                didFail = true
            }
            lock.unlock()
            semaphore.signal()
        }
        connection.invalidationHandler = {
            lock.lock()
            if !didReceiveResponse {
                didFail = true
            }
            lock.unlock()
            semaphore.signal()
        }
        connection.resume()

        guard let proxy = connection.remoteObjectProxyWithErrorHandler({ _ in
            lock.lock()
            didFail = true
            lock.unlock()
            semaphore.signal()
        }) as? MacMenderMenuBarItemServiceProtocol else {
            connection.invalidate()
            return nil
        }

        proxy.sourcePIDs(forWindows: payload) { dictionary in
            lock.lock()
            response = dictionary
            didReceiveResponse = true
            lock.unlock()
            semaphore.signal()
        }

        let status = semaphore.wait(timeout: .now() + 1.75)
        connection.invalidate()
        guard status == .success else { return nil }

        lock.lock()
        let finalResponse = response
        let failed = didFail
        lock.unlock()

        guard !failed, let finalResponse else { return nil }
        var result = [CGWindowID: pid_t]()
        for (key, value) in finalResponse {
            guard let key = key as? NSNumber,
                  let value = value as? NSNumber else {
                continue
            }
            result[CGWindowID(truncating: key)] = pid_t(truncating: value)
        }
        return result
    }

    private func resolveAllMenuBarWindows() -> [CGWindowID: pid_t] {
        let windows = MenuBarPrivateBridge
            .windowDescriptions(for: MenuBarPrivateBridge.menuBarWindowIDs(onActiveSpaceOnly: true))
            .compactMap(MenuBarWindowInfo.init(dictionary:))
            .filter { $0.frame.width > 0 && $0.frame.height > 0 }

        let runningApps = NSWorkspace.shared.runningApplications
            .filter { !$0.isTerminated && $0.isFinishedLaunching }

        lock.lock()
        var apps = runningApps.map { running -> CachedApplication in
            if var cached = cachedApps[running.processIdentifier] {
                cached.app = running
                return cached
            }
            return CachedApplication(app: running)
        }
        lock.unlock()

        var unresolved = Set(windows.map(\.windowID))
        var result: [CGWindowID: pid_t] = [:]

        for appIndex in apps.indices {
            guard !unresolved.isEmpty else { break }
            guard let extrasMenuBar = extrasMenuBar(for: &apps[appIndex]) else { continue }
            for child in children(of: extrasMenuBar) {
                guard isEnabled(child), let childFrame = frame(of: child) else { continue }
                let childCenter = CGPoint(x: childFrame.midX, y: childFrame.midY)
                guard let matched = windows.first(where: { window in
                    unresolved.contains(window.windowID) &&
                        distance(CGPoint(x: window.frame.midX, y: window.frame.midY), childCenter) <= 1.5
                }) else { continue }

                result[matched.windowID] = apps[appIndex].app.processIdentifier
                unresolved.remove(matched.windowID)
            }
        }

        lock.lock()
        cachedApps = Dictionary(uniqueKeysWithValues: apps.map { ($0.app.processIdentifier, $0) })
        lock.unlock()

        return result
    }

    private func extrasMenuBar(for cached: inout CachedApplication) -> AXUIElement? {
        if let extrasMenuBar = cached.extrasMenuBar { return extrasMenuBar }
        if cached.checkedWithNoResult { return nil }

        let appElement = AXUIElementCreateApplication(cached.app.processIdentifier)
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, "AXExtrasMenuBar" as CFString, &value)
        guard result == .success, let element = value else {
            cached.checkedWithNoResult = true
            return nil
        }

        let extrasMenuBar = element as! AXUIElement
        cached.extrasMenuBar = extrasMenuBar
        return extrasMenuBar
    }

    private func children(of element: AXUIElement) -> [AXUIElement] {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &value) == .success,
              let children = value as? [AXUIElement] else {
            return []
        }
        return children
    }

    private func isEnabled(_ element: AXUIElement) -> Bool {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXEnabledAttribute as CFString, &value) == .success else {
            return false
        }
        return (value as? Bool) == true
    }

    private func frame(of element: AXUIElement) -> CGRect? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXFrame" as CFString, &value) == .success,
              let axValue = value else {
            return nil
        }

        var frame = CGRect.zero
        guard AXValueGetValue((axValue as! AXValue), .cgRect, &frame) else { return nil }
        return frame
    }

    private func distance(_ lhs: CGPoint, _ rhs: CGPoint) -> CGFloat {
        hypot(lhs.x - rhs.x, lhs.y - rhs.y)
    }
}
