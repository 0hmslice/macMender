import Foundation
import Testing
@testable import macMender

@Suite("Menu Bar Spacing Service")
struct MenuBarSpacingServiceTests {
    private let beta4Context = MenuBarSpacingSystemContext(
        majorVersion: 27,
        minorVersion: 0,
        patchVersion: 0,
        buildVersion: "26A5388g"
    )

    @Test("macOS 26 keeps the legacy current-host and Control Center strategy")
    func macOS26Strategy() {
        let strategy = MenuBarSpacingCompatibility.strategy(
            for: MenuBarSpacingSystemContext(
                majorVersion: 26,
                minorVersion: 6,
                patchVersion: 0,
                buildVersion: "25G100"
            )
        )

        #expect(strategy.preferenceScope == .currentHostGlobal)
        #expect(strategy.refreshStrategy == .controlCenter)
        #expect(strategy.systemItemSupport == .legacy)
    }

    @Test("exact macOS 27 Beta 4 build selects the measured unsupported strategy")
    func beta4Strategy() {
        let strategy = MenuBarSpacingCompatibility.strategy(for: beta4Context)

        #expect(strategy.preferenceScope == .currentHostGlobal)
        #expect(strategy.refreshStrategy == .none)
        #expect(strategy.systemItemSupport == .unsupportedOnThisBeta)
    }

    @Test("future macOS 27 builds remain unconfirmed")
    func futureMacOS27Strategy() {
        let strategy = MenuBarSpacingCompatibility.strategy(
            for: MenuBarSpacingSystemContext(
                majorVersion: 27,
                minorVersion: 0,
                patchVersion: 0,
                buildVersion: "26A6000"
            )
        )

        #expect(strategy.preferenceScope == .currentHostGlobal)
        #expect(strategy.refreshStrategy == .none)
        #expect(strategy.systemItemSupport == .unconfirmed)
    }

