//
//  MenuBarItemTag.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023-2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Adapted for macMender © 2026 Ryan
//  Licensed under the GNU GPLv3
//

import Foundation

/// Stable identity for a physical menu bar item.
///
/// This is adapted from Thaw's `MenuBarItemTag`. macMender keeps the same
/// `namespace:title[:instanceIndex]` persistence shape because it is the
/// part of Thaw that keeps multi-icon apps such as Stats, Hammerspoon, and
/// iStat Menus in their designated sections across relaunches.
public struct MenuBarItemTag: Hashable, Codable, Sendable, CustomStringConvertible {
    public struct Namespace: Hashable, Codable, Sendable, RawRepresentable, CustomStringConvertible {
        public var rawValue: String
        public var description: String { rawValue }

        public init(rawValue: String) {
            self.rawValue = rawValue
        }

        public init(_ rawValue: String?) {
            self.rawValue = rawValue ?? "<null>"
        }
    }

    public var namespace: Namespace
    public var title: String
    public var instanceIndex: Int

    public init(namespace: Namespace, title: String, instanceIndex: Int = 0) {
        self.namespace = namespace
        self.title = title
        self.instanceIndex = instanceIndex
    }

    public var description: String { tagIdentifier }

    public var tagIdentifier: String {
        if instanceIndex > 0 {
            return "\(namespace.rawValue):\(title):\(instanceIndex)"
        }
        return "\(namespace.rawValue):\(title)"
    }

    public var canBeHidden: Bool {
        !Self.nonHideableTags.contains(self)
    }

    public var isMovable: Bool {
        !Self.immovableTags.contains(self) && !title.hasPrefix("BentoBox")
    }

    public var isControlCenterGenericItem: Bool {
        namespace == .controlCenter && (title == "CombinedModules" || title.range(of: #"^Item-\d+$"#, options: .regularExpression) != nil)
    }

    public func withInstanceIndex(_ instanceIndex: Int) -> Self {
        var copy = self
        copy.instanceIndex = instanceIndex
        return copy
    }
}

public extension MenuBarItemTag.Namespace {
    static let macMender = Self("com.ryan.macMender")
    static let controlCenter = Self("com.apple.controlcenter")
    static let systemUIServer = Self("com.apple.systemuiserver")
}

public extension MenuBarItemTag {
    static let visibleControlItem = Self(namespace: .macMender, title: "macMender.ControlItem.Visible")
    static let hiddenControlItem = Self(namespace: .macMender, title: "macMender.ControlItem.Hidden")
    static let alwaysHiddenControlItem = Self(namespace: .macMender, title: "macMender.ControlItem.AlwaysHidden")
    static let clock = Self(namespace: .controlCenter, title: "Clock")
    static let siri = Self(namespace: .systemUIServer, title: "Siri")
    static let controlCenterItem = Self(namespace: .controlCenter, title: "BentoBox")
    static let audioVideoModule = Self(namespace: .controlCenter, title: "AudioVideoModule")
    static let faceTime = Self(namespace: .controlCenter, title: "FaceTime")
    static let musicRecognition = Self(namespace: .controlCenter, title: "MusicRecognition")

    static let immovableTags: Set<Self> = [
        .clock,
        .siri,
        .controlCenterItem
    ]

    static let nonHideableTags: Set<Self> = [
        .audioVideoModule,
        .faceTime,
        .musicRecognition
    ]
}
