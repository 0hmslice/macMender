import Foundation

enum MenuBarSection: String, CaseIterable, Codable, Identifiable {
    case pinned
    case overflow
    case hidden

    var id: String { rawValue }

    var title: String {
        switch self {
        case .pinned: "Visible"
        case .overflow: "Hidden"
        case .hidden: "Always Hidden"
        }
    }

    var shortTitle: String {
        switch self {
        case .pinned: "Visible"
        case .overflow: "Hidden"
        case .hidden: "Always"
        }
    }

    var detail: String {
        switch self {
        case .pinned:
            "Shown in the menu bar."
        case .overflow:
            "Hidden until Mendy or the reveal zone near Mendy brings it back."
        case .hidden:
            "Kept tucked away until you explicitly reveal it."
        }
    }
}

struct MenuBarItemModel: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var bundleIdentifier: String
    var section: MenuBarSection
    var controllabilityNote: String
}

struct MenuBarLiveOrderItem: Equatable {
    var key: String
    var title: String
    var section: MenuBarSection
}

struct MenuBarLayout: Codable, Equatable {
    var items: [MenuBarItemModel]
    var itemSpacingOffset: Int
    var showSectionDividers: Bool
    var autoRehideEnabled: Bool
    var autoRehideDelay: Double
    var revealOnHover: Bool
    var revealOnEmptyMenuBarClick: Bool
    var revealOnScroll: Bool
    var hideApplicationMenusOnOverlap: Bool
    var showHiddenItemsInSecondaryBar: Bool

    enum CodingKeys: String, CodingKey {
        case items
        case itemSpacingOffset
        case showSectionDividers
        case autoRehideEnabled
        case autoRehideDelay
        case revealOnHover
        case revealOnEmptyMenuBarClick
        case revealOnScroll
        case hideApplicationMenusOnOverlap
        case showHiddenItemsInSecondaryBar
    }

