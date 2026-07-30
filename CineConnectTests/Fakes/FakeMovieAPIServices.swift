import Foundation
@testable import CineConnect

/// Test doubles for the remote data source protocols
/// `DefaultMovieRepository` depends on - used to verify the repository's
/// own cache-fallback and cancellation-propagation policy without a live
/// network call.
/// `@unchecked Sendable` justification: same as `FakeMovieDetailAPIService`
/// below - `result` is configured once before concurrent use begins.
final class FakeMovieSearchAPIService: MovieSearchAPIServiceProtocol, @unchecked Sendable {
    var result: Result<[Movie], Error> = .success([])

    func searchVideos(query: String) async throws -> [Movie] {
        try result.get()
    }
}

/// `@unchecked Sendable` justification: `result`/`onFetch` are configured
/// once by the test before any concurrent access begins (never mutated
/// *during* concurrent calls) - safe in practice for this test-only fake,
/// even though the compiler can't verify it structurally.
final class FakeMovieDetailAPIService: MovieDetailAPIServiceProtocol, @unchecked Sendable {
    var result: Result<MovieDetail, Error> = .failure(FakeMovieSearchAPIService.FakeAPIError.unconfigured)
    /// Optional hook for tests that need to count/delay calls (e.g.
    /// request-coalescing tests) rather than just return a fixed result.
    var onFetch: (@Sendable () async -> Result<MovieDetail, Error>)?

    func fetchMovieDetail(slug: String) async throws -> MovieDetail {
        if let onFetch {
            return try await onFetch().get()
        }
        return try result.get()
    }
}

extension FakeMovieSearchAPIService {
    enum FakeAPIError: Error {
        case unconfigured
        case networkFailure
    }
}
