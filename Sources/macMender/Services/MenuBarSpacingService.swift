import Combine
import Foundation

@MainActor
final class MenuBarSpacingService: ObservableObject {
    @Published private(set) var isApplying = false
    @Published private(set) var statusDescription: String
    @Published private(set) var resultKind: MenuBarSpacingResultKind?
    @Published private(set) var currentValues: MenuBarSpacingDefaultsValues

    let systemContext: MenuBarSpacingSystemContext
    let compatibilityStrategy: MenuBarSpacingCompatibilityStrategy

    private let dependencies: MenuBarSpacingDependencies
    private var refreshTask: Task<Void, Never>?

    init(
        dependencies: MenuBarSpacingDependencies = .live,
        initialValues: MenuBarSpacingDefaultsValues? = nil
    ) {
        self.dependencies = dependencies
        systemContext = dependencies.systemContext()
        compatibilityStrategy = MenuBarSpacingCompatibility.strategy(for: systemContext)

        let values = initialValues ?? MenuBarSpacingSystemClient.currentDefaultsValues(
            scope: compatibilityStrategy.preferenceScope
        )
        currentValues = values
        let idleStatus = MenuBarSpacingCompatibility.idleStatus(
            for: values,
            strategy: compatibilityStrategy
        )
        statusDescription = idleStatus.description
        resultKind = idleStatus.kind
    }

    nonisolated static func defaultsPlan(
        for preference: MenuBarSpacingPreference,
        customValue: Int = MenuBarSpacingPreference.systemDefaultNumericValue
    ) -> MenuBarSpacingDefaultsPlan {
        MenuBarSpacingCompatibility.defaultsPlan(
            for: preference,
            customValue: customValue
        )
    }

    nonisolated static func compatibilityStrategy(
        for context: MenuBarSpacingSystemContext
    ) -> MenuBarSpacingCompatibilityStrategy {
        MenuBarSpacingCompatibility.strategy(for: context)
    }

    nonisolated static func applicationResult(
        for plan: MenuBarSpacingDefaultsPlan,
        strategy: MenuBarSpacingCompatibilityStrategy,
        refreshResult: MenuBarSpacingRefreshResult,
        allItemsConfirmed: Bool = false
    ) -> MenuBarSpacingApplicationResult {
        MenuBarSpacingCompatibility.applicationResult(
            for: plan,
            strategy: strategy,
            refreshResult: refreshResult,
            allItemsConfirmed: allItemsConfirmed
        )
    }

    nonisolated static func arguments(
        for operation: MenuBarSpacingDefaultsPlan.Operation,
        key: String,
        scope: MenuBarSpacingPreferenceScope = .currentHostGlobal
    ) -> [String] {
        MenuBarSpacingCompatibility.arguments(
            for: operation,
            key: key,
            scope: scope
        )
    }

    nonisolated static func execute(
        plan: MenuBarSpacingDefaultsPlan,
        dependencies: MenuBarSpacingDependencies
    ) async -> MenuBarSpacingExecutionResult {
        await MenuBarSpacingCompatibility.execute(
            plan: plan,
            dependencies: dependencies
        )
    }

    nonisolated static func currentDefaultsValues(
        scope: MenuBarSpacingPreferenceScope = .currentHostGlobal
    ) -> MenuBarSpacingDefaultsValues {
        MenuBarSpacingSystemClient.currentDefaultsValues(scope: scope)
    }

    nonisolated static func currentSystemContext() -> MenuBarSpacingSystemContext {
        MenuBarSpacingSystemClient.currentSystemContext()
    }

    func refreshCurrentValues() {
        guard !isApplying else { return }
        refreshTask?.cancel()

        let dependencies = dependencies
        let strategy = compatibilityStrategy
        refreshTask = Task { @MainActor [weak self] in
            do {
                let values = try await dependencies.readValues(strategy.preferenceScope)
                guard !Task.isCancelled,
                      let self,
                      !self.isApplying else {
                    return
                }

                let idleStatus = MenuBarSpacingCompatibility.idleStatus(
                    for: values,
                    strategy: strategy
                )
                self.currentValues = values
                self.statusDescription = idleStatus.description
                self.resultKind = idleStatus.kind
            } catch {
                guard !Task.isCancelled,
                      let self,
                      !self.isApplying else {
                    return
                }
                self.resultKind = .failed
                self.statusDescription = "Could not read the current menu bar spacing preference."
            }
        }
    }

    func apply(
        _ preference: MenuBarSpacingPreference,
        customValue: Int,
        onPreferenceVerified: (@MainActor () -> Void)? = nil
    ) {
        guard !isApplying else { return }
        refreshTask?.cancel()
        refreshTask = nil

        isApplying = true
        resultKind = nil
        statusDescription = "Applying \(preference.title.lowercased()) spacing..."

        let plan = Self.defaultsPlan(for: preference, customValue: customValue)
        let dependencies = dependencies
        let strategy = compatibilityStrategy

        Task { @MainActor [weak self] in
            let update = await MenuBarSpacingCompatibility.updatePreferences(
                plan: plan,
                strategy: strategy,
                dependencies: dependencies
            )
            guard let self else { return }

            guard update.preferenceVerified else {
                self.isApplying = false
                if let values = update.currentValues {
                    self.currentValues = values
                }
                let failure = update.failureResult ?? MenuBarSpacingApplicationResult(
                    kind: .failed,
                    detail: "The preference update did not complete."
                )
                self.resultKind = failure.kind
                self.statusDescription = failure.detail
                return
            }

            if let values = update.currentValues {
                self.currentValues = values
            }
            onPreferenceVerified?()
            self.statusDescription = "Preference saved. Finishing menu bar update..."

            let refreshResult = await dependencies.refresh(strategy.refreshStrategy)
            let result = MenuBarSpacingCompatibility.applicationResult(
                for: plan,
                strategy: strategy,
                refreshResult: refreshResult
            )
            self.isApplying = false
            self.resultKind = result.kind
            self.statusDescription = result.detail
        }
    }
}