    init(
        items: [MenuBarItemModel],
        itemSpacingOffset: Int = 0,
        showSectionDividers: Bool = false,
        autoRehideEnabled: Bool = true,
        autoRehideDelay: Double = 1.0,
        revealOnHover: Bool = true,
        revealOnEmptyMenuBarClick: Bool = true,
        revealOnScroll: Bool = true,
        hideApplicationMenusOnOverlap: Bool = true,
        showHiddenItemsInSecondaryBar: Bool = false
    ) {
        self.items = items
        self.itemSpacingOffset = itemSpacingOffset
        self.showSectionDividers = showSectionDividers
        self.autoRehideEnabled = autoRehideEnabled
        self.autoRehideDelay = autoRehideDelay
        self.revealOnHover = revealOnHover
        self.revealOnEmptyMenuBarClick = revealOnEmptyMenuBarClick
        self.revealOnScroll = revealOnScroll
        self.hideApplicationMenusOnOverlap = hideApplicationMenusOnOverlap
        self.showHiddenItemsInSecondaryBar = showHiddenItemsInSecondaryBar
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([MenuBarItemModel].self, forKey: .items) ?? []
        itemSpacingOffset = try container.decodeIfPresent(Int.self, forKey: .itemSpacingOffset) ?? 0
        showSectionDividers = try container.decodeIfPresent(Bool.self, forKey: .showSectionDividers) ?? false
        autoRehideEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoRehideEnabled) ?? true
        autoRehideDelay = try container.decodeIfPresent(Double.self, forKey: .autoRehideDelay) ?? 1.0
        revealOnHover = try container.decodeIfPresent(Bool.self, forKey: .revealOnHover) ?? true
        revealOnEmptyMenuBarClick = try container.decodeIfPresent(Bool.self, forKey: .revealOnEmptyMenuBarClick) ?? true
        revealOnScroll = try container.decodeIfPresent(Bool.self, forKey: .revealOnScroll) ?? true
        hideApplicationMenusOnOverlap = try container.decodeIfPresent(Bool.self, forKey: .hideApplicationMenusOnOverlap) ?? true
        showHiddenItemsInSecondaryBar = try container.decodeIfPresent(Bool.self, forKey: .showHiddenItemsInSecondaryBar) ?? false
    }

    static let `default` = MenuBarLayout(items: [])

    func section(for key: String) -> MenuBarSection {
        items.first(where: { $0.bundleIdentifier == key })?.section ?? .pinned
    }

    func resolvedSectionForLiveSync(
        itemKey: String,
        actualSection: MenuBarSection,
        resolvesVisibleConflicts: Bool
    ) -> MenuBarSection {
        let storedSection = section(for: itemKey)
        guard resolvesVisibleConflicts else { return storedSection }

        // A direct Command-drag in the real menu bar is an ordering action, not
        // a request to move sections. If a stored Hidden item is physically in
        // the visible bar, however, favor the user's visible reality so the UI
        // never claims a plainly visible item is hidden.
        if storedSection != .pinned, actualSection == .pinned {
            return .pinned
        }
        return storedSection
    }

    mutating func rememberMenuBarItem(itemKey: String, title: String, section: MenuBarSection) {
        guard !items.contains(where: { $0.bundleIdentifier == itemKey }) else { return }
        let model = MenuBarItemModel(
            id: UUID(),
            title: title,
            bundleIdentifier: itemKey,
            section: section,
            controllabilityNote: "Live window-server item"
        )
        let insertionIndex = items.lastIndex { $0.section == section }
            .map { items.index(after: $0) } ?? items.endIndex
        items.insert(model, at: insertionIndex)
    }

    mutating func syncLiveMenuBarItems(_ liveItems: [MenuBarLiveOrderItem]) {
        let liveKeys = Set(liveItems.map(\.key))
        items.removeAll { item in
            item.section == .pinned && !liveKeys.contains(item.bundleIdentifier)
        }

        for liveItem in liveItems {
            if let existingIndex = items.firstIndex(where: { $0.bundleIdentifier == liveItem.key }) {
                items[existingIndex].title = liveItem.title
                items[existingIndex].section = liveItem.section
            } else {
                items.append(MenuBarItemModel(
                    id: UUID(),
                    title: liveItem.title,
                    bundleIdentifier: liveItem.key,
                    section: liveItem.section,
                    controllabilityNote: "Live window-server item"
                ))
            }
        }

        var modelByKey = [String: MenuBarItemModel]()
        for item in items {
            modelByKey[item.bundleIdentifier] = item
        }
        var orderedItems = [MenuBarItemModel]()
        for section in MenuBarSection.allCases {
            let liveSectionKeys = liveItems
                .filter { $0.section == section }
                .map(\.key)
            orderedItems.append(contentsOf: liveSectionKeys.compactMap { modelByKey[$0] })
            orderedItems.append(contentsOf: items.filter { item in
                item.section == section && !liveKeys.contains(item.bundleIdentifier)
            })
        }
        items = orderedItems
    }

    mutating func setMenuBarItemSection(itemKey: String, title: String, section: MenuBarSection, before beforeKey: String? = nil) {
        if beforeKey == nil,
           let existingIndex = items.firstIndex(where: { $0.bundleIdentifier == itemKey }) {
            items[existingIndex].title = title
            items[existingIndex].section = section
            return
        }

        let existing = items.first { $0.bundleIdentifier == itemKey }
        var model = existing ?? MenuBarItemModel(
            id: UUID(),
            title: title,
            bundleIdentifier: itemKey,
            section: section,
            controllabilityNote: "Live window-server item"
        )
        model.title = title
        model.section = section

        items.removeAll { $0.bundleIdentifier == itemKey }
        if let beforeKey,
           let insertionIndex = items.firstIndex(where: { $0.bundleIdentifier == beforeKey }) {
            items.insert(model, at: insertionIndex)
        } else {
            let insertionIndex = items.lastIndex { $0.section == section }
                .map { items.index(after: $0) } ?? items.endIndex
            items.insert(model, at: insertionIndex)
        }
    }

    func orderedItemKeys(in section: MenuBarSection) -> [String] {
        items.filter { $0.section == section }.map(\.bundleIdentifier)
    }
}
