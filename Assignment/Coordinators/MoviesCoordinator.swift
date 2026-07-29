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

    /// No default parameter - always supplied by `AppCoordinator`, never
    /// `AuthManager.shared` directly.
    init(authManager: AuthManager) {
        self.authManager = authManager
    }

    func makeView() -> some View {
        NavigationStack(path: Binding(get: { self.path }, set: { self.path = $0 })) {
            MoviesListView(
                viewModel: makeSearchViewModel(),
                onLogout: { [weak self] in
                    self?.onLogout?()
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

    /// Builds the full ViewModel -> use case -> repository -> remote data
    /// source chain. `MovieSearchAPIService`/`MovieDetailAPIService` are
    /// still the only concrete `MovieRepository` backing today - a real,
    /// swappable networking layer (Phase 4) changes what's inside
    /// `DefaultMovieRepository`, not this factory's shape.
    private func makeSearchViewModel() -> MovieSearchViewModel {
        MovieSearchViewModel(searchMovies: SearchMoviesUseCase(repository: makeMovieRepository()))
    }

    private func makeDetailViewModel() -> MovieDetailViewModel {
        MovieDetailViewModel(getMovieDetail: GetMovieDetailUseCase(repository: makeMovieRepository()))
    }

    private func makeMovieRepository() -> MovieRepository {
        DefaultMovieRepository(
            searchAPIService: MovieSearchAPIService(),
            detailAPIService: MovieDetailAPIService()
        )
    }
}
