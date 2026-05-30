import CoreGraphics
import Foundation

public typealias MenuBarEngineItemID = String

@MainActor
public protocol MenuBarEngineProtocol: ObservableObject {
    var snapshot: MenuBarEngineSnapshot { get }
    var status: MenuBarEngineStatus { get }

    func start(configuration: MenuBarEngineConfiguration)
    func stop()
    func refresh() async

    func setSection(itemID: MenuBarEngineItemID, section: MenuBarEngineSection) async throws
    func move(itemID: MenuBarEngineItemID, to destination: MenuBarEngineMoveDestination) async throws
    func revealHidden(trigger: MenuBarRevealTrigger) async
    func revealAlwaysHidden() async
    func hideRevealed() async
    func applySpacing(_ value: Int) async throws
}

public struct MenuBarEngineSnapshot: Equatable, Sendable {
    public var visible: [MenuBarEngineItem]
    public var hidden: [MenuBarEngineItem]
    public var alwaysHidden: [MenuBarEngineItem]
    public var readOnly: [MenuBarEngineItem]

    public init(
        visible: [MenuBarEngineItem] = [],
        hidden: [MenuBarEngineItem] = [],
        alwaysHidden: [MenuBarEngineItem] = [],
        readOnly: [MenuBarEngineItem] = []
    ) {
        self.visible = visible
        self.hidden = hidden
        self.alwaysHidden = alwaysHidden
        self.readOnly = readOnly
    }

    public var allManagedItems: [MenuBarEngineItem] {
        visible + hidden + alwaysHidden
    }
}

public struct MenuBarEngineItem: Identifiable, Equatable, Sendable {
    public var id: MenuBarEngineItemID
    public var displayName: String
    public var sourceBundleIdentifier: String?
    public var sourceProcessIdentifier: pid_t?
    public var windowID: CGWindowID
    public var frame: CGRect
    public var section: MenuBarEngineSection
    public var canHide: Bool
    public var canMove: Bool
    public var imageData: Data?

    public init(
        id: MenuBarEngineItemID,
        displayName: String,
        sourceBundleIdentifier: String?,
        sourceProcessIdentifier: pid_t?,
        windowID: CGWindowID,
        frame: CGRect,
        section: MenuBarEngineSection,
        canHide: Bool,
        canMove: Bool,
        imageData: Data? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.sourceBundleIdentifier = sourceBundleIdentifier
        self.sourceProcessIdentifier = sourceProcessIdentifier
        self.windowID = windowID
        self.frame = frame
        self.section = section
        self.canHide = canHide
        self.canMove = canMove
        self.imageData = imageData
    }
}

public struct MenuBarEngineConfiguration: Equatable, Sendable {
    public var revealOnHover: Bool
    public var revealOnEmptyMenuBarClick: Bool
    public var revealOnScroll: Bool
    public var autoRehideEnabled: Bool
    public var autoRehideDelay: Double
    public var hideApplicationMenusOnOverlap: Bool
    public var useSecondaryBar: Bool
    public var itemSpacing: Int
    public var showSectionDividers: Bool

    public init(
        revealOnHover: Bool = true,
        revealOnEmptyMenuBarClick: Bool = true,
        revealOnScroll: Bool = true,
        autoRehideEnabled: Bool = true,
        autoRehideDelay: Double = 1.0,
        hideApplicationMenusOnOverlap: Bool = true,
        useSecondaryBar: Bool = false,
        itemSpacing: Int = 0,
        showSectionDividers: Bool = false
    ) {
        self.revealOnHover = revealOnHover
        self.revealOnEmptyMenuBarClick = revealOnEmptyMenuBarClick
        self.revealOnScroll = revealOnScroll
        self.autoRehideEnabled = autoRehideEnabled
        self.autoRehideDelay = autoRehideDelay
        self.hideApplicationMenusOnOverlap = hideApplicationMenusOnOverlap
        self.useSecondaryBar = useSecondaryBar
        self.itemSpacing = itemSpacing
        self.showSectionDividers = showSectionDividers
    }
}

public struct MenuBarEngineStatus: Equatable, Sendable {
    public var isRunning: Bool
    public var isRevealed: Bool
    public var description: String
    public var lastError: String?

    public init(isRunning: Bool = false, isRevealed: Bool = false, description: String = "Stopped", lastError: String? = nil) {
        self.isRunning = isRunning
        self.isRevealed = isRevealed
        self.description = description
        self.lastError = lastError
    }
}

public enum MenuBarEngineSection: String, Codable, CaseIterable, Identifiable, Sendable {
    case visible
    case hidden
    case alwaysHidden

    public var id: String { rawValue }
}

public enum MenuBarRevealTrigger: String, Codable, Sendable {
    case manual
    case hover
    case emptyMenuBarClick
    case scroll
}

public enum MenuBarEngineMoveDestination: Equatable, Sendable {
    case section(MenuBarEngineSection)
    case beforeItem(MenuBarEngineItemID, in: MenuBarEngineSection)
    case afterItem(MenuBarEngineItemID, in: MenuBarEngineSection)
}
