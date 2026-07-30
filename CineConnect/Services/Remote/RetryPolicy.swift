import Foundation

/// Bounded exponential-backoff retry, used only for idempotent (GET)
/// requests - `RemoteService` checks the request's method before consulting
/// this policy at all, so POST/write requests are never silently retried.
struct RetryPolicy {
    let maxAttempts: Int
    private let baseDelayNanoseconds: UInt64
    private let maxDelayNanoseconds: UInt64
    /// Injectable so tests can make retries instant instead of waiting on
    /// real backoff delays; defaults to a real `Task.sleep`.
    private let sleep: (UInt64) async throws -> Void

    init(
        maxAttempts: Int,
        baseDelayNanoseconds: UInt64,
        maxDelayNanoseconds: UInt64,
        sleep: @escaping (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }
    ) {
        self.maxAttempts = maxAttempts
        self.baseDelayNanoseconds = baseDelayNanoseconds
        self.maxDelayNanoseconds = maxDelayNanoseconds
        self.sleep = sleep
    }

    static let `default` = RetryPolicy(
        maxAttempts: 3,
        baseDelayNanoseconds: 500_000_000, // 0.5s
        maxDelayNanoseconds: 4_000_000_000 // 4s ceiling
    )

    /// A policy that never retries and never sleeps - used by default for
    /// non-idempotent requests, and directly in tests that don't care about
    /// retry behavior.
    static let none = RetryPolicy(maxAttempts: 1, baseDelayNanoseconds: 0, maxDelayNanoseconds: 0)

    /// Whether `error`, seen on the given zero-indexed `attempt`, is worth
    /// retrying. Never retries `CancellationError` - a cancelled request
    /// isn't a transient failure, it's the caller no longer wanting a
    /// result at all.
    func shouldRetry(error: Error, attempt: Int) -> Bool {
        guard attempt + 1 < maxAttempts else { return false }
        if error is CancellationError {
            return false
        }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .timedOut, .networkConnectionLost, .notConnectedToInternet, .dnsLookupFailed:
                return true
            default:
                return false
            }
        }
        if case RemoteError.general(_, let statusCode) = error {
            return statusCode == 429 || (500...504).contains(statusCode)
        }
        return false
    }

    func delayNanoseconds(forAttempt attempt: Int) -> UInt64 {
        let exponential = baseDelayNanoseconds * (UInt64(1) << UInt64(attempt))
        return min(exponential, maxDelayNanoseconds)
    }

    /// Sleeps for the backoff delay for `attempt`. Propagates
    /// `CancellationError` immediately if the delay itself is cancelled -
    /// the caller must not swallow it and retry anyway.
    func waitBeforeRetrying(attempt: Int) async throws {
        try await sleep(delayNanoseconds(forAttempt: attempt))
    }
}
