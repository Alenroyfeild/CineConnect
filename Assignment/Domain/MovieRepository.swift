import Foundation

/// The movies feature's data-access boundary. Use cases depend on this
/// protocol, never on `MovieSearchAPIService`/`MovieDetailAPIService`
/// directly - that's what lets tests substitute a fake without touching
/// any production networking code.
///
/// No `CachePolicy` parameter yet: today's implementation only has a
/// single fallback-on-failure cache policy (inherited from the pre-Phase-3
/// `MovieCache`), so a policy parameter would be a placeholder with no
/// second behavior to select between. That parameter belongs with Phase 6's
/// actual multi-policy cache, not here.
protocol MovieRepository {
    func searchMovies(query: String) async throws -> [Movie]
    func movieDetail(slug: String) async throws -> MovieDetail
}