    @Test("defaults arguments target only the current-host global domain")
    func currentHostArguments() {
        #expect(
            MenuBarSpacingCompatibility.arguments(
                for: .write(24),
                key: "NSStatusItemSpacing"
            ) == [
                "-currentHost",
                "write",
                "-globalDomain",
                "NSStatusItemSpacing",
                "-int",
                "24"
            ]
        )
        #expect(
            MenuBarSpacingCompatibility.arguments(
                for: .delete,
                key: "NSStatusItemSelectionPadding"
            ) == [
                "-currentHost",
                "delete",
                "-globalDomain",
                "NSStatusItemSelectionPadding"
            ]
        )
    }

    @Test("structured results map every required status")
    func resultMapping() {
        let plan = MenuBarSpacingCompatibility.defaultsPlan(for: .wide)
        let legacy = MenuBarSpacingCompatibility.strategy(
            for: MenuBarSpacingSystemContext(
                majorVersion: 26,
                minorVersion: 0,
                patchVersion: 0,
                buildVersion: "25A1"
            )
        )
        let beta4 = MenuBarSpacingCompatibility.strategy(for: beta4Context)
        let future = MenuBarSpacingCompatibility.strategy(
            for: MenuBarSpacingSystemContext(
                majorVersion: 27,
                minorVersion: 0,
                patchVersion: 0,
                buildVersion: "26A6000"
            )
        )

        #expect(
            MenuBarSpacingCompatibility.applicationResult(
                for: plan,
                strategy: legacy,
                refreshResult: .refreshed,
                allItemsConfirmed: true
            ).kind == .applied
        )
        #expect(
            MenuBarSpacingCompatibility.applicationResult(
                for: plan,
                strategy: legacy,
                refreshResult: .refreshed
            ).kind == .appliedSomeAppsMayNeedRelaunch
        )
        #expect(
            MenuBarSpacingCompatibility.applicationResult(
                for: plan,
                strategy: beta4,
                refreshResult: .notNeeded
            ).kind == .unsupportedOnThisBeta
        )
        #expect(
            MenuBarSpacingCompatibility.applicationResult(
                for: plan,
                strategy: future,
                refreshResult: .notNeeded
            ).kind == .couldNotConfirmSystemItemUpdate
        )
        #expect(
            MenuBarSpacingCompatibility.applicationResult(
                for: plan,
                strategy: legacy,
                refreshResult: .failed
            ).kind == .couldNotConfirmSystemItemUpdate
        )
    }

    @Test("verified Beta 4 write keeps third-party preference and skips host restart")
    func beta4WriteExecution() async {
        let harness = SpacingHarness(
            values: MenuBarSpacingDefaultsValues(spacing: nil, selectionPadding: nil),
            refreshResult: .notNeeded
        )
        let execution = await MenuBarSpacingCompatibility.execute(
            plan: MenuBarSpacingCompatibility.defaultsPlan(for: .wide),
            dependencies: makeDependencies(harness: harness, context: beta4Context)
        )
        let snapshot = await harness.snapshot()

        #expect(execution.preferenceVerified)
        #expect(execution.currentValues == MenuBarSpacingDefaultsValues(spacing: 24, selectionPadding: 24))
        #expect(execution.applicationResult.kind == .unsupportedOnThisBeta)
        #expect(snapshot.operations == [
            SpacingOperation(key: "NSStatusItemSpacing", operation: .write(24), scope: .currentHostGlobal),
            SpacingOperation(key: "NSStatusItemSelectionPadding", operation: .write(24), scope: .currentHostGlobal)
        ])
        #expect(snapshot.readScopes == [.currentHostGlobal, .currentHostGlobal])
        #expect(snapshot.refreshStrategies == [.none])
    }

    @Test("legacy verified write refreshes Control Center once")
    func legacyWriteExecution() async {
        let context = MenuBarSpacingSystemContext(
            majorVersion: 26,
            minorVersion: 6,
            patchVersion: 0,
            buildVersion: "25G100"
        )
        let harness = SpacingHarness(
            values: MenuBarSpacingDefaultsValues(spacing: 16, selectionPadding: 16),
            refreshResult: .refreshed
        )
        let execution = await MenuBarSpacingCompatibility.execute(
            plan: MenuBarSpacingCompatibility.defaultsPlan(for: .compact),
            dependencies: makeDependencies(harness: harness, context: context)
        )
        let snapshot = await harness.snapshot()

        #expect(execution.preferenceVerified)
        #expect(execution.applicationResult.kind == .appliedSomeAppsMayNeedRelaunch)
        #expect(snapshot.values == MenuBarSpacingDefaultsValues(spacing: 8, selectionPadding: 8))
        #expect(snapshot.operations.allSatisfy { $0.scope == .currentHostGlobal })
        #expect(snapshot.readScopes == [.currentHostGlobal, .currentHostGlobal])
        #expect(snapshot.refreshStrategies == [.controlCenter])
    }

    @Test("System Default deletes both keys and verifies absence")
    func systemDefaultExecution() async {
        let harness = SpacingHarness(
            values: MenuBarSpacingDefaultsValues(spacing: 4, selectionPadding: 4),
            refreshResult: .notNeeded
        )
        let execution = await MenuBarSpacingCompatibility.execute(
            plan: MenuBarSpacingCompatibility.defaultsPlan(for: .systemDefault),
            dependencies: makeDependencies(harness: harness, context: beta4Context)
        )
        let snapshot = await harness.snapshot()

        #expect(execution.preferenceVerified)
        #expect(execution.applicationResult.kind == .appliedSomeAppsMayNeedRelaunch)
        #expect(snapshot.values == MenuBarSpacingDefaultsValues(spacing: nil, selectionPadding: nil))
        #expect(snapshot.operations == [
            SpacingOperation(key: "NSStatusItemSpacing", operation: .delete, scope: .currentHostGlobal),
            SpacingOperation(key: "NSStatusItemSelectionPadding", operation: .delete, scope: .currentHostGlobal)
        ])
        #expect(snapshot.readScopes == [.currentHostGlobal, .currentHostGlobal])
        #expect(snapshot.refreshStrategies == [.none])
    }

    @Test("staged preference update verifies values before any host refresh")
    func stagedPreferenceUpdateDoesNotRefresh() async {
        let harness = SpacingHarness(
            values: MenuBarSpacingDefaultsValues(spacing: 4, selectionPadding: 4),
            refreshResult: .refreshed
        )
        let strategy = MenuBarSpacingCompatibility.strategy(for: beta4Context)

        let update = await MenuBarSpacingCompatibility.updatePreferences(
            plan: MenuBarSpacingCompatibility.defaultsPlan(for: .wide),
            strategy: strategy,
            dependencies: makeDependencies(harness: harness, context: beta4Context)
        )
        let snapshot = await harness.snapshot()

        #expect(update.preferenceVerified)
        #expect(update.currentValues == MenuBarSpacingDefaultsValues(spacing: 24, selectionPadding: 24))
        #expect(update.failureResult == nil)
        #expect(snapshot.operations.allSatisfy { $0.scope == .currentHostGlobal })
        #expect(snapshot.readScopes == [.currentHostGlobal, .currentHostGlobal])
        #expect(snapshot.refreshStrategies.isEmpty)
    }

    @Test("failed staged preference update never refreshes the host")
    func failedStagedPreferenceUpdateDoesNotRefresh() async {
        let harness = SpacingHarness(
            values: MenuBarSpacingDefaultsValues(spacing: 4, selectionPadding: 4),
            refreshResult: .refreshed,
            failingKey: "NSStatusItemSelectionPadding",
            remainingOperationFailures: 1
        )
        let strategy = MenuBarSpacingCompatibility.strategy(for: beta4Context)

        let update = await MenuBarSpacingCompatibility.updatePreferences(
            plan: MenuBarSpacingCompatibility.defaultsPlan(for: .wide),
            strategy: strategy,
            dependencies: makeDependencies(harness: harness, context: beta4Context)
        )
        let snapshot = await harness.snapshot()

        #expect(!update.preferenceVerified)
        #expect(update.failureResult?.kind == .failed)
        #expect(snapshot.operations.allSatisfy { $0.scope == .currentHostGlobal })
        #expect(snapshot.readScopes.allSatisfy { $0 == .currentHostGlobal })
        #expect(snapshot.refreshStrategies.isEmpty)
    }

    @Test("partial write failure restores both original values")
    func partialWriteFailureRollsBack() async {
        let harness = SpacingHarness(
            values: MenuBarSpacingDefaultsValues(spacing: 7, selectionPadding: 7),
            refreshResult: .notNeeded,
            failingKey: "NSStatusItemSelectionPadding",
            remainingOperationFailures: 1
        )
        let execution = await MenuBarSpacingCompatibility.execute(
            plan: MenuBarSpacingCompatibility.defaultsPlan(for: .wide),
            dependencies: makeDependencies(harness: harness, context: beta4Context)
        )
        let snapshot = await harness.snapshot()

        #expect(!execution.preferenceVerified)
        #expect(execution.rollbackSucceeded)
        #expect(execution.applicationResult.kind == .failed)
        #expect(snapshot.values == MenuBarSpacingDefaultsValues(spacing: 7, selectionPadding: 7))
        #expect(snapshot.operations == [
            SpacingOperation(key: "NSStatusItemSpacing", operation: .write(24), scope: .currentHostGlobal),
            SpacingOperation(key: "NSStatusItemSelectionPadding", operation: .write(24), scope: .currentHostGlobal),
            SpacingOperation(key: "NSStatusItemSpacing", operation: .write(7), scope: .currentHostGlobal),
            SpacingOperation(key: "NSStatusItemSelectionPadding", operation: .write(7), scope: .currentHostGlobal)
        ])
        #expect(snapshot.readScopes == [
            .currentHostGlobal,
            .currentHostGlobal,
            .currentHostGlobal
        ])
        #expect(snapshot.refreshStrategies.isEmpty)
    }

    @Test("rollback restores mixed missing and explicit original values")
    func mixedOriginalValuesRollBack() async {
        let original = MenuBarSpacingDefaultsValues(spacing: nil, selectionPadding: 7)
        let harness = SpacingHarness(
            values: original,
            refreshResult: .notNeeded,
            failingKey: "NSStatusItemSelectionPadding",
            remainingOperationFailures: 1
        )

        let execution = await MenuBarSpacingCompatibility.execute(
            plan: MenuBarSpacingCompatibility.defaultsPlan(for: .wide),
            dependencies: makeDependencies(harness: harness, context: beta4Context)
        )
        let snapshot = await harness.snapshot()

        #expect(!execution.preferenceVerified)
        #expect(execution.rollbackSucceeded)
        #expect(execution.currentValues == original)
        #expect(snapshot.values == original)
        #expect(snapshot.operations == [
            SpacingOperation(key: "NSStatusItemSpacing", operation: .write(24), scope: .currentHostGlobal),
            SpacingOperation(key: "NSStatusItemSelectionPadding", operation: .write(24), scope: .currentHostGlobal),
            SpacingOperation(key: "NSStatusItemSpacing", operation: .delete, scope: .currentHostGlobal),
            SpacingOperation(key: "NSStatusItemSelectionPadding", operation: .write(7), scope: .currentHostGlobal)
        ])
        #expect(snapshot.readScopes == [
            .currentHostGlobal,
            .currentHostGlobal,
            .currentHostGlobal
        ])
        #expect(snapshot.refreshStrategies.isEmpty)
    }

    @Test("rollback operation errors still count as restored when final values match")
    func rollbackOperationErrorWithRestoredState() async {
        let original = MenuBarSpacingDefaultsValues(spacing: 7, selectionPadding: 7)
        let harness = SpacingHarness(
            values: original,
            refreshResult: .notNeeded,
            failingKey: "NSStatusItemSelectionPadding",
            remainingOperationFailures: 2
        )

        let execution = await MenuBarSpacingCompatibility.execute(
            plan: MenuBarSpacingCompatibility.defaultsPlan(for: .wide),
            dependencies: makeDependencies(harness: harness, context: beta4Context)
        )
        let snapshot = await harness.snapshot()

        #expect(!execution.preferenceVerified)
        #expect(execution.rollbackSucceeded)
        #expect(execution.currentValues == original)
        #expect(execution.applicationResult.kind == .failed)
        #expect(execution.applicationResult.detail.contains("original preference values were restored"))
        #expect(snapshot.values == original)
        #expect(snapshot.refreshStrategies.isEmpty)
    }

    @Test("latest rollback read confirms restoration after a transient read failure")
    func latestRollbackReadConfirmsRestoration() async {
        let original = MenuBarSpacingDefaultsValues(spacing: 7, selectionPadding: 7)
        let harness = SpacingHarness(
            values: original,
            refreshResult: .notNeeded,
            failingKey: "NSStatusItemSelectionPadding",
            remainingOperationFailures: 1,
            failingReadCalls: [2]
        )

        let execution = await MenuBarSpacingCompatibility.execute(
            plan: MenuBarSpacingCompatibility.defaultsPlan(for: .wide),
            dependencies: makeDependencies(harness: harness, context: beta4Context)
        )
        let snapshot = await harness.snapshot()

        #expect(!execution.preferenceVerified)
        #expect(execution.rollbackSucceeded)
        #expect(execution.currentValues == original)
        #expect(execution.applicationResult.kind == .failed)
        #expect(execution.applicationResult.detail.contains("original preference values were restored"))
        #expect(snapshot.values == original)
        #expect(snapshot.readScopes == [
            .currentHostGlobal,
            .currentHostGlobal,
            .currentHostGlobal
        ])
        #expect(snapshot.refreshStrategies.isEmpty)
    }

    @Test("latest rollback read rejects restoration when values changed again")
    func latestRollbackReadRejectsChangedValues() async {
        let original = MenuBarSpacingDefaultsValues(spacing: 7, selectionPadding: 7)
        let changed = MenuBarSpacingDefaultsValues(spacing: 12, selectionPadding: 12)
        let harness = SpacingHarness(
            values: original,
            refreshResult: .notNeeded,
            failingKey: "NSStatusItemSelectionPadding",
            remainingOperationFailures: 1,
            readOverrides: [3: changed]
        )

        let execution = await MenuBarSpacingCompatibility.execute(
            plan: MenuBarSpacingCompatibility.defaultsPlan(for: .wide),
            dependencies: makeDependencies(harness: harness, context: beta4Context)
        )
        let snapshot = await harness.snapshot()

        #expect(!execution.preferenceVerified)
        #expect(!execution.rollbackSucceeded)
        #expect(execution.currentValues == changed)
        #expect(execution.applicationResult.kind == .failed)
        #expect(execution.applicationResult.detail.contains("could not be fully restored"))
        #expect(snapshot.readScopes == [
            .currentHostGlobal,
            .currentHostGlobal,
            .currentHostGlobal
        ])
        #expect(snapshot.refreshStrategies.isEmpty)
    }

    @Test("failed rollback and failed final read leave current values unknown")
    func failedRollbackAndReadYieldNilValues() async {
        let harness = SpacingHarness(
            values: MenuBarSpacingDefaultsValues(spacing: nil, selectionPadding: 7),
            refreshResult: .notNeeded,
            failingKey: "NSStatusItemSelectionPadding",
            remainingOperationFailures: 2,
            failingReadCalls: [2, 3]
        )

        let execution = await MenuBarSpacingCompatibility.execute(
            plan: MenuBarSpacingCompatibility.defaultsPlan(for: .wide),
            dependencies: makeDependencies(harness: harness, context: beta4Context)
        )
        let snapshot = await harness.snapshot()

        #expect(!execution.preferenceVerified)
        #expect(!execution.rollbackSucceeded)
        #expect(execution.currentValues == nil)
        #expect(execution.applicationResult.kind == .failed)
        #expect(snapshot.operations.allSatisfy { $0.scope == .currentHostGlobal })
        #expect(snapshot.readScopes == [
            .currentHostGlobal,
            .currentHostGlobal,
            .currentHostGlobal
        ])
        #expect(snapshot.refreshStrategies.isEmpty)
    }

    @Test("verification mismatch fails instead of claiming Apply succeeded")
    func verificationMismatchFails() async {
        let original = MenuBarSpacingDefaultsValues(spacing: 11, selectionPadding: 11)
        let harness = SpacingHarness(
            values: original,
            refreshResult: .notNeeded,
            ignoresOperations: true
        )
        let execution = await MenuBarSpacingCompatibility.execute(
            plan: MenuBarSpacingCompatibility.defaultsPlan(for: .compact),
            dependencies: makeDependencies(harness: harness, context: beta4Context)
        )
        let snapshot = await harness.snapshot()

        #expect(!execution.preferenceVerified)
        #expect(execution.rollbackSucceeded)
        #expect(execution.applicationResult.kind == .failed)
        #expect(snapshot.values == original)
        #expect(snapshot.operations.allSatisfy { $0.scope == .currentHostGlobal })
        #expect(snapshot.readScopes.allSatisfy { $0 == .currentHostGlobal })
        #expect(snapshot.refreshStrategies.isEmpty)
    }

    @Test("initial preference read failure does not mutate or claim success")
    func initialReadFailure() async {
        let harness = SpacingHarness(
            values: MenuBarSpacingDefaultsValues(spacing: nil, selectionPadding: nil),
            refreshResult: .notNeeded,
            failingReadCalls: [1]
        )
        let execution = await MenuBarSpacingCompatibility.execute(
            plan: MenuBarSpacingCompatibility.defaultsPlan(for: .compact),
            dependencies: makeDependencies(harness: harness, context: beta4Context)
        )
        let snapshot = await harness.snapshot()

        #expect(!execution.preferenceVerified)
        #expect(execution.currentValues == nil)
        #expect(execution.applicationResult.kind == .failed)
        #expect(execution.applicationResult.detail.contains("No changes were made"))
        #expect(snapshot.operations.isEmpty)
        #expect(snapshot.readScopes == [.currentHostGlobal])
        #expect(snapshot.refreshStrategies.isEmpty)
    }

    @Test("production Apply publishes verified values before delayed refresh completes")
    @MainActor
    func productionApplyOrdersVerifiedStateBeforeRefreshCompletion() async {
        let context = MenuBarSpacingSystemContext(
            majorVersion: 26,
            minorVersion: 6,
            patchVersion: 0,
            buildVersion: "25G100"
        )
        let initial = MenuBarSpacingDefaultsValues(spacing: 16, selectionPadding: 16)
        let harness = SpacingHarness(
            values: initial,
            refreshResult: .refreshed,
            delaysRefresh: true
        )
        let service = MenuBarSpacingService(
            dependencies: makeDependencies(harness: harness, context: context),
            initialValues: initial
        )
        var callbackCalled = false
        var valuesAtCallback: MenuBarSpacingDefaultsValues?

        service.apply(.compact, customValue: 8) {
            callbackCalled = true
            valuesAtCallback = service.currentValues
        }

        await harness.waitForRefreshStart()
        let snapshotWhileRefreshing = await harness.snapshot()

        #expect(callbackCalled)
        #expect(valuesAtCallback == MenuBarSpacingDefaultsValues(spacing: 8, selectionPadding: 8))
        #expect(service.currentValues == MenuBarSpacingDefaultsValues(spacing: 8, selectionPadding: 8))
        #expect(service.isApplying)
        #expect(service.resultKind == nil)
        #expect(service.statusDescription == "Preference saved. Finishing menu bar update...")
        #expect(snapshotWhileRefreshing.refreshStrategies == [.controlCenter])

        await harness.completeRefresh(with: .refreshed)
        let didFinish = await waitUntil { !service.isApplying }

        #expect(didFinish)
        #expect(service.resultKind == .appliedSomeAppsMayNeedRelaunch)
        #expect(service.currentValues == MenuBarSpacingDefaultsValues(spacing: 8, selectionPadding: 8))
    }

    @Test("failed production Apply never invokes verified callback or refresh")
    @MainActor
    func failedProductionApplyDoesNotCallbackOrRefresh() async {
        let initial = MenuBarSpacingDefaultsValues(spacing: 4, selectionPadding: 4)
        let harness = SpacingHarness(
            values: initial,
            refreshResult: .refreshed,
            failingKey: "NSStatusItemSelectionPadding",
            remainingOperationFailures: 1
        )
        let service = MenuBarSpacingService(
            dependencies: makeDependencies(harness: harness, context: beta4Context),
            initialValues: initial
        )
        var callbackCalled = false

        service.apply(.wide, customValue: 24) {
            callbackCalled = true
        }

        let didFinish = await waitUntil { !service.isApplying }
        let snapshot = await harness.snapshot()

        #expect(didFinish)
        #expect(!callbackCalled)
        #expect(service.currentValues == initial)
        #expect(service.resultKind == .failed)
        #expect(service.statusDescription.contains("original preference values were restored"))
        #expect(snapshot.refreshStrategies.isEmpty)
    }

    @Test("cancelled stale value refresh cannot overwrite a successful Apply")
    @MainActor
    func staleValueRefreshCannotOverwriteApply() async {
        let initial = MenuBarSpacingDefaultsValues(spacing: 4, selectionPadding: 4)
        let stale = MenuBarSpacingDefaultsValues(spacing: 8, selectionPadding: 8)
        let harness = SpacingHarness(
            values: initial,
            refreshResult: .notNeeded,
            staleFirstRead: stale
        )
        let service = MenuBarSpacingService(
            dependencies: makeDependencies(harness: harness, context: beta4Context),
            initialValues: initial
        )

        service.refreshCurrentValues()
        await harness.waitForStaleReadStart()
        service.apply(.wide, customValue: 24)

        let applyDidFinish = await waitUntil { !service.isApplying }
        let valuesAfterApply = service.currentValues
        let resultAfterApply = service.resultKind
        let statusAfterApply = service.statusDescription

        #expect(applyDidFinish)
        #expect(valuesAfterApply == MenuBarSpacingDefaultsValues(spacing: 24, selectionPadding: 24))
        #expect(resultAfterApply == .unsupportedOnThisBeta)

        await harness.completeStaleRead()
        await harness.waitForStaleReadCompletion()
        await Task.yield()
        await Task.yield()

        #expect(service.currentValues == valuesAfterApply)
        #expect(service.resultKind == resultAfterApply)
        #expect(service.statusDescription == statusAfterApply)
        let snapshot = await harness.snapshot()
        #expect(snapshot.refreshStrategies == [.none])
    }

    @Test("macMender status item geometry preserves the complete custom range")
    func statusItemGeometry() {
        #expect(MacMenderStatusItemController.statusItemLength(imageWidth: 22, spacingValue: -4) == 22)
        #expect(MacMenderStatusItemController.statusItemLength(imageWidth: 22, spacingValue: 4) == 26)
        #expect(MacMenderStatusItemController.statusItemLength(imageWidth: 22, spacingValue: 24) == 46)
        #expect(MacMenderStatusItemController.statusItemLength(imageWidth: 22, spacingValue: 32) == 54)
        #expect(MacMenderStatusItemController.statusItemLength(imageWidth: 22, spacingValue: 48) == 54)
    }

    @Test("macMender uses measured default only on the exact Beta 4 build")
    func statusItemSystemDefaultGeometryByStrategy() {
        let absentValues = MenuBarSpacingDefaultsValues(spacing: nil, selectionPadding: nil)
        let beta4 = MenuBarSpacingCompatibility.strategy(for: beta4Context)
        let legacy = MenuBarSpacingCompatibility.strategy(
            for: MenuBarSpacingSystemContext(
                majorVersion: 26,
                minorVersion: 6,
                patchVersion: 0,
                buildVersion: "25G100"
            )
        )
        let future = MenuBarSpacingCompatibility.strategy(
            for: MenuBarSpacingSystemContext(
                majorVersion: 27,
                minorVersion: 0,
                patchVersion: 0,
                buildVersion: "26A6000"
            )
        )

        #expect(
            MacMenderStatusItemController.effectiveSpacingValue(
                for: absentValues,
                strategy: beta4
            ) == 16
        )
        #expect(
            MacMenderStatusItemController.effectiveSpacingValue(
                for: absentValues,
                strategy: legacy
            ) == nil
        )
        #expect(
            MacMenderStatusItemController.effectiveSpacingValue(
                for: absentValues,
                strategy: future
            ) == nil
        )
        #expect(
            MacMenderStatusItemController.effectiveSpacingValue(
                for: MenuBarSpacingDefaultsValues(spacing: 0, selectionPadding: 0),
                strategy: beta4
            ) == 0
        )
        #expect(
            MacMenderStatusItemController.effectiveSpacingValue(
                for: MenuBarSpacingDefaultsValues(spacing: 4, selectionPadding: 8),
                strategy: beta4
            ) == nil
        )
    }
}

