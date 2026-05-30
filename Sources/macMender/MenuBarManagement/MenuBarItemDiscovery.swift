import AppKit
import Foundation

struct MenuBarItemDiscovery {
    func items(onScreenOnly: Bool, activeSpaceOnly: Bool = true) -> [MenuBarPhysicalItem] {
        let ids = Array(MenuBarPrivateBridge.menuBarWindowIDs(onActiveSpaceOnly: activeSpaceOnly).reversed())
        let descriptions = MenuBarPrivateBridge.windowDescriptions(for: ids)
        let currentPID = ProcessInfo.processInfo.processIdentifier
        let windows = descriptions.compactMap(MenuBarWindowInfo.init(dictionary:))
        let sourcePIDs = MenuBarSourcePIDResolver.shared.sourcePIDs(for: windows)

        let resolvedWindows = windows
            .map { window -> MenuBarWindowInfo in
                var resolved = window
                if let sourcePID = sourcePIDs[window.windowID],
                   sourcePID != currentPID || MenuBarControlIdentifier.isControlTitle(window.title ?? "") {
                    resolved.sourcePID = sourcePID
                }
                return resolved
            }

        let propagatedWindows = propagateSourcePIDsForMultiItemApps(in: resolvedWindows)

        var items = propagatedWindows
            .compactMap(MenuBarPhysicalItem.init(window:))
            .filter { item in
                guard item.ownerPID != currentPID || item.isInternalControlItem else { return false }
                guard item.ownerName != "Window Server", item.ownerName != "Dock" else { return false }
                guard item.frame.width > 0, item.frame.height > 0 else { return false }
                guard !onScreenOnly || item.isOnScreen else { return false }
                guard !activeSpaceOnly || item.isOnActiveSpace else { return false }
                return true
            }

        MenuBarDiscoveryNormalizer.assignStableInstanceIndices(to: &items)
        return MenuBarDiscoveryNormalizer.collapseDuplicateTransientWindows(in: items)
    }

    private func propagateSourcePIDsForMultiItemApps(in windows: [MenuBarWindowInfo]) -> [MenuBarWindowInfo] {
        let unresolvedIndices = windows.indices.filter { windows[$0].sourcePID == nil }
        guard !unresolvedIndices.isEmpty else { return windows }

        var resolvedCountByPID = [pid_t: Int]()
        var titleToPID = [String: ResolvedPID]()
        for window in windows {
            guard let sourcePID = window.sourcePID else { continue }
            resolvedCountByPID[sourcePID, default: 0] += 1
            guard let title = window.title else { continue }
            switch titleToPID[title] {
            case nil:
                titleToPID[title] = .resolved(sourcePID)
            case .resolved(let existingPID) where existingPID != sourcePID:
                titleToPID[title] = .ambiguous
            default:
                break
            }
        }

        var result = windows
        for index in unresolvedIndices {
            guard let title = windows[index].title,
                  case .resolved(let siblingPID) = titleToPID[title],
                  resolvedCountByPID[siblingPID, default: 0] >= 2 else {
                continue
            }
            result[index].sourcePID = siblingPID
        }
        return result
    }

    private enum ResolvedPID {
        case resolved(pid_t)
        case ambiguous
    }
}

enum MenuBarDiscoveryNormalizer {
    static func assignStableInstanceIndices(to items: inout [MenuBarPhysicalItem]) {
        var groups = [String: [Int]]()
        for index in items.indices {
            let key = "\(items[index].identity.namespace.rawValue):\(items[index].identity.title)"
            groups[key, default: []].append(index)
        }

        for indices in groups.values where indices.count > 1 {
            let sorted = indices.sorted { items[$0].windowID < items[$1].windowID }
            for (instanceIndex, itemIndex) in sorted.enumerated() {
                items[itemIndex] = items[itemIndex].withInstanceIndex(instanceIndex)
            }
        }
    }

    static func collapseDuplicateTransientWindows(in items: [MenuBarPhysicalItem]) -> [MenuBarPhysicalItem] {
        var result = [MenuBarPhysicalItem]()
        var indexByIdentity = [String: Int]()
        for item in items {
            if let existingIndex = indexByIdentity[item.identity.description] {
                result[existingIndex] = preferredItem(result[existingIndex], item)
            } else {
                indexByIdentity[item.identity.description] = result.count
                result.append(item)
            }
        }
        return result
    }

