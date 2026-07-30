import Foundation

/// A deliberately thin pass-through to `MovieRepository.movieDetail(slug:)`.
///
/// This is the honest counter-example to "use cases always add value":
/// there's no application-level policy for fetching a single detail beyond
/// "ask the repository." It still exists, rather than having
/// `MovieDetailViewModel` depend on `MovieRepository` directly, so every
/// ViewModel talks to a use case consistently - the day this one needs
/// real behavior (e.g. "prefetch related titles"), it already has a home.
struct GetMovieDetailUseCase {
    private let repository: MovieRepository

    init(repository: MovieRepository) {
        self.repository = repository
    }

    func callAsFunction(slug: String) async throws -> MovieDetail {
        try await repository.movieDetail(slug: slug)
    }
}
