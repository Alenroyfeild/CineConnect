import Foundation

/// Composition root. Owns the app's shared, long-lived instances and hands
/// them to coordinators explicitly - nothing downstream reaches for a
/// `.shared` singleton itself.
///
/// Scope note: `AuthManager` is still a singleton type (`AuthManager.shared`
/// exists, and this container defaults to it) - but as of Phase 5, this is
/// the *only* place that reference appears in production code.
/// `AuthenticationInterceptor` depends on `AuthHeaderProviding` (Phase 4),
/// and `LoginViewController` now takes an injected `AuthManager` (Phase 5) -
/// neither reaches for `.shared` themselves anymore. What Phase 5 didn't
/// change: `AuthManager` is still a class wrapping storage rather than a
/// fully protocol-backed abstraction a test could substitute wholesale
/// (its *storage*, `CredentialsStore`, is already swappable - see
/// `AuthManagerTests.swift` for real isolated tests using that seam).
@MainActor
final class AppDependencyContainer {
    let authManager: AuthManager
    let remoteService: RemoteService
    /// Set on the SwiftUI environment at the root (`AssignmentApp`), not
    /// threaded through coordinators - see `CachedAsyncImage.swift`'s doc
    /// comment for why images specifically use environment injection.
    let imageLoader: ImageLoader

    init(authManager: AuthManager? = nil, remoteService: RemoteService? = nil, imageLoader: ImageLoader? = nil) {
        // `AuthManager.shared` is main-actor isolated; resolving it in the
        // init body (rather than as a default-argument expression) avoids
        // an actor-isolation warning on the default value itself.
        let resolvedAuthManager = authManager ?? AuthManager.shared
        self.authManager = resolvedAuthManager
        self.remoteService = remoteService ?? RemoteService(
            preInterceptors: [AuthenticationInterceptor(headerProvider: resolvedAuthManager)]
        )
        self.imageLoader = imageLoader ?? ImageLoader()
    }

    func makeAppCoordinator() -> AppCoordinator {
        AppCoordinator(authManager: authManager, remoteService: remoteService)
    }
}
