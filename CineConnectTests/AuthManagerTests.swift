import Foundation
import Testing
@testable import CineConnect

/// Unlike `AppCoordinatorTests` (which must use the real `AuthManager.shared`
/// singleton), these construct a fresh `AuthManager` with an injected,
/// in-memory `CredentialsStore` - a genuinely isolated unit test, made
/// possible by Phase 5's constructor injection. `WebDataClearingService`
/// is not faked (no fake exists for it yet); its real WebKit calls run
/// against empty data and complete quickly.
@MainActor
@Suite
struct AuthManagerTests {
    private func makeAuthManager() -> AuthManager {
        AuthManager(credentialsStore: CredentialsStore(keychain: InMemoryKeyValueStore()))
    }

    @Test func startsLoggedOut() {
        let authManager = makeAuthManager()
        #expect(authManager.isLoggedIn == false)
    }

    @Test func saveCredentialsSetsIsLoggedIn() async {
        let authManager = makeAuthManager()

        await authManager.saveCredentials(userToken: "t", platform: "web", cookie: "c")

        #expect(authManager.isLoggedIn == true)
    }

    @Test func getHeadersReflectsSavedCredentials() async {
        let authManager = makeAuthManager()
        await authManager.saveCredentials(userToken: "t", platform: "web", cookie: "c")

        let headers = await authManager.getHeaders()

        #expect(headers["x-hs-usertoken"] == "t")
    }

    @Test func refreshAuthenticationStateReadsFromStore() async {
        let credentialsStore = CredentialsStore(keychain: InMemoryKeyValueStore())
        await credentialsStore.save(userToken: "t", platform: "web", cookie: "c")
        let authManager = AuthManager(credentialsStore: credentialsStore)

        // Constructing AuthManager doesn't itself read the store - it
        // starts at `isLoggedIn = false` until something asks it to check.
        #expect(authManager.isLoggedIn == false)

        await authManager.refreshAuthenticationState()

        #expect(authManager.isLoggedIn == true)
    }

    @Test func logoutClearsCredentialsAndIsLoggedIn() async {
        let authManager = makeAuthManager()
        await authManager.saveCredentials(userToken: "t", platform: "web", cookie: "c")

        await authManager.logout()

        #expect(authManager.isLoggedIn == false)
        #expect(await authManager.getHeaders().isEmpty)
    }
}
