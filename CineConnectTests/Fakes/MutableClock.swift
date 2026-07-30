import Foundation

/// A controllable clock for deterministic cache-TTL tests - lets a test
/// advance time instantly instead of sleeping for real seconds.
///
/// `@unchecked Sendable` justification: all mutable state (`current`) is
/// guarded by `lock`; every read and write takes it. This is a test-only
/// helper, not production code.
final class MutableClock: @unchecked Sendable {
    private let lock = NSLock()
    private var current: Date

    init(_ date: Date = Date(timeIntervalSince1970: 0)) {
        self.current = date
    }

    func now() -> Date {
        lock.lock()
        defer { lock.unlock() }
        return current
    }

    func advance(by seconds: TimeInterval) {
        lock.lock()
        defer { lock.unlock() }
        current = current.addingTimeInterval(seconds)
    }
}
