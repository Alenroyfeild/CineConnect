import Testing
@testable import Assignment

/// Coordinator tests for Phase 1 (composition root).
///
/// Honesty note: `AuthManager` is still the pre-refactor singleton type -
/// splitting it into an injectable, protocol-backed credentials store is
/// scoped to Phase 5 (see docs/ARCHITECTURE_REFACTOR_PLAN.md). Until then
/// there's no way to construct an isolated fake `AuthManager`, so these
/// exercise `AppCoordinator`'s routing logic against the real
/// `AuthManager.shared`, driving it through its own public API and
/// resetting state afterward. That makes these integration tests against a
/// process-wide singleton, not isolated unit tests - a real testability gap,
/// tracked rather than hidden.
/// `.serialized`: every test here mutates the shared `AuthManager.shared`
/// singleton (see the honesty note above) - running them concurrently would
/// make them race each other.
@Suite(.serialized)
@MainActor
struct AppCoordinatorTests {
    @Test func startsAtAuthRootWhenNotAuthenticated() {
        AuthManager.shared.logout()

        let coordinator = AppCoordinator(authManager: .shared)

        #expect(coordinator.root == .auth)
    }

    @Test func startsAtMoviesRootWhenAuthenticated() {
        AuthManager.shared.saveCredentials(userToken: "test-token", platform: "web", cookie: "test-cookie")
        defer { AuthManager.shared.logout() }

        let coordinator = AppCoordinator(authManager: .shared)

        #expect(coordinator.root == .movies)
    }

    @Test func showMoviesAndShowAuthUpdateRoot() {
        AuthManager.shared.logout()
        let coordinator = AppCoordinator(authManager: .shared)

        coordinator.showMovies()
        #expect(coordinator.root == .movies)

        coordinator.showAuth()
        #expect(coordinator.root == .auth)
    }

    @Test func authCoordinatorCompletionBubblesToAppCoordinator() {
        AuthManager.shared.logout()
        let coordinator = AppCoordinator(authManager: .shared)

        coordinator.authCoordinator.onAuthenticated?()

        #expect(coordinator.root == .movies)
    }

    @Test func moviesCoordinatorLogoutBubblesToAppCoordinator() {
        AuthManager.shared.saveCredentials(userToken: "test-token", platform: "web", cookie: "test-cookie")
        defer { AuthManager.shared.logout() }
        let coordinator = AppCoordinator(authManager: .shared)

        coordinator.moviesCoordinator.onLogout?()

        #expect(coordinator.root == .auth)
    }

    @Test func dependencyContainerWiresACoordinator() {
        let container = AppDependencyContainer()
        let coordinator = container.makeAppCoordinator()
        #expect(coordinator.root == .auth || coordinator.root == .movies)
    }
}
