import Foundation
import Testing
@testable import CineConnect

/// Pure, deterministic tests of `RetryPolicy`'s decision logic - no
/// networking, no real delays (all policies here inject a no-op `sleep`).
@MainActor
@Suite
struct RetryPolicyTests {
    private func makePolicy(maxAttempts: Int) -> RetryPolicy {
        RetryPolicy(maxAttempts: maxAttempts, baseDelayNanoseconds: 0, maxDelayNanoseconds: 0, sleep: { _ in })
    }

    @Test func neverRetriesCancellation() {
        let policy = makePolicy(maxAttempts: 5)
        #expect(policy.shouldRetry(error: CancellationError(), attempt: 0) == false)
    }

    @Test func retriesSelectedTransientURLErrors() {
        let policy = makePolicy(maxAttempts: 3)
        for code: URLError.Code in [.timedOut, .networkConnectionLost, .notConnectedToInternet, .dnsLookupFailed] {
            #expect(policy.shouldRetry(error: URLError(code), attempt: 0) == true)
        }
    }

    @Test func doesNotRetryNonTransientURLErrors() {
        let policy = makePolicy(maxAttempts: 3)
        #expect(policy.shouldRetry(error: URLError(.badURL), attempt: 0) == false)
        #expect(policy.shouldRetry(error: URLError(.cancelled), attempt: 0) == false)
    }

    @Test func retries429And5xxButNot4xxOtherwise() {
        let policy = makePolicy(maxAttempts: 3)
        #expect(policy.shouldRetry(error: RemoteError.general(status: "", statusCode: 429), attempt: 0) == true)
        #expect(policy.shouldRetry(error: RemoteError.general(status: "", statusCode: 503), attempt: 0) == true)
        #expect(policy.shouldRetry(error: RemoteError.general(status: "", statusCode: 404), attempt: 0) == false)
        #expect(policy.shouldRetry(error: RemoteError.general(status: "", statusCode: 400), attempt: 0) == false)
    }

    @Test func stopsRetryingOnceMaxAttemptsReached() {
        let policy = makePolicy(maxAttempts: 2)
        // attempt 0 -> would become attempt 1 (< 2 attempts total) - allowed
        #expect(policy.shouldRetry(error: URLError(.timedOut), attempt: 0) == true)
        // attempt 1 -> would become attempt 2 (not < 2) - no more retries
        #expect(policy.shouldRetry(error: URLError(.timedOut), attempt: 1) == false)
    }

    @Test func delayGrowsExponentiallyAndIsBounded() {
        let policy = RetryPolicy(maxAttempts: 10, baseDelayNanoseconds: 100, maxDelayNanoseconds: 350, sleep: { _ in })
        #expect(policy.delayNanoseconds(forAttempt: 0) == 100)
        #expect(policy.delayNanoseconds(forAttempt: 1) == 200)
        #expect(policy.delayNanoseconds(forAttempt: 2) == 350) // would be 400, capped at 350
        #expect(policy.delayNanoseconds(forAttempt: 5) == 350) // still capped
    }

    @Test func waitBeforeRetryingPropagatesCancellationFromInjectedSleep() async {
        let policy = RetryPolicy(maxAttempts: 3, baseDelayNanoseconds: 0, maxDelayNanoseconds: 0, sleep: { _ in
            throw CancellationError()
        })

        await #expect(throws: CancellationError.self) {
            try await policy.waitBeforeRetrying(attempt: 0)
        }
    }
}
