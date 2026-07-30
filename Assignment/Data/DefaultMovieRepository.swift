import Foundation

/// Coordinates the remote data source with the cache stack:
///
/// ```
/// L0 in-flight coalescing -> L1 memory cache -> (detail only) L2 disk cache -> remote
/// ```
///
/// This used to coordinate a single flat disk cache (`MovieCache`,
/// Phase 3); Phase 6 replaces it with real actor-isolated layers, TTLs,
/// and policy-driven behavior. Search results are memory-only; movie
/// details use memory and disk - see `MovieRepository`'s doc comment for
/// why.
final class DefaultMovieRepository: MovieRepository {
    private let searchAPIService: MovieSearchAPIServiceProtocol
    private let detailAPIService: MovieDetailAPIServiceProtocol

    private let searchMemoryCache: MemoryCache<String, [Movie]>
    private let detailMemoryCache: MemoryCache<String, MovieDetail>
    private let detailDiskCache: DiskCache<MovieDetail>

    private let searchInFlight = InFlightRequestStore<String, [Movie]>()
    private let detailInFlight = InFlightRequestStore<String, MovieDetail>()

    init(
        searchAPIService: MovieSearchAPIServiceProtocol,
        detailAPIService: MovieDetailAPIServiceProtocol,
        searchMemoryCache: MemoryCache<String, [Movie]> = MemoryCache(maxEntries: 30, ttl: 120),
        detailMemoryCache: MemoryCache<String, MovieDetail> = MemoryCache(maxEntries: 50, ttl: 900),
        detailDiskCache: DiskCache<MovieDetail> = DiskCache(directoryName: "CineConnectMovieDetailCache", ttl: 86_400)
    ) {
        self.searchAPIService = searchAPIService
        self.detailAPIService = detailAPIService
        self.searchMemoryCache = searchMemoryCache
        self.detailMemoryCache = detailMemoryCache
        self.detailDiskCache = detailDiskCache
    }

    func searchMovies(query: String, policy: CachePolicy) async throws -> [Movie] {
        switch policy {
        case .cacheFirst:
            if let cached = await searchMemoryCache.value(forKey: query) {
                return cached
            }
            return try await fetchAndCacheSearch(query: query)

        case .reloadIgnoringCache:
            return try await fetchAndCacheSearch(query: query)

        case .networkFirst:
            do {
                return try await fetchAndCacheSearch(query: query)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if let stale = await searchMemoryCache.staleValue(forKey: query) {
                    return stale
                }
                throw error
            }
        }
    }

    func movieDetail(slug: String, policy: CachePolicy) async throws -> MovieDetail {
        switch policy {
        case .cacheFirst:
            if let cached = await detailMemoryCache.value(forKey: slug) {
                return cached
            }
            if let cached = await detailDiskCache.value(forKey: slug) {
                await detailMemoryCache.setValue(cached, forKey: slug)
                return cached
            }
            return try await fetchAndCacheDetail(slug: slug)

        case .reloadIgnoringCache:
            return try await fetchAndCacheDetail(slug: slug)

        case .networkFirst:
            do {
                return try await fetchAndCacheDetail(slug: slug)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                if let stale = await detailMemoryCache.staleValue(forKey: slug) {
                    return stale
                }
                if let stale = await detailDiskCache.value(forKey: slug) {
                    return stale
                }
                throw error
            }
        }
    }

    func clearCaches() async {
        await searchMemoryCache.removeAll()
        await detailMemoryCache.removeAll()
        await detailDiskCache.removeAll()
    }

    private func fetchAndCacheSearch(query: String) async throws -> [Movie] {
        try await searchInFlight.value(forKey: query) { [searchAPIService, searchMemoryCache] in
            let movies = try await searchAPIService.searchVideos(query: query)
            await searchMemoryCache.setValue(movies, forKey: query)
            return movies
        }
    }

    private func fetchAndCacheDetail(slug: String) async throws -> MovieDetail {
        try await detailInFlight.value(forKey: slug) { [detailAPIService, detailMemoryCache, detailDiskCache] in
            let detail = try await detailAPIService.fetchMovieDetail(slug: slug)
            await detailMemoryCache.setValue(detail, forKey: slug)
            await detailDiskCache.setValue(detail, forKey: slug)
            return detail
        }
    }
}
