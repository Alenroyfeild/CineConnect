import Foundation

/// Generic, TTL-based, LRU-evicted in-memory cache. Actor-isolated because
/// its `storage`/`accessOrder` dictionaries are genuinely mutable state
/// that concurrent search/detail requests can read and write at the same
/// time - unlike `KeychainStore` (Phase 5), this one *is* protecting a
/// real potential data race, not just presenting an async interface.
actor MemoryCache<Key: Hashable & Sendable, Value: Sendable> {
    private struct Entry {
        let value: Value
        let expiresAt: Date
    }

    private var storage: [Key: Entry] = [:]
    /// Least-recently-used first. A plain array is fine at this app's
    /// scale (tens of entries, not millions) - a production cache with a
    /// much larger working set would want an actual LRU list structure.
    private var accessOrder: [Key] = []

    private let maxEntries: Int
    private let ttl: TimeInterval
    /// Injected so tests can control time deterministically instead of
    /// racing real TTL expiry with `Task.sleep`.
    private let now: @Sendable () -> Date

    private(set) var hitCount = 0
    private(set) var missCount = 0

    init(maxEntries: Int = 50, ttl: TimeInterval, now: @escaping @Sendable () -> Date = { Date() }) {
        self.maxEntries = maxEntries
        self.ttl = ttl
        self.now = now
    }

    /// A "fresh" read: `nil` if the key was never cached, or if it has
    /// expired (an expired entry is also evicted here, not just ignored).
    func value(forKey key: Key) -> Value? {
        guard let entry = storage[key] else {
            missCount += 1
            return nil
        }
        guard entry.expiresAt > now() else {
            storage.removeValue(forKey: key)
            accessOrder.removeAll { $0 == key }
            missCount += 1
            return nil
        }
        hitCount += 1
        touch(key)
        return entry.value
    }

    /// A "stale-acceptable" read: returns a cached value even if its TTL
    /// has passed, without removing it. Used only for the `.networkFirst`
    /// failure-fallback path - a real network failure with stale cached
    /// data is a better user experience than no data at all.
    func staleValue(forKey key: Key) -> Value? {
        storage[key]?.value
    }

    func setValue(_ value: Value, forKey key: Key) {
        storage[key] = Entry(value: value, expiresAt: now().addingTimeInterval(ttl))
        touch(key)
        evictLeastRecentlyUsedIfNeeded()
    }

    func removeValue(forKey key: Key) {
        storage.removeValue(forKey: key)
        accessOrder.removeAll { $0 == key }
    }

    func removeAll() {
        storage.removeAll()
        accessOrder.removeAll()
    }

    private func touch(_ key: Key) {
        accessOrder.removeAll { $0 == key }
        accessOrder.append(key)
    }

    private func evictLeastRecentlyUsedIfNeeded() {
        while storage.count > maxEntries, !accessOrder.isEmpty {
            let oldest = accessOrder.removeFirst()
            storage.removeValue(forKey: oldest)
        }
    }
}
