import Foundation

/// Generic, TTL-based disk cache for a single `Codable` value type. Used
/// today only for movie detail (`DiskCache<MovieDetail>`) - search results
/// are deliberately memory-only (see `MovieRepository`'s doc comment on
/// why the two use different cache layers).
///
/// Why an actor: file I/O here is genuinely async-appropriate work (disk
/// access, however fast on modern hardware, shouldn't block whoever calls
/// in), and multiple concurrent detail requests could read/write the same
/// key's file at once without one.
actor DiskCache<Value: Codable & Sendable> {
    private struct Envelope: Codable {
        let value: Value
        let expiresAt: Date
    }

    private let directory: URL
    private let ttl: TimeInterval
    private let now: @Sendable () -> Date
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    /// `nonisolated(unsafe)`: `FileManager` itself isn't `Sendable` in the
    /// SDK's annotations, but `FileManager.default` is documented by Apple
    /// as safe to use concurrently from multiple threads - this is exactly
    /// the documented, narrow case `nonisolated(unsafe)` exists for, not a
    /// blanket escape hatch. Needed so `init` (see below) can read it
    /// before `self` is fully isolated.
    private nonisolated(unsafe) let fileManager = FileManager.default

    init(
        directoryName: String,
        ttl: TimeInterval,
        now: @escaping @Sendable () -> Date = { Date() },
        baseDirectory: URL? = nil
    ) {
        self.ttl = ttl
        self.now = now
        let root = baseDirectory ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        self.directory = root.appendingPathComponent(directoryName, isDirectory: true)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    func value(forKey key: String) -> Value? {
        guard let data = try? Data(contentsOf: fileURL(for: key)) else { return nil }
        // A corrupt or unreadable file is treated as a cache miss, not an
        // error - callers already have a "no cached value" path (go to
        // network), so there's no need for a separate corruption-handling
        // path. The corrupt file is removed so it doesn't keep failing to
        // decode on every future lookup.
        guard let envelope = try? decoder.decode(Envelope.self, from: data) else {
            try? fileManager.removeItem(at: fileURL(for: key))
            return nil
        }
        guard envelope.expiresAt > now() else {
            try? fileManager.removeItem(at: fileURL(for: key))
            return nil
        }
        return envelope.value
    }

    func setValue(_ value: Value, forKey key: String) {
        let envelope = Envelope(value: value, expiresAt: now().addingTimeInterval(ttl))
        guard let data = try? encoder.encode(envelope) else { return }
        try? data.write(to: fileURL(for: key), options: .atomic)
    }

    func removeValue(forKey key: String) {
        try? fileManager.removeItem(at: fileURL(for: key))
    }

    func removeAll() {
        try? fileManager.removeItem(at: directory)
        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    private func fileURL(for key: String) -> URL {
        let safeName = Data(key.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return directory.appendingPathComponent("\(safeName).json")
    }
}
