import Combine
import Foundation
import IOKit.pwr_mgt

struct PowerAssertionClient: Sendable {
    var create: @Sendable (_ keepDisplayAwake: Bool) throws -> IOPMAssertionID
    var release: @Sendable (IOPMAssertionID) -> Void

    static let live = PowerAssertionClient(
        create: { keepDisplayAwake in
            var assertion: IOPMAssertionID = 0
            let type = keepDisplayAwake ? kIOPMAssertionTypePreventUserIdleDisplaySleep : kIOPMAssertionTypePreventUserIdleSystemSleep
            let result = IOPMAssertionCreateWithName(
                type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn),
                "macMender Keep Awake session" as CFString, &assertion
            )
            guard result == kIOReturnSuccess else { throw PowerAssertionError.creationFailed }
            return assertion
        },
        release: { _ = IOPMAssertionRelease($0) }
    )
}

private enum PowerAssertionError: LocalizedError {
    case creationFailed
    var errorDescription: String? { "macOS could not start Keep Awake. Try starting the session again." }
}

@MainActor
final class KeepAwakeService: ObservableObject {
    @Published private(set) var session: KeepAwakeSession?
    @Published private(set) var errorMessage: String?
    private let client: PowerAssertionClient
    private let sleep: @Sendable (TimeInterval) async throws -> Void
    private var assertion: IOPMAssertionID?
    private var expirationTask: Task<Void, Never>?

    init(
        client: PowerAssertionClient = .live,
        sleep: @escaping @Sendable (TimeInterval) async throws -> Void = { try await Task.sleep(for: .seconds($0)) }
    ) {
        self.client = client
        self.sleep = sleep
    }

    deinit {
        expirationTask?.cancel()
        if let assertion { client.release(assertion) }
    }

    var isActive: Bool { session != nil }

    func start(duration: KeepAwakeDuration, keepDisplayAwake: Bool) {
        do {
            // Acquire first so an unsuccessful replacement leaves the current session intact.
            let nextAssertion = try client.create(keepDisplayAwake)
            stop()
            assertion = nextAssertion
            session = KeepAwakeSession(
                endsAt: duration.seconds.map { Date().addingTimeInterval($0) },
                keepsDisplayAwake: keepDisplayAwake
            )
            guard let seconds = duration.seconds else { return }
            let sleep = sleep
            expirationTask = Task { [weak self] in
                do {
                    try await sleep(seconds)
                    try Task.checkCancellation()
                    self?.stop()
                } catch { /* Stopped or replaced. */ }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func stop() {
        expirationTask?.cancel()
        expirationTask = nil
        if let assertion { client.release(assertion) }
        assertion = nil
        session = nil
        errorMessage = nil
    }
}
