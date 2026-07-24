import AppKit
import Darwin
import Foundation

enum MenuBarSpacingSystemClient {
    static func currentDefaultsValues(
        scope: MenuBarSpacingPreferenceScope = .currentHostGlobal
    ) -> MenuBarSpacingDefaultsValues {
        synchronize(scope: scope)
        return MenuBarSpacingDefaultsValues(
            spacing: integerValue(for: MenuBarSpacingDefaultsPlan.keys[0], scope: scope),
            selectionPadding: integerValue(for: MenuBarSpacingDefaultsPlan.keys[1], scope: scope)
        )
    }

    static func currentSystemContext() -> MenuBarSpacingSystemContext {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return MenuBarSpacingSystemContext(
            majorVersion: version.majorVersion,
            minorVersion: version.minorVersion,
            patchVersion: version.patchVersion,
            buildVersion: operatingSystemBuildVersion()
        )
    }

    static func applyDefaultsOperation(
        _ operation: MenuBarSpacingDefaultsPlan.Operation,
        key: String,
        scope: MenuBarSpacingPreferenceScope
    ) async throws {
        // `defaults delete` exits nonzero for a missing key. Check raw presence rather
        // than parsed integer presence so Reset still removes malformed stored values.
        if operation == .delete, rawValue(for: key, scope: scope) == nil {
            return
        }
        try await runDefaults(
            MenuBarSpacingCompatibility.arguments(
                for: operation,
                key: key,
                scope: scope
            )
        )
    }

    static func refreshHost(
        _ strategy: MenuBarSpacingRefreshStrategy
    ) async -> MenuBarSpacingRefreshResult {
        switch strategy {
        case .none:
            return .notNeeded
        case .controlCenter:
            return await Task.detached {
                let bundleIdentifier = "com.apple.controlcenter"
                guard let controlCenter = NSRunningApplication.runningApplications(
                    withBundleIdentifier: bundleIdentifier
                ).first else {
                    return .hostUnavailable
                }

                let previousPID = controlCenter.processIdentifier
                if controlCenter.terminate() {
                    waitForTermination(controlCenter, timeout: .seconds(1))
                }
                if !controlCenter.isTerminated, controlCenter.forceTerminate() {
                    waitForTermination(controlCenter, timeout: .milliseconds(500))
                }
                guard controlCenter.isTerminated else { return .failed }

                let deadline = ContinuousClock.now.advanced(by: .seconds(2))
                while ContinuousClock.now < deadline {
                    if NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
                        .contains(where: { $0.processIdentifier != previousPID }) {
                        return .refreshed
                    }
                    try? await Task.sleep(for: .milliseconds(50))
                }
                return .failed
            }.value
        }
    }

    private static func rawValue(
        for key: String,
        scope: MenuBarSpacingPreferenceScope
    ) -> Any? {
        synchronize(scope: scope)
        switch scope {
        case .currentHostGlobal:
            return CFPreferencesCopyValue(
                key as CFString,
                kCFPreferencesAnyApplication,
                kCFPreferencesCurrentUser,
                kCFPreferencesCurrentHost
            )
        }
    }

    private static func integerValue(
        for key: String,
        scope: MenuBarSpacingPreferenceScope
    ) -> Int? {
        (rawValue(for: key, scope: scope) as? NSNumber)?.intValue
    }

    private static func synchronize(scope: MenuBarSpacingPreferenceScope) {
        switch scope {
        case .currentHostGlobal:
            CFPreferencesSynchronize(
                kCFPreferencesAnyApplication,
                kCFPreferencesCurrentUser,
                kCFPreferencesCurrentHost
            )
        }
    }

    private static func runDefaults(_ arguments: [String]) async throws {
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            process.arguments = arguments
            try process.run()
            process.waitUntilExit()
            guard process.terminationReason == .exit,
                  process.terminationStatus == 0 else {
                throw CocoaError(.fileWriteUnknown)
            }
        }.value
    }

    private static func waitForTermination(
        _ app: NSRunningApplication,
        timeout: Duration
    ) {
        let deadline = ContinuousClock.now.advanced(by: timeout)
        while !app.isTerminated, ContinuousClock.now < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
    }

    private static func operatingSystemBuildVersion() -> String {
        var size = 0
        guard sysctlbyname("kern.osversion", nil, &size, nil, 0) == 0,
              size > 0 else {
            return "unknown"
        }

        var value = [CChar](repeating: 0, count: size)
        guard sysctlbyname("kern.osversion", &value, &size, nil, 0) == 0 else {
            return "unknown"
        }
        let bytes = value.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
        return String(decoding: bytes, as: UTF8.self)
    }
}

extension MenuBarSpacingDependencies {
    static let live = MenuBarSpacingDependencies(
        readValues: { scope in
            MenuBarSpacingSystemClient.currentDefaultsValues(scope: scope)
        },
        applyOperation: { operation, key, scope in
            try await MenuBarSpacingSystemClient.applyDefaultsOperation(
                operation,
                key: key,
                scope: scope
            )
        },
        refresh: { strategy in
            await MenuBarSpacingSystemClient.refreshHost(strategy)
        },
        systemContext: {
            MenuBarSpacingSystemClient.currentSystemContext()
        }
    )
}
