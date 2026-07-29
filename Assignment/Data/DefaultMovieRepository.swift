import Foundation

/// Coordinates the remote data source and the fallback cache: network is
/// the source of truth, and the last successful response is only used if
/// the network call itself fails. This policy used to be duplicated inside
/// both `MovieSearchAPIService` and `MovieDetailAPIService`; it now lives
/// here, once, as the repository's actual job.
final class DefaultMovieRepository: MovieRepository {
    private let searchAPIService: MovieSearchAPIServiceProtocol
    private let detailAPIService: MovieDetailAPIServiceProtocol
    private let cache: MovieCache

    init(
        searchAPIService: MovieSearchAPIServiceProtocol,
        detailAPIService: MovieDetailAPIServiceProtocol,
        cache: MovieCache = .shared
    ) {
        self.searchAPIService = searchAPIService
        self.detailAPIService = detailAPIService
        self.cache = cache
    }

    func searchMovies(query: String) async throws -> [Movie] {
        do {
            let movies = try await searchAPIService.searchVideos(query: query)
            cache.saveSearch(movies, query: query)
            return movies
        } catch is CancellationError {
            // A cancelled request isn't a "failure" the cache should paper
            // over - propagate it so the caller's own cancellation handling
            // (e.g. MovieSearchViewModel's `catch is CancellationError`)
            // still runs, instead of silently substituting stale data.
            throw CancellationError()
        } catch {
            if let cached = cache.loadSearch(query: query) {
                return cached
            }
            throw error
        }
    }

    func movieDetail(slug: String) async throws -> MovieDetail {
        do {
            let detail = try await detailAPIService.fetchMovieDetail(slug: slug)
            cache.saveDetail(detail, slug: slug)
            return detail
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if let cached = cache.loadDetail(slug: slug) {
                return cached
            }
            throw error
        }
    }
}
