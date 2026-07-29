import Foundation

/// Composition root. Owns the app's shared, long-lived instances and hands
/// them to coordinators explicitly - nothing downstream reaches for a
/// `.shared` singleton itself.
///
/// Scope note: `AuthManager` is still the pre-refactor singleton type here.
/// This phase only removes the *implicit* `.shared` access at the
/// coordinator layer; `AuthManager` itself is split into a `CredentialsStore`
/// actor + authentication repository in a later phase (see
/// docs/ARCHITECTURE_REFACTOR_PLAN.md, Phase 5). `AuthenticationInterceptor`
/// and `LoginViewController` still read `AuthManager.shared` directly until
/// that phase gives them an injectable seam.
@MainActor
final class AppDependencyContainer {
    let authManager: AuthManager

    init(authManager: AuthManager? = nil) {
        // `AuthManager.shared` is main-actor isolated; resolving it in the
        // init body (rather than as a default-argument expression) avoids
        // an actor-isolation warning on the default value itself.
        self.authManager = authManager ?? AuthManager.shared
    }

    func makeAppCoordinator() -> AppCoordinator {
        AppCoordinator(authManager: authManager)
    }
}
