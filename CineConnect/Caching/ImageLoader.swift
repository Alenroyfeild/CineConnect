import UIKit

enum ImageLoadingError: Error {
    case invalidResponse
    case invalidData
}

/// Fetches and decodes images, backed by the same generic cache actors
/// Phase 6 built for movie data (`MemoryCache`, `InFlightRequestStore`) -
/// no separate image-specific caching primitives were built, since these
/// already do exactly what's needed.
///
/// Decoding (`UIImage(data:)`) happens inside this actor's own isolation
/// domain, not `@MainActor` - `ImageLoader` isn't annotated `@MainActor`
/// and actors are self-isolating regardless of the project's default
/// isolation setting, so this is "decoding away from the main actor" for
/// free, not something requiring extra `Task.detached` ceremony.
actor ImageLoader {
    private let urlSession: URLSession
    private let memoryCache: MemoryCache<URL, UIImage>
    private let inFlight = InFlightRequestStore<URL, UIImage>()

    init(urlSession: URLSession = .shared, memoryCache: MemoryCache<URL, UIImage> = MemoryCache(maxEntries: 100, ttl: 600)) {
        self.urlSession = urlSession
        self.memoryCache = memoryCache
    }

    func image(for url: URL) async throws -> UIImage {
        if let cached = await memoryCache.value(forKey: url) {
            return cached
        }

        return try await inFlight.value(forKey: url) { [urlSession, memoryCache] in
            let (data, response) = try await urlSession.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
                throw ImageLoadingError.invalidResponse
            }
            guard let image = UIImage(data: data) else {
                throw ImageLoadingError.invalidData
            }
            await memoryCache.setValue(image, forKey: url)
            return image
        }
    }
}
