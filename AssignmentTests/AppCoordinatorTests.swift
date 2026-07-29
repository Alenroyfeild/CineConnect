import Testing
@testable import Assignment

/// Coordinator tests for Phase 1 (composition root).
///
/// As of Phase 5, these construct a fresh, isolated `AuthManager` per test
/// (injected with an in-memory `CredentialsStore`) instead of driving the
/// real `AuthManager.shared` singleton - genuinely isolated unit tests now,
/// not integration tests against shared process-wide state. No
/// `.serialized` trait needed for that reason either: nothing here shares
/// mutable state across tests anymore.
@MainActor
@Suite
struct AppCoordinatorTests {
    /// A plain `RemoteService` with no interceptors is enough here - none
    /// of these tests exercise networking, only `AppCoordinator`'s routing.
    private func makeCoordinator(authManager: AuthManager? = nil) -> AppCoordinator {
        let manager = authManager ?? AuthManager(credentialsStore: CredentialsStore(keychain: InMemoryKeyValueStore()))
        return AppCoordinator(authManager: manager, remoteService: RemoteService())
    }

    @Test func startsAtAuthRootWhenNotAuthenticated() async {
        let coordinator = makeCoordinator()
        await coordinator.start()

        #expect(coordinator.root == .auth)
    }

    @Test func startsAtMoviesRootWhenAuthenticated() async {
        let authManager = AuthManager(credentialsStore: CredentialsStore(keychain: InMemoryKeyValueStore()))
        await authManager.saveCredentials(userToken: "test-token", platform: "web", cookie: "test-cookie")
        let coordinator = makeCoordinator(authManager: authManager)

        await coordinator.start()

        #expect(coordinator.root == .movies)
    }

    @Test func showMoviesAndShowAuthUpdateRoot() async {
        let coordinator = makeCoordinator()

        coordinator.showMovies()
        #expect(coordinator.root == .movies)

        coordinator.showAuth()
        #expect(coordinator.root == .auth)
    }

    @Test func authCoordinatorCompletionBubblesToAppCoordinator() async {
        let coordinator = makeCoordinator()

        coordinator.authCoordinator.onAuthenticated?()

        #expect(coordinator.root == .movies)
    }

    @Test func moviesCoordinatorLogoutBubblesToAppCoordinator() async {
        let authManager = AuthManager(credentialsStore: CredentialsStore(keychain: InMemoryKeyValueStore()))
        await authManager.saveCredentials(userToken: "test-token", platform: "web", cookie: "test-cookie")
        let coordinator = makeCoordinator(authManager: authManager)

        coordinator.moviesCoordinator.onLogout?()

        #expect(coordinator.root == .auth)
    }

    @Test func dependencyContainerWiresACoordinator() async {
        let container = AppDependencyContainer()
        let coordinator = container.makeAppCoordinator()
        await coordinator.start()
        #expect(coordinator.root == .auth || coordinator.root == .movies)
    }
}
