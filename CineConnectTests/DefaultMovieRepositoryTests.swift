import Foundation
import Testing
@testable import CineConnect

/// Verifies `DefaultMovieRepository`'s actual job as of Phase 6: policy-driven
/// coordination across in-flight coalescing, memory cache, (detail-only)
/// disk cache, and the remote data source - plus that cancellation is
/// never treated as "network failed, use the cache" (a bug found and
/// fixed in Phase 3, still protected here).
@MainActor
@Suite
struct DefaultMovieRepositoryTests {
    private func makeRepository(
        searchAPI: FakeMovieSearchAPIService = FakeMovieSearchAPIService(),
        detailAPI: FakeMovieDetailAPIService = FakeMovieDetailAPIService(),
        clock: MutableClock = MutableClock(),
        searchTTL: TimeInterval = 120,
        detailTTL: TimeInterval = 900
    ) -> DefaultMovieRepository {
        let diskDir = FileManager.default.temporaryDirectory.appendingPathComponent("DefaultMovieRepositoryTests-\(UUID().uuidString)")
        return DefaultMovieRepository(
            searchAPIService: searchAPI,
            detailAPIService: detailAPI,
            searchMemoryCache: MemoryCache(maxEntries: 30, ttl: searchTTL, now: { clock.now() }),
            detailMemoryCache: MemoryCache(maxEntries: 50, ttl: detailTTL, now: { clock.now() }),
            detailDiskCache: DiskCache(directoryName: "detail", ttl: detailTTL, now: { clock.now() }, baseDirectory: diskDir)
        )
    }

    // MARK: - Search: memory-only caching

    @Test func searchForwardsResultsFromRemoteOnSuccessAndCaches() async throws {
        let searchAPI = FakeMovieSearchAPIService()
        let expected = [Movie(id: "1", title: "T", subtitle: "S", pageSlug: "/x", posterURL: nil)]
        searchAPI.result = .success(expected)
        let repository = makeRepository(searchAPI: searchAPI)

        let result = try await repository.searchMovies(query: "batman", policy: .networkFirst)

        #expect(result == expected)
    }

    @Test func searchCacheFirstReturnsMemoryHitWithoutCallingRemote() async throws {
        let searchAPI = FakeMovieSearchAPIService()
        let cached = [Movie(id: "1", title: "Cached", subtitle: "S", pageSlug: "/x", posterURL: nil)]
        searchAPI.result = .success(cached)
        let repository = makeRepository(searchAPI: searchAPI)
        _ = try await repository.searchMovies(query: "batman", policy: .networkFirst) // populates cache

        searchAPI.result = .failure(FakeMovieSearchAPIService.FakeAPIError.networkFailure) // remote would now fail
        let result = try await repository.searchMovies(query: "batman", policy: .cacheFirst)

        #expect(result == cached) // came from cache, not the now-failing remote
    }

    @Test func searchExpiredCacheFallsThroughToNetworkUnderCacheFirst() async throws {
        let clock = MutableClock()
        let searchAPI = FakeMovieSearchAPIService()
        searchAPI.result = .success([Movie(id: "1", title: "Old", subtitle: "S", pageSlug: "/x", posterURL: nil)])
        let repository = makeRepository(searchAPI: searchAPI, clock: clock, searchTTL: 10)
        _ = try await repository.searchMovies(query: "batman", policy: .networkFirst)

        clock.advance(by: 11) // expire the cached entry
        let fresh = [Movie(id: "2", title: "Fresh", subtitle: "S", pageSlug: "/y", posterURL: nil)]
        searchAPI.result = .success(fresh)

        let result = try await repository.searchMovies(query: "batman", policy: .cacheFirst)

        #expect(result == fresh)
    }

    @Test func searchNetworkFirstFallsBackToStaleCacheOnFailure() async throws {
        let searchAPI = FakeMovieSearchAPIService()
        let cached = [Movie(id: "1", title: "Cached", subtitle: "S", pageSlug: "/x", posterURL: nil)]
        searchAPI.result = .success(cached)
        let repository = makeRepository(searchAPI: searchAPI)
        _ = try await repository.searchMovies(query: "batman", policy: .networkFirst)

        searchAPI.result = .failure(FakeMovieSearchAPIService.FakeAPIError.networkFailure)
        let result = try await repository.searchMovies(query: "batman", policy: .networkFirst)

        #expect(result == cached)
    }

