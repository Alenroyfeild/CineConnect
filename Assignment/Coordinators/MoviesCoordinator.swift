import SwiftUI
import Combine

@MainActor
final class MoviesCoordinator: Coordinator {
    let authManager: AuthManager
    private let remoteService: RemoteService
    var onLogout: (() -> Void)?

    /// Owns the movies feature's navigation state explicitly (rather than
    /// leaving it implicit inside `NavigationStack`), so a future deep link
    /// or "pop to root" action has something to drive programmatically.
    @Published var path = NavigationPath()

    /// No default parameters - always supplied by `AppCoordinator`, never
    /// `AuthManager.shared`/a standalone `RemoteService` directly.
    init(authManager: AuthManager, remoteService: RemoteService) {
        self.authManager = authManager
        self.remoteService = remoteService
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
    /// source chain, using the single `RemoteService` instance the
    /// composition root built (with its `AuthenticationInterceptor` already
    /// wired) - no code here defaults to a standalone `RemoteService`.
    private func makeSearchViewModel() -> MovieSearchViewModel {
        MovieSearchViewModel(searchMovies: SearchMoviesUseCase(repository: makeMovieRepository()))
    }

    private func makeDetailViewModel() -> MovieDetailViewModel {
        MovieDetailViewModel(getMovieDetail: GetMovieDetailUseCase(repository: makeMovieRepository()))
    }

    private func makeMovieRepository() -> MovieRepository {
        DefaultMovieRepository(
            searchAPIService: MovieSearchAPIService(remoteService: remoteService),
            detailAPIService: MovieDetailAPIService(remoteService: remoteService)
        )
    }
}
