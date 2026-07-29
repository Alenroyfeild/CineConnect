//
//  AuthManager.swift
//  Assignment
//
//  Created by Balaji Royal on 10/01/26.
//

import Foundation
import Combine

/// The single, `@MainActor`-isolated source of truth for "is the user
/// logged in" that SwiftUI observes. Storage itself lives in
/// `CredentialsStore` (Keychain-backed, Phase 5) - this type no longer
/// touches `UserDefaults` or persists anything on its own.
///
/// Conforms to `AuthHeaderProviding` (Phase 4) so `AuthenticationInterceptor`
/// depends on that protocol, not `AuthManager` - or `.shared` - directly.
@MainActor
class AuthManager: ObservableObject, AuthHeaderProviding {
    static let shared = AuthManager()

    @Published private(set) var isLoggedIn: Bool = false

    private let credentialsStore: CredentialsStore
    private let webDataClearingService: WebDataClearingService

    // Both dependencies resolved via nil-coalescing in the body, not
    // default-argument expressions, for the same actor-isolation reason
    // documented on `AppDependencyContainer.init`.
    init(credentialsStore: CredentialsStore? = nil, webDataClearingService: WebDataClearingService? = nil) {
        self.credentialsStore = credentialsStore ?? CredentialsStore(keychain: KeychainStore())
        self.webDataClearingService = webDataClearingService ?? WebDataClearingService()
    }

    /// Reads the real (Keychain-backed) authentication state and updates
    /// `isLoggedIn` accordingly. Called once at app launch by
    /// `AppCoordinator.start()` - synchronous callers (like `AppCoordinator.init`)
    /// use `isLoggedIn`'s last-known value instead of blocking on this.
    func refreshAuthenticationState() async {
        isLoggedIn = await credentialsStore.isAuthenticated()
    }

    func saveCredentials(userToken: String, platform: String, cookie: String) async {
        await credentialsStore.save(userToken: userToken, platform: platform, cookie: cookie)
        isLoggedIn = true
    }

    func getHeaders() async -> [String: String] {
        await credentialsStore.headers()
    }

    func logout() async {
        await credentialsStore.clear()
        await webDataClearingService.clearAllWebData()
        isLoggedIn = false
    }
}
