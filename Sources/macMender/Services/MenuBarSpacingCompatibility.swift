import Foundation

enum MenuBarSpacingCompatibility {
    private enum UpdateError: Error {
        case verificationFailed
    }

    static func defaultsPlan(
        for preference: MenuBarSpacingPreference,
        customValue: Int = MenuBarSpacingPreference.systemDefaultNumericValue
    ) -> MenuBarSpacingDefaultsPlan {
        if let value = preference.resolvedDefaultsValue(customValue: customValue) {
            return MenuBarSpacingDefaultsPlan(preference: preference, operation: .write(value))
        }
        return MenuBarSpacingDefaultsPlan(preference: preference, operation: .delete)
    }

    static func strategy(
        for context: MenuBarSpacingSystemContext
    ) -> MenuBarSpacingCompatibilityStrategy {
        let support: MenuBarSpacingSystemItemSupport
        let refresh: MenuBarSpacingRefreshStrategy

        if context.majorVersion < 27 {
            support = .legacy
            refresh = .controlCenter
        } else if context.majorVersion == 27 {
            // A MenuBarAgent restart was tested on 27.0 (26A428) with verified
            // preference writes; Apple item frames did not move. See docs/UPGRADE.md.
            support = .unverifiedSystemItems
            refresh = .none
        } else {
            support = .unconfirmed
            refresh = .none
        }

        return MenuBarSpacingCompatibilityStrategy(
            preferenceScope: .currentHostGlobal,
            refreshStrategy: refresh,
            systemItemSupport: support
        )
    }

    static func applicationResult(
        for plan: MenuBarSpacingDefaultsPlan,
        strategy: MenuBarSpacingCompatibilityStrategy,
        refreshResult: MenuBarSpacingRefreshResult,
        allItemsConfirmed: Bool = false
    ) -> MenuBarSpacingApplicationResult {
        if allItemsConfirmed {
            let action = plan.operation == .delete ? "System Default restored." : "Preference saved."
            return MenuBarSpacingApplicationResult(
                kind: .applied,
                detail: "\(action) macMender and observed menu bar items updated."
            )
        }

        if plan.operation == .delete {
            return resetResult(strategy: strategy, refreshResult: refreshResult)
        }

        switch strategy.systemItemSupport {
        case .unverifiedSystemItems:
            return MenuBarSpacingApplicationResult(
                kind: .unverifiedSystemItems,
                detail: "Preference saved and macMender’s icon width updated. Apple system-wide spacing is unverified on macOS 27. Other apps may ignore these preferences or need relaunch."
            )
        case .unconfirmed:
            return MenuBarSpacingApplicationResult(
                kind: .couldNotConfirmSystemItemUpdate,
                detail: "Preference saved. macMender updated. Apple system item behavior is unconfirmed on this macOS version; third-party apps may need relaunch."
            )
        case .legacy:
            if refreshResult == .refreshed {
                return MenuBarSpacingApplicationResult(
                    kind: .appliedSomeAppsMayNeedRelaunch,
                    detail: "Preference saved. macMender updated immediately and Control Center was refreshed."
                )
            }
            return MenuBarSpacingApplicationResult(
                kind: .couldNotConfirmSystemItemUpdate,
                detail: "Preference saved. macMender updated, but the system item refresh could not be confirmed; third-party apps may need relaunch."
            )
        }
    }

    static func arguments(
        for operation: MenuBarSpacingDefaultsPlan.Operation,
        key: String,
        scope: MenuBarSpacingPreferenceScope = .currentHostGlobal
    ) -> [String] {
        switch (scope, operation) {
        case (.currentHostGlobal, .delete):
            ["-currentHost", "delete", "-globalDomain", key]
        case (.currentHostGlobal, .write(let value)):
            ["-currentHost", "write", "-globalDomain", key, "-int", "\(value)"]
        }
    }

    static func idleStatus(
        for values: MenuBarSpacingDefaultsValues,
        strategy: MenuBarSpacingCompatibilityStrategy
    ) -> (kind: MenuBarSpacingResultKind?, description: String) {
        switch strategy.systemItemSupport {
        case .legacy:
            (nil, values.description)
        case .unverifiedSystemItems:
            (
                .unverifiedSystemItems,
                "System-wide spacing is unverified on macOS 27. macMender can adjust its own icon; other apps may ignore these preferences. \(values.description)"
            )
        case .unconfirmed:
            (
                .couldNotConfirmSystemItemUpdate,
                "Could not confirm Apple system item behavior on this macOS version; other AppKit status items may need relaunch. \(values.description)"
            )
        }
    }

