import Foundation
import Testing
@testable import Assignment

@Suite
struct InFlightRequestStoreTests {
    private actor CallCounter {
        private(set) var count = 0
        func increment() -> Int {
            count += 1
            return count
        }
    }

    @Test func tenSimultaneousCallsForTheSameKeyShareOneOperationCall() async throws {
        let store = InFlightRequestStore<String, Int>()
        let counter = CallCounter()

        // Every concurrent caller asks for the same key ("slug") - this is
        // the actor-reentrancy scenario documented on InFlightRequestStore:
        // the "check for an existing task, else register a new one" logic
        // has no `await` in between, so all ten callers arriving before
        // the operation completes correctly converge on one shared Task.
        let results = try await withThrowingTaskGroup(of: Int.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    try await store.value(forKey: "slug") {
                        try await Task.sleep(nanoseconds: 50_000_000) // 50ms - long enough for all 10 to arrive first
                        return await counter.increment()
                    }
                }
            }
            var collected: [Int] = []
            for try await result in group { collected.append(result) }
            return collected
        }

        #expect(results.count == 10)
        #expect(results.allSatisfy { $0 == 1 }) // all ten got the SAME single call's result
        #expect(await counter.count == 1)
    }

    @Test func differentKeysProceedConcurrentlyNotSerially() async throws {
        let store = InFlightRequestStore<String, Int>()
        let counter = CallCounter()

        let results = try await withThrowingTaskGroup(of: Int.self) { group in
            for key in ["a", "b", "c"] {
                group.addTask {
                    try await store.value(forKey: key) {
                        try await Task.sleep(nanoseconds: 10_000_000)
                        return await counter.increment()
                    }
                }
            }
            var collected: [Int] = []
            for try await result in group { collected.append(result) }
            return collected
        }

        // Three distinct keys -> three distinct operation calls, each
        // getting its own increment (order not guaranteed, set of values is).
        #expect(Set(results) == [1, 2, 3])
    }

    @Test func failedTaskIsRemovedSoTheNextCallRetries() async {
        let store = InFlightRequestStore<String, Int>()
        struct Failure: Error {}

        await #expect(throws: Failure.self) {
            try await store.value(forKey: "a") { throw Failure() }
        }

        // If the failed task weren't removed, this would hang awaiting a
        // dead task's already-thrown result forever instead of running fresh.
        let result = try? await store.value(forKey: "a") { 42 }
        #expect(result == 42)
    }

    @Test func completedTaskIsRemovedSoASecondCallRunsAgain() async throws {
        let store = InFlightRequestStore<String, Int>()
        let counter = CallCounter()

        let first = try await store.value(forKey: "a") { await counter.increment() }
        let second = try await store.value(forKey: "a") { await counter.increment() }

        #expect(first == 1)
        #expect(second == 2) // not coalesced with the first - it had already completed
    }
}
