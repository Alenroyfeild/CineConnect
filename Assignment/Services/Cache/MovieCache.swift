import Foundation

/// Small, optional disk cache for the last successful movie responses.
/// Network remains the source of truth; cached values are only used after a failed request.
final class MovieCache {
    static let shared = MovieCache()

    private let directory: URL
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let fileManager = FileManager.default

    init(directory: URL? = nil) {
        self.directory = directory ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CineConnectMovieCache", isDirectory: true)
        try? fileManager.createDirectory(at: self.directory, withIntermediateDirectories: true)
    }

    func saveSearch(_ movies: [Movie], query: String) {
        save(movies, name: "search-\(key(query))")
    }

    func loadSearch(query: String) -> [Movie]? {
        load([Movie].self, name: "search-\(key(query))")
    }

    func saveDetail(_ detail: MovieDetail, slug: String) {
        save(detail, name: "detail-\(key(slug))")
    }

    func loadDetail(slug: String) -> MovieDetail? {
        load(MovieDetail.self, name: "detail-\(key(slug))")
    }

    private func save<Value: Encodable>(_ value: Value, name: String) {
        guard let data = try? encoder.encode(value) else { return }
        try? data.write(to: directory.appendingPathComponent("\(name).json"), options: .atomic)
    }

    private func load<Value: Decodable>(_ type: Value.Type, name: String) -> Value? {
        let url = directory.appendingPathComponent("\(name).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(type, from: data)
    }

    private func key(_ value: String) -> String {
        Data(value.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
    }
}
