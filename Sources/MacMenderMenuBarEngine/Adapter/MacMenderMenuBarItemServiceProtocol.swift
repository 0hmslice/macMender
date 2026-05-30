//
//  MacMenderMenuBarItemServiceProtocol.swift
//  macMender
//
//  GPL-compatible XPC boundary modeled after Thaw's MenuBarItemService.
//  Upstream references:
//  - Ice for macOS: https://github.com/jordanbaird/Ice
//  - Thaw: https://github.com/stonerl/Thaw
//

import Foundation

public enum MacMenderMenuBarItemServiceConstants {
    public static let serviceName = "com.ryan.macMender.MenuBarItemService"
}

@objc(MacMenderMenuBarItemServiceProtocol)
public protocol MacMenderMenuBarItemServiceProtocol {
    func ping(withReply reply: @escaping (Bool) -> Void)
    func sourcePIDs(forWindows windows: NSArray, withReply reply: @escaping (NSDictionary) -> Void)
}

