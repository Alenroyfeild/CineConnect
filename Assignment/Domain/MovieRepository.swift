import Foundation

/// The movies feature's data-access boundary. Use cases depend on this
/// protocol, never on `MovieSearchAPIService`/`MovieDetailAPIService`
/// directly - that's what lets tests substitute a fake without touching
/// any production networking or caching code.
///
/// `policy` defaults to `.networkFirst` at both call sites so existing
/// use cases (`SearchMoviesUseCase`, `GetMovieDetailUseCase`) don't need
/// to change - a manual "pull to refresh" control (Phase 9) is what will
/// eventually pass `.reloadIgnoringCache` explicitly.
///
/// Search results are cached memory-only; movie details are cached in
/// memory *and* on disk. Why the difference: search results are cheap to
/// re-fetch and change often (new results for a slightly different
/// query), so persisting them across app launches has little value.
/// A movie's detail page is comparatively stable and more expensive to
/// lose - worth surviving a memory warning or app relaunch.
protocol MovieRepository {
    func searchMovies(query: String, policy: CachePolicy) async throws -> [Movie]
    func movieDetail(slug: String, policy: CachePolicy) async throws -> MovieDetail

    /// Clears every cache layer this repository owns. Called on logout -
    /// see `MoviesCoordinator.performLogout()` - so a second account
    /// signing in on the same device never sees the first account's
    /// cached search/detail data.
    func clearCaches() async
}

extension MovieRepository {
    func searchMovies(query: String) async throws -> [Movie] {
        try await searchMovies(query: query, policy: .networkFirst)
    }

    func movieDetail(slug: String) async throws -> MovieDetail {
        try await movieDetail(slug: slug, policy: .networkFirst)
    }
}
