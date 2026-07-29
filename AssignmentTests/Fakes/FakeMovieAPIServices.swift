import Foundation
@testable import Assignment

/// Test doubles for the remote data source protocols
/// `DefaultMovieRepository` depends on - used to verify the repository's
/// own cache-fallback and cancellation-propagation policy without a live
/// network call.
final class FakeMovieSearchAPIService: MovieSearchAPIServiceProtocol {
    var result: Result<[Movie], Error> = .success([])

    func searchVideos(query: String) async throws -> [Movie] {
        try result.get()
    }
}

final class FakeMovieDetailAPIService: MovieDetailAPIServiceProtocol {
    var result: Result<MovieDetail, Error> = .failure(FakeMovieSearchAPIService.FakeAPIError.unconfigured)

    func fetchMovieDetail(slug: String) async throws -> MovieDetail {
        try result.get()
    }
}

extension FakeMovieSearchAPIService {
    enum FakeAPIError: Error {
        case unconfigured
        case networkFailure
    }
}
