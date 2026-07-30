import SwiftUI
import Combine

@MainActor
final class MoviesCoordinator: Coordinator {
    let authManager: AuthManager
    var onLogout: (() -> Void)?

    /// Owns the movies feature's navigation state explicitly (rather than
    /// leaving it implicit inside `NavigationStack`), so a future deep link
    /// or "pop to root" action has something to drive programmatically.
    @Published var path = NavigationPath()

    /// One repository instance for this coordinator's lifetime, not
    /// rebuilt per screen. This matters as of Phase 6: `DefaultMovieRepository`
    /// now owns real cache state (`MemoryCache`/`DiskCache` actors) - a
    /// fresh instance per `makeDetailViewModel()` call would mean
    /// revisiting the same movie's detail screen never hits its own cache,
    /// defeating the point of caching. `AppCoordinator` owns this
    /// coordinator for the whole app session, so this repository (and its
    /// caches) survive across navigations - and across a logout/re-login
    /// cycle unless explicitly cleared, which is exactly why
    /// `performLogout()` calls `clearCaches()` below.
    private let movieRepository: MovieRepository

    /// No default parameters - always supplied by `AppCoordinator`, never
    /// `AuthManager.shared`/a standalone `RemoteService` directly.
    init(authManager: AuthManager, remoteService: RemoteService) {
        self.authManager = authManager
        self.movieRepository = DefaultMovieRepository(
            searchAPIService: MovieSearchAPIService(remoteService: remoteService),
            detailAPIService: MovieDetailAPIService(remoteService: remoteService)
        )
    }

    func makeView() -> some View {
        NavigationStack(path: Binding(get: { self.path }, set: { self.path = $0 })) {
            MoviesListView(
                viewModel: makeSearchViewModel(),
                onLogout: { [weak self] in
                    Task { await self?.performLogout() }
                }
            )
            .environmentObject(authManager)
            .navigationDestination(for: MoviesRoute.self) { [weak self] route in
                self?.destinationView(for: route)
            }
        }
    }

    @ViewBuilder
    private func destinationView(for route: MoviesRoute) -> some View {
        switch route {
        case .detail(let movie):
            MovieDetailView(movie: movie, viewModel: makeDetailViewModel())
        }
    }

    private func makeSearchViewModel() -> MovieSearchViewModel {
        MovieSearchViewModel(searchMovies: SearchMoviesUseCase(repository: movieRepository))
    }

    private func makeDetailViewModel() -> MovieDetailViewModel {
        MovieDetailViewModel(getMovieDetail: GetMovieDetailUseCase(repository: movieRepository))
    }

    /// Clears every cache this coordinator's repository owns before
    /// notifying `AppCoordinator` - so a second account signing in on this
    /// device never sees the first account's cached search/detail data.
    /// Credential clearing itself already happened in
    /// `MoviesListView.logout()` (`await authManager.logout()`) before
    /// this closure runs.
    private func performLogout() async {
        await movieRepository.clearCaches()
        onLogout?()
    }
}