    static func updatePreferences(
        plan: MenuBarSpacingDefaultsPlan,
        strategy: MenuBarSpacingCompatibilityStrategy,
        dependencies: MenuBarSpacingDependencies
    ) async -> MenuBarSpacingPreferenceUpdateResult {
        let scope = strategy.preferenceScope
        let originalValues: MenuBarSpacingDefaultsValues

        do {
            originalValues = try await dependencies.readValues(scope)
        } catch {
            return MenuBarSpacingPreferenceUpdateResult(
                currentValues: nil,
                preferenceVerified: false,
                rollbackSucceeded: false,
                failureResult: MenuBarSpacingApplicationResult(
                    kind: .failed,
                    detail: "The current preference could not be read. No changes were made."
                )
            )
        }

        do {
            for key in MenuBarSpacingDefaultsPlan.keys {
                try await dependencies.applyOperation(plan.operation(for: key), key, scope)
            }
            let verifiedValues = try await dependencies.readValues(scope)
            guard verifiedValues.matches(plan) else {
                throw UpdateError.verificationFailed
            }
            return MenuBarSpacingPreferenceUpdateResult(
                currentValues: verifiedValues,
                preferenceVerified: true,
                rollbackSucceeded: false,
                failureResult: nil
            )
        } catch {
            let restoreReadbackMatched = await restore(
                originalValues,
                scope: scope,
                dependencies: dependencies
            )
            let valuesAfterFailure = try? await dependencies.readValues(scope)
            let rollbackSucceeded = valuesAfterFailure.map { $0 == originalValues } ?? restoreReadbackMatched
            let knownValues = valuesAfterFailure ?? (restoreReadbackMatched ? originalValues : nil)

            return MenuBarSpacingPreferenceUpdateResult(
                currentValues: knownValues,
                preferenceVerified: false,
                rollbackSucceeded: rollbackSucceeded,
                failureResult: MenuBarSpacingApplicationResult(
                    kind: .failed,
                    detail: rollbackSucceeded ?
                        "The original preference values were restored." :
                        "The preference values could not be fully restored; use Reset to Default or try again."
                )
            )
        }
    }

    static func execute(
        plan: MenuBarSpacingDefaultsPlan,
        dependencies: MenuBarSpacingDependencies
    ) async -> MenuBarSpacingExecutionResult {
        let selectedStrategy = strategy(for: dependencies.systemContext())
        let update = await updatePreferences(
            plan: plan,
            strategy: selectedStrategy,
            dependencies: dependencies
        )
        guard update.preferenceVerified else {
            return MenuBarSpacingExecutionResult(
                applicationResult: update.failureResult ?? MenuBarSpacingApplicationResult(
                    kind: .failed,
                    detail: "The preference update did not complete."
                ),
                currentValues: update.currentValues,
                preferenceVerified: false,
                rollbackSucceeded: update.rollbackSucceeded
            )
        }

        let refreshResult = await dependencies.refresh(selectedStrategy.refreshStrategy)
        return MenuBarSpacingExecutionResult(
            applicationResult: applicationResult(
                for: plan,
                strategy: selectedStrategy,
                refreshResult: refreshResult
            ),
            currentValues: update.currentValues,
            preferenceVerified: true,
            rollbackSucceeded: false
        )
    }

    private static func resetResult(
        strategy: MenuBarSpacingCompatibilityStrategy,
        refreshResult: MenuBarSpacingRefreshResult
    ) -> MenuBarSpacingApplicationResult {
        switch strategy.systemItemSupport {
        case .unverifiedSystemItems:
            return MenuBarSpacingApplicationResult(
                kind: .appliedSomeAppsMayNeedRelaunch,
                detail: "System Default restored. macOS now chooses macMender’s icon width. Other apps may need relaunch."
            )
        case .unconfirmed:
            return MenuBarSpacingApplicationResult(
                kind: .appliedSomeAppsMayNeedRelaunch,
                detail: "System Default preference restored and macMender updated. Apple system item refresh remains unconfirmed on this macOS version."
            )
        case .legacy:
            if refreshResult == .refreshed {
                return MenuBarSpacingApplicationResult(
                    kind: .appliedSomeAppsMayNeedRelaunch,
                    detail: "System Default restored. macMender updated immediately and Control Center was refreshed."
                )
            }
            return MenuBarSpacingApplicationResult(
                kind: .couldNotConfirmSystemItemUpdate,
                detail: "System Default preference restored and macMender updated, but the system item refresh could not be confirmed."
            )
        }
    }

    private static func restore(
        _ values: MenuBarSpacingDefaultsValues,
        scope: MenuBarSpacingPreferenceScope,
        dependencies: MenuBarSpacingDependencies
    ) async -> Bool {
        let originalValues = [values.spacing, values.selectionPadding]

        for (key, value) in zip(MenuBarSpacingDefaultsPlan.keys, originalValues) {
            do {
                let operation: MenuBarSpacingDefaultsPlan.Operation = value.map {
                    .write($0)
                } ?? .delete
                try await dependencies.applyOperation(operation, key, scope)
            } catch {
                // A command can report failure even when the requested state was
                // already present. The final readback is the source of truth.
            }
        }

        guard let restoredValues = try? await dependencies.readValues(scope) else {
            return false
        }
        return restoredValues == values
    }
}
