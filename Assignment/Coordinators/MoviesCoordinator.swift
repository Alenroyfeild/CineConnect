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

    /// Concrete API services are constructed here rather than in the Views
    /// or the ViewModels' own convenience initializers - the repository/DI
    /// layer that will replace `MovieSearchAPIService`/`MovieDetailAPIService`
    /// with an injected `MovieRepository` is Phase 3/4 scope, not this one.
    private func makeSearchViewModel() -> MovieSearchViewModel {
        MovieSearchViewModel(apiService: MovieSearchAPIService())
    }

    private func makeDetailViewModel() -> MovieDetailViewModel {
        MovieDetailViewModel(apiService: MovieDetailAPIService())
    }
}
