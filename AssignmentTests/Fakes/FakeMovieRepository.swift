import Foundation
@testable import Assignment

/// Test double for `MovieRepository`. Configurable to return fixed results
/// or throw a fixed error, so use-case and ViewModel tests never need a
/// live network call.
final class FakeMovieRepository: MovieRepository {
    var searchResult: Result<[Movie], Error> = .success([])
    var detailResult: Result<MovieDetail, Error> = .failure(FakeError.unconfigured)
    private(set) var searchQueriesReceived: [String] = []
    private(set) var detailSlugsReceived: [String] = []

    /// Per-query override with an artificial delay, keyed by the exact
    /// query string - lets a test simulate "the first request is slower
    /// than the second" races without a real network.
    var delayedSearchResultsByQuery: [String: (result: Result<[Movie], Error>, delayNanoseconds: UInt64)] = [:]

    enum FakeError: Error {
        case unconfigured
    }

    func searchMovies(query: String) async throws -> [Movie] {
        searchQueriesReceived.append(query)

        if let override = delayedSearchResultsByQuery[query] {
            try await Task.sleep(nanoseconds: override.delayNanoseconds)
            return try override.result.get()
        }

        return try searchResult.get()
    }

    func movieDetail(slug: String) async throws -> MovieDetail {
        detailSlugsReceived.append(slug)
        return try detailResult.get()
    }
}
