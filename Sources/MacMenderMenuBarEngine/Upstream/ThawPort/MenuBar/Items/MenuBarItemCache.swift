//
//  MenuBarItemCache.swift
//  Project: Thaw
//
//  Copyright (Ice) © 2023-2025 Jordan Baird
//  Copyright (Thaw) © 2026 Toni Förster
//  Adapted for macMender © 2026 Ryan
//  Licensed under the GNU GPLv3
//

import Foundation

public struct MenuBarItemRecord: Hashable, Codable, Sendable {
    public var tag: MenuBarItemTag
    public var sourcePID: pid_t?
    public var width: Double

    public init(tag: MenuBarItemTag, sourcePID: pid_t? = nil, width: Double = 24) {
        self.tag = tag
        self.sourcePID = sourcePID
        self.width = width
    }
}

public enum MenuBarItemMoveDestination: Hashable, Sendable {
    case leftOfItem(MenuBarItemRecord)
    case rightOfItem(MenuBarItemRecord)

    public var targetItem: MenuBarItemRecord {
        switch self {
        case .leftOfItem(let item), .rightOfItem(let item):
            item
        }
    }
}

/// Sectioned cache adapted from Thaw's `MenuBarItemManager.ItemCache`.
public struct MenuBarItemCache: Hashable, Sendable {
    private var storage: [MenuBarEngineSection: [MenuBarItemRecord]]

    public init(storage: [MenuBarEngineSection: [MenuBarItemRecord]] = [:]) {
        self.storage = storage
    }

    public var managedItems: [MenuBarItemRecord] {
        MenuBarEngineSection.allCases.flatMap { storage[$0, default: []] }
    }

    public func managedItems(for section: MenuBarEngineSection) -> [MenuBarItemRecord] {
        self[section]
    }

    public func address(for tag: MenuBarItemTag) -> (section: MenuBarEngineSection, index: Int)? {
        for section in MenuBarEngineSection.allCases {
            guard let index = self[section].firstIndex(where: { $0.tag == tag }) else {
                continue
            }
            return (section, index)
        }
        return nil
    }

    public mutating func remove(tag: MenuBarItemTag) -> MenuBarItemRecord? {
        guard let address = address(for: tag) else { return nil }
        return storage[address.section, default: []].remove(at: address.index)
    }

    public mutating func insert(_ item: MenuBarItemRecord, at destination: MenuBarItemMoveDestination) {
        let targetTag = destination.targetItem.tag

        if targetTag == .hiddenControlItem {
            switch destination {
            case .leftOfItem:
                self[.hidden].append(item)
            case .rightOfItem:
                self[.visible].insert(item, at: 0)
            }
            return
        }

        if targetTag == .alwaysHiddenControlItem {
            switch destination {
            case .leftOfItem:
                self[.alwaysHidden].append(item)
            case .rightOfItem:
                self[.hidden].insert(item, at: 0)
            }
            return
        }

        guard case (let section, var index)? = address(for: targetTag) else {
            return
        }

        if case .rightOfItem = destination {
            index = Swift.min(index + 1, self[section].endIndex)
        }

        self[section].insert(item, at: index)
    }

    public subscript(section: MenuBarEngineSection) -> [MenuBarItemRecord] {
        get { storage[section, default: []] }
        set { storage[section] = newValue }
    }
}

public enum MenuBarItemInstanceIndexer {
    public static func assignStableInstanceIndices(to tags: [MenuBarItemTag], windowIDs: [UInt32]) -> [MenuBarItemTag] {
        precondition(tags.count == windowIDs.count)
        var indexed = tags
        var groups = [String: [Int]]()

        for index in tags.indices {
            let key = "\(tags[index].namespace.rawValue):\(tags[index].title)"
            groups[key, default: []].append(index)
        }

        for indices in groups.values where indices.count > 1 {
            let sorted = indices.sorted { windowIDs[$0] < windowIDs[$1] }
            for (instanceIndex, itemIndex) in sorted.enumerated() {
                indexed[itemIndex] = indexed[itemIndex].withInstanceIndex(instanceIndex)
            }
        }

        return indexed
    }
}
