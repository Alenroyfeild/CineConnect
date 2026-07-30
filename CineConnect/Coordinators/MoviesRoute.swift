import Foundation

/// Typed navigation destinations owned by `MoviesCoordinator`.
///
/// Carries the whole `Movie`, not just an id/slug: `MovieDetailView` renders
/// a poster immediately from `movie.posterURL` while the real detail call is
/// in flight, and the search row already has the full model in hand, so
/// there's no lookup step to decouple from. A slug-only route becomes worth
/// it once deep linking needs to construct a route without an in-memory
/// `Movie` - tracked in docs/ARCHITECTURE_REFACTOR_PLAN.md, not needed yet.
enum MoviesRoute: Hashable {
    case detail(Movie)
}
