import Foundation
import IOKit.pwr_mgt
import Testing
@testable import macMender

@MainActor
struct KeepAwakeTests {
    @Test func startsInactiveAndReleasesOnStop() {
        let recorder = AssertionRecorder()
        let service = KeepAwakeService(client: recorder.client)
        #expect(!service.isActive)
        service.start(duration: .oneHour, keepDisplayAwake: false)
        #expect(service.isActive)
        #expect(service.session?.endsAt != nil)
        #expect(service.session?.keepsDisplayAwake == false)
        #expect(recorder.created == [false])
        service.stop()
        service.stop()
        #expect(!service.isActive)
        #expect(recorder.released == [1])
    }

    @Test func replacementReleasesOldAssertionAndCancelsOldTimer() async throws {
        let recorder = AssertionRecorder()
        let service = KeepAwakeService(client: recorder.client, sleep: { _ in try await Task.sleep(for: .milliseconds(10)) })
        service.start(duration: .fifteenMinutes, keepDisplayAwake: false)
        service.start(duration: .untilStopped, keepDisplayAwake: true)
        try await Task.sleep(for: .milliseconds(30))
        #expect(service.isActive)
        #expect(service.session?.endsAt == nil)
        #expect(service.session?.keepsDisplayAwake == true)
        #expect(recorder.released == [1])
        service.stop()
        #expect(recorder.released == [1, 2])
    }

    @Test func failedReplacementPreservesExistingSession() {
        let recorder = AssertionRecorder()
        let service = KeepAwakeService(client: recorder.client)
        service.start(duration: .untilStopped, keepDisplayAwake: false)
        recorder.shouldFail = true
        service.start(duration: .oneHour, keepDisplayAwake: true)
        #expect(service.isActive)
        #expect(service.session?.keepsDisplayAwake == false)
        #expect(service.errorMessage != nil)
        #expect(recorder.released.isEmpty)
        service.stop()
    }

    @Test func timedSessionExpires() async throws {
        let recorder = AssertionRecorder()
        let service = KeepAwakeService(client: recorder.client, sleep: { _ in })
        service.start(duration: .fifteenMinutes, keepDisplayAwake: false)
        for _ in 0..<100 where service.isActive { await Task.yield() }
        #expect(!service.isActive)
        #expect(recorder.released == [1])
    }

    @Test func deinitializationReleasesAssertion() {
        let recorder = AssertionRecorder()
        var service: KeepAwakeService? = KeepAwakeService(client: recorder.client)
        service?.start(duration: .untilStopped, keepDisplayAwake: true)
        service = nil
        #expect(recorder.released == [1])
    }
}

private final class AssertionRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var modes: [Bool] = []
    private var releaseIDs: [IOPMAssertionID] = []
    private var failure = false
    var created: [Bool] { lock.withLock { modes } }
    var released: [IOPMAssertionID] { lock.withLock { releaseIDs } }
    var shouldFail: Bool {
        get { lock.withLock { failure } }
        set { lock.withLock { failure = newValue } }
    }
    var client: PowerAssertionClient {
        PowerAssertionClient(create: { [self] display in
            try lock.withLock {
                if failure { throw CocoaError(.featureUnsupported) }
                modes.append(display)
                return IOPMAssertionID(modes.count)
            }
        }, release: { [self] id in lock.withLock { releaseIDs.append(id) } })
    }
}
