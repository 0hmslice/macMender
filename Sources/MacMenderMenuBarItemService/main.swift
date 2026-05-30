//
//  main.swift
//  macMender
//
//  XPC source-PID helper modeled after Thaw's MenuBarItemService.
//
//  Copyright (Thaw) © 2026 Toni Förster
//  Copyright (Ice) © 2023–2025 Jordan Baird
//  Adapted for macMender under GPL-compatible terms.
//

import AppKit
import ApplicationServices
import Foundation
import os.lock

@objc(MacMenderMenuBarItemServiceProtocol)
private protocol MacMenderMenuBarItemServiceProtocol {
    func ping(withReply reply: @escaping (Bool) -> Void)
    func sourcePIDs(forWindows windows: NSArray, withReply reply: @escaping (NSDictionary) -> Void)
}

private struct ServiceWindow: Hashable, Sendable {
    var windowID: CGWindowID
    var frame: CGRect

    init?(dictionary: NSDictionary) {
        guard let windowID = dictionary["windowID"] as? NSNumber,
              let x = dictionary["x"] as? NSNumber,
              let y = dictionary["y"] as? NSNumber,
              let width = dictionary["width"] as? NSNumber,
              let height = dictionary["height"] as? NSNumber else {
            return nil
        }
        self.windowID = CGWindowID(truncating: windowID)
        self.frame = CGRect(
            x: CGFloat(truncating: x),
            y: CGFloat(truncating: y),
            width: CGFloat(truncating: width),
            height: CGFloat(truncating: height)
        )
    }
}

private final class SourcePIDCache: @unchecked Sendable {
    static let shared = SourcePIDCache()

    private struct CachedApplication: @unchecked Sendable {
        var app: NSRunningApplication
        var extrasMenuBar: AXUIElement?
        var checkedWithNoResult = false
    }

    private let lock = OSAllocatedUnfairLock(initialState: [CGWindowID: pid_t]())
    private let appLock = OSAllocatedUnfairLock(initialState: [pid_t: CachedApplication]())
    private let scanLock = OSAllocatedUnfairLock(initialState: ())

    func sourcePIDs(for windows: [ServiceWindow]) -> [CGWindowID: pid_t] {
        autoreleasepool {
            sourcePIDsBody(for: windows)
        }
    }

    private func sourcePIDsBody(for windows: [ServiceWindow]) -> [CGWindowID: pid_t] {
        guard AXIsProcessTrusted(), !windows.isEmpty else { return [:] }

        let cached = lock.withLock { cache in
            Dictionary(uniqueKeysWithValues: windows.compactMap { window in
                cache[window.windowID].map { (window.windowID, $0) }
            })
        }
        if cached.count == windows.count {
            return cached
        }

        scanLock.lock()
        defer { scanLock.unlock() }

        let runningApps = NSWorkspace.shared.runningApplications
            .filter { !$0.isTerminated && $0.isFinishedLaunching }

        var apps = appLock.withLock { cachedApps -> [CachedApplication] in
            var rebuilt = [pid_t: CachedApplication]()
            for app in runningApps {
                if var cached = cachedApps[app.processIdentifier] {
                    cached.app = app
                    rebuilt[app.processIdentifier] = cached
                } else {
                    rebuilt[app.processIdentifier] = CachedApplication(app: app)
                }
            }
            cachedApps = rebuilt
            return Array(rebuilt.values).sorted { lhs, rhs in
                if (lhs.extrasMenuBar != nil) != (rhs.extrasMenuBar != nil) {
                    return lhs.extrasMenuBar != nil
                }
                return lhs.app.processIdentifier < rhs.app.processIdentifier
            }
        }

        var unresolved = Set(windows.map(\.windowID))
        for index in apps.indices {
            guard !unresolved.isEmpty else { break }
            guard let extrasMenuBar = extrasMenuBar(for: &apps[index]) else { continue }

            for child in children(of: extrasMenuBar) {
                guard isEnabled(child), let childFrame = frame(of: child) else { continue }
                let childCenter = CGPoint(x: childFrame.midX, y: childFrame.midY)
                guard let matched = windows.first(where: { window in
                    unresolved.contains(window.windowID) &&
                        distance(CGPoint(x: window.frame.midX, y: window.frame.midY), childCenter) <= 1.5
                }) else {
                    continue
                }

                unresolved.remove(matched.windowID)
                let pid = apps[index].app.processIdentifier
                lock.withLock { $0[matched.windowID] = pid }
            }
        }

        let updatedApps = apps
        appLock.withLock { cachedApps in
            for app in updatedApps {
                cachedApps[app.app.processIdentifier] = app
            }
        }

        return lock.withLock { cache in
            Dictionary(uniqueKeysWithValues: windows.compactMap { window in
                cache[window.windowID].map { (window.windowID, $0) }
            })
        }
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

private final class MacMenderMenuBarItemService: NSObject, MacMenderMenuBarItemServiceProtocol {
    func ping(withReply reply: @escaping (Bool) -> Void) {
        reply(true)
    }

    func sourcePIDs(forWindows windows: NSArray, withReply reply: @escaping (NSDictionary) -> Void) {
        let parsed = windows.compactMap { ($0 as? NSDictionary).flatMap(ServiceWindow.init(dictionary:)) }
        let pids = SourcePIDCache.shared.sourcePIDs(for: parsed)
        let response = NSMutableDictionary(capacity: pids.count)
        for (windowID, pid) in pids {
            response[NSNumber(value: windowID)] = NSNumber(value: pid)
        }
        reply(response)
    }
}

private final class MacMenderMenuBarItemServiceDelegate: NSObject, NSXPCListenerDelegate {
    private let service = MacMenderMenuBarItemService()

    func listener(
        _ listener: NSXPCListener,
        shouldAcceptNewConnection connection: NSXPCConnection
    ) -> Bool {
        connection.exportedInterface = NSXPCInterface(with: MacMenderMenuBarItemServiceProtocol.self)
        connection.exportedObject = service
        connection.resume()
        return true
    }
}

private let delegate = MacMenderMenuBarItemServiceDelegate()
private let listener = NSXPCListener.service()
listener.delegate = delegate
listener.resume()

while true {
    autoreleasepool {
        _ = RunLoop.current.run(mode: .default, before: Date(timeIntervalSinceNow: 60))
    }
}
