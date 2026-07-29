import SwiftUI
import Combine

@MainActor
final class AppCoordinator: ObservableObject {
    enum Root {
        case auth
        case movies
    }

    @Published private(set) var root: Root
    let authManager: AuthManager
    let authCoordinator: AuthenticationCoordinator
    let moviesCoordinator: MoviesCoordinator

    /// Dependencies are always supplied by `AppDependencyContainer` - no
    /// default parameter here, so nothing can silently fall back to
    /// `AuthManager.shared`.
    init(authManager: AuthManager) {
        self.authManager = authManager
        self.root = authManager.isAuthenticated() ? .movies : .auth
        self.authCoordinator = AuthenticationCoordinator(authManager: authManager)
        self.moviesCoordinator = MoviesCoordinator(authManager: authManager)

        authCoordinator.onAuthenticated = { [weak self] in
            self?.showMovies()
        }
        moviesCoordinator.onLogout = { [weak self] in
            self?.showAuth()
        }
    }

    func start() {
        root = authManager.isAuthenticated() ? .movies : .auth
    }

    func showMovies() {
        root = .movies
    }

    func showAuth() {
        root = .auth
    }

    @ViewBuilder
    func makeRootView() -> some View {
        switch root {
        case .auth:
            authCoordinator.makeView()
        case .movies:
            moviesCoordinator.makeView()
        }
    }
}
