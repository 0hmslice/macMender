import AppKit
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

struct MenuBarSpacingDefaultsValues: Equatable {
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
            "Current system value: Default"
        case let (spacing?, selectionPadding?) where spacing == selectionPadding:
            "Current system value: \(spacing)"
        case let (spacing, selectionPadding):
            "Current system values: spacing \(spacing.map(String.init) ?? "default"), selection padding \(selectionPadding.map(String.init) ?? "default")"
        }
    }
}

@MainActor
final class MenuBarSpacingService: ObservableObject {
    @Published private(set) var isApplying = false
    @Published private(set) var statusDescription = "System spacing"
    @Published private(set) var currentValues = MenuBarSpacingDefaultsValues(spacing: nil, selectionPadding: nil)

    nonisolated static func defaultsPlan(for preference: MenuBarSpacingPreference, customValue: Int = MenuBarSpacingPreference.systemDefaultNumericValue) -> MenuBarSpacingDefaultsPlan {
        if let value = preference.resolvedDefaultsValue(customValue: customValue) {
            return MenuBarSpacingDefaultsPlan(preference: preference, operation: .write(value))
        }
        return MenuBarSpacingDefaultsPlan(preference: preference, operation: .delete)
    }

    func refreshCurrentValues() {
        currentValues = Self.readCurrentValues()
        statusDescription = currentValues.description
    }

    func apply(_ preference: MenuBarSpacingPreference, customValue: Int) {
        guard !isApplying else { return }
        isApplying = true
        statusDescription = "Applying \(preference.title.lowercased()) spacing..."
        let plan = Self.defaultsPlan(for: preference, customValue: customValue)

        Task { [weak self] in
            let result = await Self.apply(plan)
            let currentValues = Self.readCurrentValues()
            await MainActor.run {
                self?.isApplying = false
                self?.currentValues = currentValues
                self?.statusDescription = result
            }
        }
    }

    private nonisolated static func apply(_ plan: MenuBarSpacingDefaultsPlan) async -> String {
        do {
            for key in MenuBarSpacingDefaultsPlan.keys {
                try await runDefaults(arguments(for: plan.operation, key: key), allowsNonzeroExit: plan.operation == .delete)
            }
            let refreshResult = await refreshControlCenter()
            switch plan.operation {
            case .delete:
                return "System default restored. \(refreshResult)"
            case .write:
                return "\(plan.preference.title) spacing applied. \(refreshResult)"
            }
        } catch {
            return "Spacing update failed."
        }
    }

    private nonisolated static func readCurrentValues() -> MenuBarSpacingDefaultsValues {
        MenuBarSpacingDefaultsValues(
            spacing: currentValue(for: MenuBarSpacingDefaultsPlan.keys[0]),
            selectionPadding: currentValue(for: MenuBarSpacingDefaultsPlan.keys[1])
        )
    }

    private nonisolated static func currentValue(for key: String) -> Int? {
        CFPreferencesCopyValue(
            key as CFString,
            kCFPreferencesAnyApplication,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        ) as? Int
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

    private nonisolated static func refreshControlCenter() async -> String {
        await Task.detached {
            guard let controlCenter = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.controlcenter").first else {
                return "Menu bar refresh requested."
            }
            if controlCenter.terminate() {
                waitForTermination(controlCenter, timeout: .seconds(1))
            }
            if !controlCenter.isTerminated {
                controlCenter.forceTerminate()
                waitForTermination(controlCenter, timeout: .milliseconds(300))
            }
            return controlCenter.isTerminated ?
                "Control Center was refreshed; icons may briefly reload." :
                "Menu bar refresh requested; Control Center may need a moment to update."
        }.value
    }

    private nonisolated static func waitForTermination(_ app: NSRunningApplication, timeout: Duration) {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !app.isTerminated, ContinuousClock.now < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
    }
}
