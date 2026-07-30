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
    /// default parameters here, so nothing can silently fall back to
    /// `AuthManager.shared`/a standalone `RemoteService`.
    ///
    /// `root` starts at `.auth` (the safe default) rather than
    /// synchronously querying authentication state - as of Phase 5, that
    /// state lives behind the Keychain-backed `CredentialsStore`, which is
    /// only readable asynchronously. `start()` corrects `root` from the
    /// real state once it's known.
    init(authManager: AuthManager, remoteService: RemoteService) {
        self.authManager = authManager
        self.root = .auth
        self.authCoordinator = AuthenticationCoordinator(authManager: authManager)
        self.moviesCoordinator = MoviesCoordinator(authManager: authManager, remoteService: remoteService)

        authCoordinator.onAuthenticated = { [weak self] in
            self?.showMovies()
        }
        moviesCoordinator.onLogout = { [weak self] in
            self?.showAuth()
        }
    }

    /// Reads real authentication state and corrects `root` accordingly.
    /// Called once at launch via `.task` (not `.onAppear`, since this is
    /// async - see `CineConnectApp.swift`).
    func start() async {
        await authManager.refreshAuthenticationState()
        root = authManager.isLoggedIn ? .movies : .auth
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
