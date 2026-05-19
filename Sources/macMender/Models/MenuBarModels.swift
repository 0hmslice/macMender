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
        case .hidden: "Always-hidden"
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
            "Hidden until Mendy, empty menu-bar space, or a menu-bar swipe reveals it."
        case .hidden:
            "Kept behind the always-hidden divider until you move it back."
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

struct MenuBarLayout: Codable, Equatable {
    var items: [MenuBarItemModel]
    var itemSpacingOffset: Int
    var showSectionDividers: Bool
    var autoRehideEnabled: Bool
    var autoRehideDelay: Double

    enum CodingKeys: String, CodingKey {
        case items
        case itemSpacingOffset
        case showSectionDividers
        case autoRehideEnabled
        case autoRehideDelay
    }

    init(
        items: [MenuBarItemModel],
        itemSpacingOffset: Int = 0,
        showSectionDividers: Bool = false,
        autoRehideEnabled: Bool = true,
        autoRehideDelay: Double = 1.0
    ) {
        self.items = items
        self.itemSpacingOffset = itemSpacingOffset
        self.showSectionDividers = showSectionDividers
        self.autoRehideEnabled = autoRehideEnabled
        self.autoRehideDelay = autoRehideDelay
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        items = try container.decodeIfPresent([MenuBarItemModel].self, forKey: .items) ?? []
        itemSpacingOffset = try container.decodeIfPresent(Int.self, forKey: .itemSpacingOffset) ?? 0
        showSectionDividers = try container.decodeIfPresent(Bool.self, forKey: .showSectionDividers) ?? false
        autoRehideEnabled = try container.decodeIfPresent(Bool.self, forKey: .autoRehideEnabled) ?? true
        autoRehideDelay = try container.decodeIfPresent(Double.self, forKey: .autoRehideDelay) ?? 1.0
    }

    static let `default` = MenuBarLayout(items: [])

    func section(for key: String) -> MenuBarSection {
        items.first(where: { $0.bundleIdentifier == key })?.section ?? .pinned
    }
}
