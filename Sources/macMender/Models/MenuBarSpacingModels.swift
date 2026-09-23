import Foundation

struct MenuBarSpacingDefaultsPlan: Equatable, Sendable {
    enum Operation: Equatable, Sendable {
        case write(Int)
        case delete
    }

    static let keys = [
        "NSStatusItemSpacing",
        "NSStatusItemSelectionPadding"
    ]

    var preference: MenuBarSpacingPreference
    var operation: Operation

    func operation(for key: String) -> Operation {
        if key == Self.keys[1], case .write(let value) = operation {
            // Keep small icons clickable while allowing a tighter inter-item gap.
            return .write(min(16, max(6, value)))
        }
        return operation
    }
}

struct MenuBarSpacingDefaultsValues: Equatable, Sendable {
    var spacing: Int?
    var selectionPadding: Int?

    var sharedValue: Int? {
        guard let spacing,
              let selectionPadding,
              spacing == selectionPadding else {
            return nil
        }
        return spacing
    }

    var description: String {
        switch (spacing, selectionPadding) {
        case (nil, nil):
            "Current preference value: Default"
        case let (spacing?, selectionPadding?) where spacing == selectionPadding:
            "Current preference value: \(spacing)"
        case let (spacing, selectionPadding):
            "Current preference values: spacing \(spacing.map(String.init) ?? "default"), selection padding \(selectionPadding.map(String.init) ?? "default")"
        }
    }

    func matches(_ plan: MenuBarSpacingDefaultsPlan) -> Bool {
        switch plan.operation {
        case .delete:
            spacing == nil && selectionPadding == nil
        case .write(let value):
            spacing == value && plan.operation(for: MenuBarSpacingDefaultsPlan.keys[1]) == selectionPadding.map { .write($0) }
        }
    }
}

enum MenuBarSpacingPreferenceScope: Equatable, Sendable {
    case currentHostGlobal
}

struct MenuBarSpacingSystemContext: Equatable, Sendable {
    var majorVersion: Int
    var minorVersion: Int
    var patchVersion: Int
    var buildVersion: String
}

enum MenuBarSpacingRefreshStrategy: Equatable, Sendable {
    case controlCenter
    case none
}

enum MenuBarSpacingSystemItemSupport: Equatable, Sendable {
    case legacy
    case unverifiedSystemItems
    case unconfirmed
}

struct MenuBarSpacingCompatibilityStrategy: Equatable, Sendable {
    var preferenceScope: MenuBarSpacingPreferenceScope
    var refreshStrategy: MenuBarSpacingRefreshStrategy
    var systemItemSupport: MenuBarSpacingSystemItemSupport
}

enum MenuBarSpacingRefreshResult: Equatable, Sendable {
    case notNeeded
    case refreshed
    case hostUnavailable
    case failed
}

enum MenuBarSpacingResultKind: Equatable, Sendable {
    case applied
    case appliedSomeAppsMayNeedRelaunch
    case unverifiedSystemItems
    case couldNotConfirmSystemItemUpdate
    case failed

    var title: String {
        switch self {
        case .applied:
            "Applied"
        case .appliedSomeAppsMayNeedRelaunch:
            "Applied, some apps may need relaunch"
        case .unverifiedSystemItems:
            "Apple icon spacing unverified"
        case .couldNotConfirmSystemItemUpdate:
            "Could not confirm system item update"
        case .failed:
            "Spacing update failed"
        }
    }
}

struct MenuBarSpacingApplicationResult: Equatable, Sendable {
    var kind: MenuBarSpacingResultKind
    var detail: String

    var message: String {
        detail.isEmpty ? kind.title : "\(kind.title). \(detail)"
    }
}

struct MenuBarSpacingPreferenceUpdateResult: Equatable, Sendable {
    var currentValues: MenuBarSpacingDefaultsValues?
    var preferenceVerified: Bool
    var rollbackSucceeded: Bool
    var failureResult: MenuBarSpacingApplicationResult?
}

struct MenuBarSpacingExecutionResult: Equatable, Sendable {
    var applicationResult: MenuBarSpacingApplicationResult
    var currentValues: MenuBarSpacingDefaultsValues?
    var preferenceVerified: Bool
    var rollbackSucceeded: Bool
}

struct MenuBarSpacingDependencies: Sendable {
    var readValues: @Sendable (MenuBarSpacingPreferenceScope) async throws -> MenuBarSpacingDefaultsValues
    var applyOperation: @Sendable (
        MenuBarSpacingDefaultsPlan.Operation,
        String,
        MenuBarSpacingPreferenceScope
    ) async throws -> Void
    var refresh: @Sendable (MenuBarSpacingRefreshStrategy) async -> MenuBarSpacingRefreshResult
    var systemContext: @Sendable () -> MenuBarSpacingSystemContext
}
