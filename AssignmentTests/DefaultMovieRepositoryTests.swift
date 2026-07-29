import Foundation
import Testing
@testable import Assignment

/// Verifies `DefaultMovieRepository`'s actual job: forward to the remote
/// data source on success, fall back to cache on failure, and never treat
/// cancellation as "network failed, use the cache" (see
/// docs/Learning/Architecture/Phase-03-Domain-and-Repository.md for why
/// that distinction matters).
@MainActor
@Suite
struct DefaultMovieRepositoryTests {
    private func makeCache() -> MovieCache {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("DefaultMovieRepositoryTests-\(UUID().uuidString)")
        return MovieCache(directory: dir)
    }

    @Test func searchForwardsResultsFromRemoteOnSuccess() async throws {
        let searchAPI = FakeMovieSearchAPIService()
        let expected = [Movie(id: "1", title: "T", subtitle: "S", pageSlug: "/x", posterURL: nil)]
        searchAPI.result = .success(expected)
        let repository = DefaultMovieRepository(
            searchAPIService: searchAPI,
            detailAPIService: FakeMovieDetailAPIService(),
            cache: makeCache()
        )

        let result = try await repository.searchMovies(query: "batman")

        #expect(result == expected)
    }

    @Test func searchFallsBackToCacheWhenRemoteFails() async throws {
        let searchAPI = FakeMovieSearchAPIService()
        let cache = makeCache()
        let cached = [Movie(id: "1", title: "Cached", subtitle: "S", pageSlug: "/x", posterURL: nil)]
        cache.saveSearch(cached, query: "batman")
        searchAPI.result = .failure(FakeMovieSearchAPIService.FakeAPIError.networkFailure)
        let repository = DefaultMovieRepository(
            searchAPIService: searchAPI,
            detailAPIService: FakeMovieDetailAPIService(),
            cache: cache
        )

        let result = try await repository.searchMovies(query: "batman")

        #expect(result == cached)
    }

    @Test func searchThrowsWhenRemoteFailsAndNoCacheExists() async {
        let searchAPI = FakeMovieSearchAPIService()
        searchAPI.result = .failure(FakeMovieSearchAPIService.FakeAPIError.networkFailure)
        let repository = DefaultMovieRepository(
            searchAPIService: searchAPI,
            detailAPIService: FakeMovieDetailAPIService(),
            cache: makeCache()
        )

        await #expect(throws: FakeMovieSearchAPIService.FakeAPIError.self) {
            _ = try await repository.searchMovies(query: "no-cache-for-this-query")
        }
    }

    @Test func searchPropagatesCancellationWithoutFallingBackToCache() async throws {
        let searchAPI = FakeMovieSearchAPIService()
        let cache = makeCache()
        cache.saveSearch([Movie(id: "1", title: "Cached", subtitle: "S", pageSlug: "/x", posterURL: nil)], query: "batman")
        searchAPI.result = .failure(CancellationError())
        let repository = DefaultMovieRepository(
            searchAPIService: searchAPI,
            detailAPIService: FakeMovieDetailAPIService(),
            cache: cache
        )

        await #expect(throws: CancellationError.self) {
            _ = try await repository.searchMovies(query: "batman")
        }
    }

    @Test func detailForwardsResultFromRemoteOnSuccess() async throws {
        let detailAPI = FakeMovieDetailAPIService()
        let expected = MovieDetail(title: "T", subtitle: nil, description: nil, posterURL: nil, rating: nil, duration: nil)
        detailAPI.result = .success(expected)
        let repository = DefaultMovieRepository(
            searchAPIService: FakeMovieSearchAPIService(),
            detailAPIService: detailAPI,
            cache: makeCache()
        )

        let result = try await repository.movieDetail(slug: "/in/movies/x/1")

        #expect(result.title == expected.title)
    }
}