private struct SpacingOperation: Equatable, Sendable {
    var key: String
    var operation: MenuBarSpacingDefaultsPlan.Operation
    var scope: MenuBarSpacingPreferenceScope
}

private struct SpacingHarnessSnapshot: Equatable, Sendable {
    var values: MenuBarSpacingDefaultsValues
    var operations: [SpacingOperation]
    var readScopes: [MenuBarSpacingPreferenceScope]
    var refreshStrategies: [MenuBarSpacingRefreshStrategy]
}

private enum SpacingHarnessError: Error {
    case plannedReadFailure
    case plannedOperationFailure
}

private actor SpacingHarness {
    private var values: MenuBarSpacingDefaultsValues
    private var operations: [SpacingOperation] = []
    private var readScopes: [MenuBarSpacingPreferenceScope] = []
    private var refreshStrategies: [MenuBarSpacingRefreshStrategy] = []
    private let refreshResult: MenuBarSpacingRefreshResult
    private let failingKey: String?
    private var remainingOperationFailures: Int
    private let failingReadCalls: Set<Int>
    private let readOverrides: [Int: MenuBarSpacingDefaultsValues]
    private var readCallCount = 0
    private let ignoresOperations: Bool
    private let delaysRefresh: Bool
    private let staleFirstRead: MenuBarSpacingDefaultsValues?
    private var refreshContinuation: CheckedContinuation<MenuBarSpacingRefreshResult, Never>?
    private var refreshStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var staleReadContinuation: CheckedContinuation<MenuBarSpacingDefaultsValues, Never>?
    private var staleReadStartWaiters: [CheckedContinuation<Void, Never>] = []
    private var staleReadCompletionWaiters: [CheckedContinuation<Void, Never>] = []
    private var staleReadStarted = false
    private var staleReadCompleted = false

    init(
        values: MenuBarSpacingDefaultsValues,
        refreshResult: MenuBarSpacingRefreshResult,
        failingKey: String? = nil,
        remainingOperationFailures: Int = 0,
        failingReadCalls: Set<Int> = [],
        readOverrides: [Int: MenuBarSpacingDefaultsValues] = [:],
        ignoresOperations: Bool = false,
        delaysRefresh: Bool = false,
        staleFirstRead: MenuBarSpacingDefaultsValues? = nil
    ) {
        self.values = values
        self.refreshResult = refreshResult
        self.failingKey = failingKey
        self.remainingOperationFailures = remainingOperationFailures
        self.failingReadCalls = failingReadCalls
        self.readOverrides = readOverrides
        self.ignoresOperations = ignoresOperations
        self.delaysRefresh = delaysRefresh
        self.staleFirstRead = staleFirstRead
    }

    func readValues(
        scope: MenuBarSpacingPreferenceScope
    ) async throws -> MenuBarSpacingDefaultsValues {
        readScopes.append(scope)
        readCallCount += 1
        if failingReadCalls.contains(readCallCount) {
            throw SpacingHarnessError.plannedReadFailure
        }
        if let overriddenValues = readOverrides[readCallCount] {
            return overriddenValues
        }
        if readCallCount == 1, staleFirstRead != nil {
            staleReadStarted = true
            let waiters = staleReadStartWaiters
            staleReadStartWaiters.removeAll()
            waiters.forEach { $0.resume() }
            let result = await withCheckedContinuation { continuation in
                staleReadContinuation = continuation
            }

            staleReadCompleted = true
            let completionWaiters = staleReadCompletionWaiters
            staleReadCompletionWaiters.removeAll()
            completionWaiters.forEach { $0.resume() }
            return result
        }
        return values
    }

    func applyOperation(
        _ operation: MenuBarSpacingDefaultsPlan.Operation,
        key: String,
        scope: MenuBarSpacingPreferenceScope
    ) throws {
        operations.append(SpacingOperation(key: key, operation: operation, scope: scope))
        if key == failingKey, remainingOperationFailures > 0 {
            remainingOperationFailures -= 1
            throw SpacingHarnessError.plannedOperationFailure
        }
        guard !ignoresOperations else { return }

        let value: Int?
        switch operation {
        case .write(let writtenValue):
            value = writtenValue
        case .delete:
            value = nil
        }

        if key == MenuBarSpacingDefaultsPlan.keys[0] {
            values.spacing = value
        } else if key == MenuBarSpacingDefaultsPlan.keys[1] {
            values.selectionPadding = value
        }
    }

    func refresh(_ strategy: MenuBarSpacingRefreshStrategy) async -> MenuBarSpacingRefreshResult {
        refreshStrategies.append(strategy)
        guard delaysRefresh else { return refreshResult }

        let waiters = refreshStartWaiters
        refreshStartWaiters.removeAll()
        waiters.forEach { $0.resume() }
        return await withCheckedContinuation { continuation in
            refreshContinuation = continuation
        }
    }

    func waitForRefreshStart() async {
        guard refreshStrategies.isEmpty else { return }
        await withCheckedContinuation { continuation in
            refreshStartWaiters.append(continuation)
        }
    }

    func completeRefresh(with result: MenuBarSpacingRefreshResult) {
        let continuation = refreshContinuation
        refreshContinuation = nil
        continuation?.resume(returning: result)
    }

    func waitForStaleReadStart() async {
        guard !staleReadStarted else { return }
        await withCheckedContinuation { continuation in
            staleReadStartWaiters.append(continuation)
        }
    }

    func completeStaleRead() {
        let continuation = staleReadContinuation
        staleReadContinuation = nil
        continuation?.resume(returning: staleFirstRead ?? values)
    }

    func waitForStaleReadCompletion() async {
        guard !staleReadCompleted else { return }
        await withCheckedContinuation { continuation in
            staleReadCompletionWaiters.append(continuation)
        }
    }

    func snapshot() -> SpacingHarnessSnapshot {
        SpacingHarnessSnapshot(
            values: values,
            operations: operations,
            readScopes: readScopes,
            refreshStrategies: refreshStrategies
        )
    }
}

private func makeDependencies(
    harness: SpacingHarness,
    context: MenuBarSpacingSystemContext
) -> MenuBarSpacingDependencies {
    MenuBarSpacingDependencies(
        readValues: { scope in
            try await harness.readValues(scope: scope)
        },
        applyOperation: { operation, key, scope in
            try await harness.applyOperation(operation, key: key, scope: scope)
        },
        refresh: { strategy in
            await harness.refresh(strategy)
        },
        systemContext: {
            context
        }
    )
}

@MainActor
private func waitUntil(
    timeout: Duration = .seconds(2),
    _ condition: () -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now.advanced(by: timeout)
    while !condition(), ContinuousClock.now < deadline {
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}