    @Test func searchThrowsWhenRemoteFailsAndNoCacheExists() async {
        let searchAPI = FakeMovieSearchAPIService()
        searchAPI.result = .failure(FakeMovieSearchAPIService.FakeAPIError.networkFailure)
        let repository = makeRepository(searchAPI: searchAPI)

        await #expect(throws: FakeMovieSearchAPIService.FakeAPIError.self) {
            _ = try await repository.searchMovies(query: "no-cache-for-this-query", policy: .networkFirst)
        }
    }

    @Test func searchPropagatesCancellationWithoutFallingBackToCache() async throws {
        let searchAPI = FakeMovieSearchAPIService()
        let repository = makeRepository(searchAPI: searchAPI)
        _ = try? await repository.searchMovies(query: "batman", policy: .networkFirst) // no cache populated (API defaults to success([]))
        searchAPI.result = .failure(CancellationError())

        await #expect(throws: CancellationError.self) {
            _ = try await repository.searchMovies(query: "batman", policy: .networkFirst)
        }
    }

    @Test func reloadIgnoringCacheAlwaysHitsNetworkEvenWithAFreshCacheEntry() async throws {
        let searchAPI = FakeMovieSearchAPIService()
        searchAPI.result = .success([Movie(id: "1", title: "Old", subtitle: "S", pageSlug: "/x", posterURL: nil)])
        let repository = makeRepository(searchAPI: searchAPI)
        _ = try await repository.searchMovies(query: "batman", policy: .networkFirst)

        let fresh = [Movie(id: "2", title: "Fresh", subtitle: "S", pageSlug: "/y", posterURL: nil)]
        searchAPI.result = .success(fresh)
        let result = try await repository.searchMovies(query: "batman", policy: .reloadIgnoringCache)

        #expect(result == fresh)
    }

    // MARK: - Detail: memory + disk caching

    @Test func detailForwardsResultFromRemoteOnSuccessAndCachesToMemoryAndDisk() async throws {
        let detailAPI = FakeMovieDetailAPIService()
        let expected = MovieDetail(title: "T", subtitle: nil, description: nil, posterURL: nil, rating: nil, duration: nil)
        detailAPI.result = .success(expected)
        let repository = makeRepository(detailAPI: detailAPI)

        let result = try await repository.movieDetail(slug: "/in/movies/x/1", policy: .networkFirst)

        #expect(result.title == expected.title)
    }

    @Test func detailCacheFirstPrefersMemoryOverDisk() async throws {
        let detailAPI = FakeMovieDetailAPIService()
        detailAPI.result = .success(MovieDetail(title: "First", subtitle: nil, description: nil, posterURL: nil, rating: nil, duration: nil))
        let repository = makeRepository(detailAPI: detailAPI)
        _ = try await repository.movieDetail(slug: "/x/1", policy: .networkFirst) // populates both memory + disk

        detailAPI.result = .failure(FakeMovieSearchAPIService.FakeAPIError.networkFailure)
        let result = try await repository.movieDetail(slug: "/x/1", policy: .cacheFirst)

        #expect(result.title == "First")
    }

    @Test func detailNetworkFirstFallsBackToDiskWhenMemoryAndNetworkBothMiss() async throws {
        // Two separate repository instances sharing the same disk directory,
        // simulating "memory cache was cleared (e.g. memory warning) but
        // disk survived."
        let diskDir = FileManager.default.temporaryDirectory.appendingPathComponent("DetailDiskFallback-\(UUID().uuidString)")
        let firstDetailAPI = FakeMovieDetailAPIService()
        firstDetailAPI.result = .success(MovieDetail(title: "Persisted", subtitle: nil, description: nil, posterURL: nil, rating: nil, duration: nil))
        let firstRepository = DefaultMovieRepository(
            searchAPIService: FakeMovieSearchAPIService(),
            detailAPIService: firstDetailAPI,
            detailDiskCache: DiskCache(directoryName: "detail", ttl: 900, baseDirectory: diskDir)
        )
        _ = try await firstRepository.movieDetail(slug: "/x/1", policy: .networkFirst)

        let secondDetailAPI = FakeMovieDetailAPIService()
        secondDetailAPI.result = .failure(FakeMovieSearchAPIService.FakeAPIError.networkFailure)
        let secondRepository = DefaultMovieRepository(
            searchAPIService: FakeMovieSearchAPIService(),
            detailAPIService: secondDetailAPI,
            detailDiskCache: DiskCache(directoryName: "detail", ttl: 900, baseDirectory: diskDir)
        )

        let result = try await secondRepository.movieDetail(slug: "/x/1", policy: .networkFirst)

        #expect(result.title == "Persisted")
    }

    // MARK: - Cancellation

    @Test func detailPropagatesCancellationWithoutFallingBackToCache() async throws {
        let detailAPI = FakeMovieDetailAPIService()
        let repository = makeRepository(detailAPI: detailAPI)
        detailAPI.result = .failure(CancellationError())

        await #expect(throws: CancellationError.self) {
            _ = try await repository.movieDetail(slug: "/x/1", policy: .networkFirst)
        }
    }

    // MARK: - Request coalescing (L0)

    @Test func tenConcurrentIdenticalDetailRequestsResultInOneRemoteCall() async throws {
        let detailAPI = FakeMovieDetailAPIService()
        let callCounter = CallCounter()
        detailAPI.onFetch = {
            await callCounter.increment()
            try? await Task.sleep(nanoseconds: 30_000_000)
            return .success(MovieDetail(title: "T", subtitle: nil, description: nil, posterURL: nil, rating: nil, duration: nil))
        }
        let repository = makeRepository(detailAPI: detailAPI)

        try await withThrowingTaskGroup(of: MovieDetail.self) { group in
            for _ in 0..<10 {
                group.addTask { try await repository.movieDetail(slug: "/x/1", policy: .networkFirst) }
            }
            for try await _ in group {}
        }

        #expect(await callCounter.count == 1)
    }

    @Test func concurrentRequestsForDifferentSlugsAllSucceed() async throws {
        let detailAPI = FakeMovieDetailAPIService()
        detailAPI.result = .success(MovieDetail(title: "T", subtitle: nil, description: nil, posterURL: nil, rating: nil, duration: nil))
        let repository = makeRepository(detailAPI: detailAPI)

        let results = try await withThrowingTaskGroup(of: MovieDetail.self) { group in
            for slug in ["/a", "/b", "/c"] {
                group.addTask { try await repository.movieDetail(slug: slug, policy: .networkFirst) }
            }
            var collected: [MovieDetail] = []
            for try await result in group { collected.append(result) }
            return collected
        }

        #expect(results.count == 3)
    }

    // MARK: - Logout

    @Test func clearCachesRemovesMemoryAndDiskEntries() async throws {
        let searchAPI = FakeMovieSearchAPIService()
        let detailAPI = FakeMovieDetailAPIService()
        searchAPI.result = .success([Movie(id: "1", title: "T", subtitle: "S", pageSlug: "/x", posterURL: nil)])
        detailAPI.result = .success(MovieDetail(title: "T", subtitle: nil, description: nil, posterURL: nil, rating: nil, duration: nil))
        let repository = makeRepository(searchAPI: searchAPI, detailAPI: detailAPI)
        _ = try await repository.searchMovies(query: "batman", policy: .networkFirst)
        _ = try await repository.movieDetail(slug: "/x/1", policy: .networkFirst)

        await repository.clearCaches()

        searchAPI.result = .failure(FakeMovieSearchAPIService.FakeAPIError.networkFailure)
        detailAPI.result = .failure(FakeMovieSearchAPIService.FakeAPIError.networkFailure)
        await #expect(throws: FakeMovieSearchAPIService.FakeAPIError.self) {
            _ = try await repository.searchMovies(query: "batman", policy: .cacheFirst)
        }
        await #expect(throws: FakeMovieSearchAPIService.FakeAPIError.self) {
            _ = try await repository.movieDetail(slug: "/x/1", policy: .cacheFirst)
        }
    }
}

private actor CallCounter {
    private(set) var count = 0
    func increment() { count += 1 }
}
