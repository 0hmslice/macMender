import Foundation
import Testing
@testable import macMender

struct MenuBarSpacingTests {
    @Test(arguments: ["26A5388g", "26A428", "release"])
    func macOS27DoesNotClaimSystemWideSupportOrRestartTheHost(build: String) {
        let strategy = MenuBarSpacingCompatibility.strategy(for: .init(majorVersion: 27, minorVersion: 0, patchVersion: 0, buildVersion: build))
        #expect(strategy.systemItemSupport == .unverifiedSystemItems)
        #expect(strategy.refreshStrategy == .none)
        let result = MenuBarSpacingCompatibility.applicationResult(for: .init(preference: .compact, operation: .write(8)), strategy: strategy, refreshResult: .notNeeded)
        #expect(result.kind == .unverifiedSystemItems)
        #expect(result.message.contains("unverified"))
    }

    @Test(arguments: [0, 1, 4, 8, 16, 24, 32])
    func paddingPreservesHitTargetsAndReadbackMatches(value: Int) {
        let plan = MenuBarSpacingCompatibility.defaultsPlan(for: .custom, customValue: value)
        let padding = min(16, max(6, value))
        #expect(plan.operation(for: "NSStatusItemSelectionPadding") == .write(padding))
        #expect(MenuBarSpacingDefaultsValues(spacing: value, selectionPadding: padding).matches(plan))
    }

    @Test func futureSystemsRemainUnconfirmed() {
        let strategy = MenuBarSpacingCompatibility.strategy(for: .init(majorVersion: 28, minorVersion: 0, patchVersion: 0, buildVersion: "future"))
        #expect(strategy.systemItemSupport == .unconfirmed)
        #expect(strategy.refreshStrategy == .none)
    }

    @Test func resetRemovesBothKeysAndUsesNativeIconWidth() {
        #expect(MenuBarSpacingCompatibility.defaultsPlan(for: .systemDefault).operation == .delete)
        let strategy = MenuBarSpacingCompatibility.strategy(for: .init(majorVersion: 27, minorVersion: 0, patchVersion: 0, buildVersion: "release"))
        #expect(MacMenderStatusItemController.effectiveSpacingValue(for: .init(spacing: nil, selectionPadding: nil), strategy: strategy) == nil)
    }

    @Test func partialWriteFailureRollsBackBothKeys() async {
        let storage = SpacingStorage()
        let result = await MenuBarSpacingCompatibility.execute(
            plan: .init(preference: .compact, operation: .write(8)),
            dependencies: MenuBarSpacingDependencies(
                readValues: { _ in await storage.values },
                applyOperation: { operation, key, _ in try await storage.apply(operation, key: key) },
                refresh: { _ in .notNeeded },
                systemContext: { .init(majorVersion: 27, minorVersion: 0, patchVersion: 0, buildVersion: "release") }
            )
        )
        #expect(!result.preferenceVerified)
        #expect(result.rollbackSucceeded)
        #expect(result.currentValues == .init(spacing: 16, selectionPadding: 24))
        #expect(result.applicationResult.kind == .failed)
    }
}

private actor SpacingStorage {
    var values = MenuBarSpacingDefaultsValues(spacing: 16, selectionPadding: 24)
    var failed = false
    func apply(_ operation: MenuBarSpacingDefaultsPlan.Operation, key: String) throws {
        if key == "NSStatusItemSelectionPadding", !failed {
            failed = true
            throw CocoaError(.fileWriteUnknown)
        }
        let value: Int?
        switch operation {
        case .delete: value = nil
        case .write(let number): value = number
        }
        if key == "NSStatusItemSpacing" { values.spacing = value } else { values.selectionPadding = value }
    }
}
