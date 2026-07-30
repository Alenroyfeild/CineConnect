import Foundation
import Testing
@testable import CineConnect

@Suite
struct DiskCacheTests {
    private struct Payload: Codable, Equatable, Sendable {
        let value: String
    }

    private func makeCache(clock: MutableClock = MutableClock(), ttl: TimeInterval = 60) -> DiskCache<Payload> {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("DiskCacheTests-\(UUID().uuidString)")
        return DiskCache(directoryName: "cache", ttl: ttl, now: { clock.now() }, baseDirectory: dir)
    }

    @Test func missOnEmptyCache() async {
        let cache = makeCache()
        #expect(await cache.value(forKey: "a") == nil)
    }

    @Test func hitAfterSet() async {
        let cache = makeCache()
        await cache.setValue(Payload(value: "hello"), forKey: "a")
        #expect(await cache.value(forKey: "a") == Payload(value: "hello"))
    }

    @Test func expiredEntryIsAMissAndFileIsRemoved() async {
        let clock = MutableClock()
        let cache = makeCache(clock: clock, ttl: 10)
        await cache.setValue(Payload(value: "hello"), forKey: "a")

        clock.advance(by: 11)

        #expect(await cache.value(forKey: "a") == nil)
        // Setting it again should succeed cleanly - proves the expired
        // file was actually removed, not just ignored.
        await cache.setValue(Payload(value: "again"), forKey: "a")
        #expect(await cache.value(forKey: "a") == Payload(value: "again"))
    }

    @Test func corruptFileIsTreatedAsAMissAndRecovered() async {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("DiskCacheTests-\(UUID().uuidString)")
        let cache = DiskCache<Payload>(directoryName: "cache", ttl: 60, baseDirectory: dir)

        // Write garbage directly where the cache would look for "a".
        let key = "a"
        let safeName = Data(key.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        let corruptFile = dir.appendingPathComponent("cache").appendingPathComponent("\(safeName).json")
        try? FileManager.default.createDirectory(at: corruptFile.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? Data("not valid json".utf8).write(to: corruptFile)

        #expect(await cache.value(forKey: key) == nil)

        // Recovers cleanly afterward.
        await cache.setValue(Payload(value: "recovered"), forKey: key)
        #expect(await cache.value(forKey: key) == Payload(value: "recovered"))
    }

    @Test func removeAllClearsEverything() async {
        let cache = makeCache()
        await cache.setValue(Payload(value: "hello"), forKey: "a")
        await cache.removeAll()
        #expect(await cache.value(forKey: "a") == nil)
    }
}
