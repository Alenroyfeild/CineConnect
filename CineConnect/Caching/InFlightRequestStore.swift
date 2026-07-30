import Foundation

/// Coalesces concurrent requests for the same key into one shared `Task`,
/// so ten simultaneous callers asking for the same movie detail trigger
/// exactly one network call, not ten.
///
/// Actor reentrancy note (see docs/Learning/Architecture/Phase-06-Caching.md
/// for the full walkthrough with a test): the check-for-existing-task and
/// register-new-task steps below have **no `await` between them** - from
/// the actor's perspective, that means no other call can interleave in
/// the middle, so two concurrent callers for the same key can never both
/// decide "no task exists yet" and each start their own. The only
/// suspension point is `await task.value`, which happens *after* the task
/// is already registered - a second caller arriving during that
/// suspension correctly finds and awaits the same task.
actor InFlightRequestStore<Key: Hashable & Sendable, Value: Sendable> {
    private var tasksByKey: [Key: Task<Value, Error>] = [:]

    func value(forKey key: Key, operation: @Sendable @escaping () async throws -> Value) async throws -> Value {
        if let existingTask = tasksByKey[key] {
            return try await existingTask.value
        }

        let task = Task { try await operation() }
        tasksByKey[key] = task

        // Removed on both success and failure - a failed request
        // shouldn't keep returning the same cached failure to every
        // caller forever; the next call for this key starts fresh.
        defer { tasksByKey[key] = nil }

        return try await task.value
    }
}