    private static func preferredItem(_ lhs: MenuBarPhysicalItem, _ rhs: MenuBarPhysicalItem) -> MenuBarPhysicalItem {
        if lhs.isOnScreen != rhs.isOnScreen { return lhs.isOnScreen ? lhs : rhs }
        if lhs.frame.width != rhs.frame.width { return lhs.frame.width > rhs.frame.width ? lhs : rhs }
        return lhs.windowID < rhs.windowID ? lhs : rhs
    }
}

enum MenuBarSectionResolver {
    static func cache(from items: [MenuBarPhysicalItem]) -> MenuBarItemCache {
        var mutableItems = items
        let hiddenControl = mutableItems.firstIndex { $0.title == MenuBarControlIdentifier.hidden }.map { mutableItems.remove(at: $0) }
        let alwaysHiddenControl = mutableItems.firstIndex { $0.title == MenuBarControlIdentifier.alwaysHidden }.map { mutableItems.remove(at: $0) }

        guard let hiddenControl else { return MenuBarItemCache() }

        let userItems = mutableItems.filter { !$0.isInternalControlItem }
        var result = MenuBarItemCache()
        for item in userItems {
            guard item.isMovable, item.canBeHidden else { continue }
            if let section = section(for: item, hiddenControl: hiddenControl, alwaysHiddenControl: alwaysHiddenControl) {
                switch section {
                case .pinned:
                    result.visible.append(item)
                case .overflow:
                    result.hidden.append(item)
                case .hidden:
                    result.alwaysHidden.append(item)
                }
            } else {
                // Thaw keeps straddling or temporarily ambiguous items in the
                // hidden cache instead of letting them fall through to Visible.
                // This prevents the UI from claiming an icon is visible while
                // it is physically tucked behind the hidden divider.
                result.hidden.append(item)
            }
        }
        return result
    }

    private static func section(
        for item: MenuBarPhysicalItem,
        hiddenControl: MenuBarPhysicalItem,
        alwaysHiddenControl: MenuBarPhysicalItem?
    ) -> MenuBarSection? {
        let itemFrame = item.frame
        let hiddenFrame = hiddenControl.frame
        if itemFrame.minX >= hiddenFrame.maxX {
            return .pinned
        }
        if itemFrame.maxX <= hiddenFrame.minX {
            if let alwaysHiddenControl {
                let alwaysHiddenFrame = alwaysHiddenControl.frame
                if itemFrame.minX >= alwaysHiddenFrame.maxX {
                    return .overflow
                }
                if itemFrame.maxX <= alwaysHiddenFrame.minX {
                    return .hidden
                }
            } else {
                return .overflow
            }
        }

        // Ported from Thaw's CacheContext.findSection fallback. Menu bar
        // divider windows can briefly overlap item bounds while expanding or
        // collapsing. Midpoint classification keeps the layout view aligned
        // with the real physical section instead of misclassifying as Visible.
        let itemMid = itemFrame.midX
        let hiddenMid = hiddenFrame.midX
        if itemMid >= hiddenMid {
            return .pinned
        }
        if let alwaysHiddenControl {
            return itemMid >= alwaysHiddenControl.frame.midX ? .overflow : .hidden
        }
        return .overflow
    }

    static func actualSectionMap(from cache: MenuBarItemCache) -> [String: MenuBarSection] {
        var sections = [String: MenuBarSection]()
        for item in cache.visible {
            sections[item.identity.description] = .pinned
        }
        for item in cache.hidden {
            sections[item.identity.description] = .overflow
        }
        for item in cache.alwaysHidden {
            sections[item.identity.description] = .hidden
        }
        return sections
    }

    static func detectedItems(from items: [MenuBarPhysicalItem], cache: MenuBarItemCache) -> [DetectedMenuBarItem] {
        let actualSections = actualSectionMap(from: cache)
        return items
            .filter { !$0.isInternalControlItem }
            .map { item in
                item.detectedItem(actualSection: actualSections[item.identity.description] ?? .pinned)
            }
    }
}
