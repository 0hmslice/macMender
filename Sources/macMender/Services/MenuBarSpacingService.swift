import Foundation

struct MenuBarSpacingDefaultsPlan: Equatable {
    enum Operation: Equatable {
        case write(Int)
        case delete
    }

    static let keys = [
        "NSStatusItemSpacing",
        "NSStatusItemSelectionPadding"
    ]

    var preference: MenuBarSpacingPreference
    var operation: Operation
}

@MainActor
final class MenuBarSpacingService: ObservableObject {
    @Published private(set) var isApplying = false
    @Published private(set) var statusDescription = "System spacing"

    nonisolated static func defaultsPlan(for preference: MenuBarSpacingPreference) -> MenuBarSpacingDefaultsPlan {
        if let value = preference.defaultsValue {
            return MenuBarSpacingDefaultsPlan(preference: preference, operation: .write(value))
        }
        return MenuBarSpacingDefaultsPlan(preference: preference, operation: .delete)
    }

    func apply(_ preference: MenuBarSpacingPreference) {
        guard !isApplying else { return }
        isApplying = true
        statusDescription = "Applying \(preference.title.lowercased()) spacing..."
        let plan = Self.defaultsPlan(for: preference)

        Task { [weak self] in
            let result = await Self.apply(plan)
            await MainActor.run {
                self?.isApplying = false
                self?.statusDescription = result
            }
        }
    }

    private nonisolated static func apply(_ plan: MenuBarSpacingDefaultsPlan) async -> String {
        do {
            for key in MenuBarSpacingDefaultsPlan.keys {
                try await runDefaults(arguments(for: plan.operation, key: key), allowsNonzeroExit: plan.operation == .delete)
            }
            switch plan.operation {
            case .delete:
                return "System default restored. Some menu bar apps may need to relaunch or you may need to log out."
            case .write:
                return "\(plan.preference.title) spacing applied. Some menu bar apps may need to relaunch or you may need to log out."
            }
        } catch {
            return "Spacing update failed."
        }
    }

    private nonisolated static func arguments(for operation: MenuBarSpacingDefaultsPlan.Operation, key: String) -> [String] {
        switch operation {
        case .delete:
            ["-currentHost", "delete", "-globalDomain", key]
        case .write(let value):
            ["-currentHost", "write", "-globalDomain", key, "-int", "\(value)"]
        }
    }

    private nonisolated static func runDefaults(_ arguments: [String], allowsNonzeroExit: Bool) async throws {
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            process.arguments = arguments
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0, !allowsNonzeroExit {
                throw CocoaError(.fileWriteUnknown)
            }
        }.value
    }
}
