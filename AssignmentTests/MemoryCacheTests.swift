import Foundation
import Testing
@testable import Assignment

@Suite
struct MemoryCacheTests {
    @Test func missOnEmptyCache() async {
        let cache = MemoryCache<String, Int>(ttl: 60)
        #expect(await cache.value(forKey: "a") == nil)
    }

    @Test func hitAfterSet() async {
        let cache = MemoryCache<String, Int>(ttl: 60)
        await cache.setValue(1, forKey: "a")
        #expect(await cache.value(forKey: "a") == 1)
    }

    @Test func expiredEntryIsAMissAndIsEvicted() async {
        let clock = MutableClock()
        let cache = MemoryCache<String, Int>(ttl: 10, now: { clock.now() })
        await cache.setValue(1, forKey: "a")

        clock.advance(by: 11)

        #expect(await cache.value(forKey: "a") == nil)
    }

    @Test func staleValueIsReturnedEvenAfterExpiry() async {
        let clock = MutableClock()
        let cache = MemoryCache<String, Int>(ttl: 10, now: { clock.now() })
        await cache.setValue(1, forKey: "a")

        clock.advance(by: 11)

        // Order matters here: `staleValue` doesn't evict, so checking it
        // first proves the entry survives past its TTL; checking `value`
        // afterward proves a fresh read still correctly reports expiry
        // (and evicts) even after a stale read already happened.
        #expect(await cache.staleValue(forKey: "a") == 1)    // stale-acceptable read: still there
        #expect(await cache.value(forKey: "a") == nil)       // fresh read: expired
    }

    @Test func hitAndMissCountsAreTracked() async {
        let cache = MemoryCache<String, Int>(ttl: 60)
        _ = await cache.value(forKey: "missing")
        await cache.setValue(1, forKey: "a")
        _ = await cache.value(forKey: "a")

        #expect(await cache.missCount == 1)
        #expect(await cache.hitCount == 1)
    }

    @Test func leastRecentlyUsedEntryIsEvictedWhenOverCapacity() async {
        let cache = MemoryCache<String, Int>(maxEntries: 2, ttl: 60)
        await cache.setValue(1, forKey: "a")
        await cache.setValue(2, forKey: "b")
        await cache.setValue(3, forKey: "c") // "a" is least recently used, should be evicted

        #expect(await cache.value(forKey: "a") == nil)
        #expect(await cache.value(forKey: "b") == 2)
        #expect(await cache.value(forKey: "c") == 3)
    }

    @Test func readingAnEntryProtectsItFromEviction() async {
        let cache = MemoryCache<String, Int>(maxEntries: 2, ttl: 60)
        await cache.setValue(1, forKey: "a")
        await cache.setValue(2, forKey: "b")
        _ = await cache.value(forKey: "a") // touch "a" - "b" becomes least recently used
        await cache.setValue(3, forKey: "c")

        #expect(await cache.value(forKey: "a") == 1)
        #expect(await cache.value(forKey: "b") == nil)
    }

    @Test func removeAllClearsEverything() async {
        let cache = MemoryCache<String, Int>(ttl: 60)
        await cache.setValue(1, forKey: "a")
        await cache.removeAll()
        #expect(await cache.value(forKey: "a") == nil)
    }
}
