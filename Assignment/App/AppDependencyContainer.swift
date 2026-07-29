import Foundation

/// Composition root. Owns the app's shared, long-lived instances and hands
/// them to coordinators explicitly - nothing downstream reaches for a
/// `.shared` singleton itself.
///
/// Scope note: `AuthManager` is still the pre-refactor singleton type here.
/// This phase only removes the *implicit* `.shared` access at the
/// coordinator layer; `AuthManager` itself is split into a `CredentialsStore`
/// actor + authentication repository in a later phase (see
/// docs/ARCHITECTURE_REFACTOR_PLAN.md, Phase 5). `LoginViewController`
/// still reads `AuthManager.shared` directly until that phase gives it an
/// injectable seam - `AuthenticationInterceptor` no longer does, as of
/// Phase 4 (it depends on `AuthHeaderProviding`, built here).
@MainActor
final class AppDependencyContainer {
    let authManager: AuthManager
    let remoteService: RemoteService

    init(authManager: AuthManager? = nil, remoteService: RemoteService? = nil) {
        // `AuthManager.shared` is main-actor isolated; resolving it in the
        // init body (rather than as a default-argument expression) avoids
        // an actor-isolation warning on the default value itself.
        let resolvedAuthManager = authManager ?? AuthManager.shared
        self.authManager = resolvedAuthManager
        self.remoteService = remoteService ?? RemoteService(
            preInterceptors: [AuthenticationInterceptor(headerProvider: resolvedAuthManager)]
        )
    }

    func makeAppCoordinator() -> AppCoordinator {
        AppCoordinator(authManager: authManager, remoteService: remoteService)
    }
}
