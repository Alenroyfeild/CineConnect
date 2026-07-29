import Foundation
import Testing
@testable import Assignment

/// Verifies `CredentialsStore`'s own logic against `InMemoryKeyValueStore`,
/// not the real Keychain (see that fake's doc comment for why). This is a
/// deliberate, documented test-boundary choice, not a gap: everything
/// `CredentialsStore` itself decides (what counts as "authenticated," how
/// headers are assembled, what clearing removes) is covered here;
/// `KeychainStore`'s actual Keychain calls are not, and need manual
/// verification on a properly signed build.
@Suite
struct CredentialsStoreTests {
    @Test func startsUnauthenticatedWithNoSavedCredentials() async {
        let store = CredentialsStore(keychain: InMemoryKeyValueStore())
        #expect(await store.isAuthenticated() == false)
        #expect(await store.currentCredentials() == nil)
    }

    @Test func savingCredentialsMakesItAuthenticated() async {
        let store = CredentialsStore(keychain: InMemoryKeyValueStore())

        await store.save(userToken: "token-123", platform: "web", cookie: "cookie-abc")

        #expect(await store.isAuthenticated() == true)
        let credentials = await store.currentCredentials()
        #expect(credentials?.userToken == "token-123")
        #expect(credentials?.platform == "web")
        #expect(credentials?.cookie == "cookie-abc")
    }

    @Test func headersReflectSavedCredentials() async {
        let store = CredentialsStore(keychain: InMemoryKeyValueStore())
        await store.save(userToken: "token-123", platform: "web", cookie: "cookie-abc")

        let headers = await store.headers()

        #expect(headers["x-hs-usertoken"] == "token-123")
        #expect(headers["x-hs-platform"] == "web")
        #expect(headers["Cookie"] == "cookie-abc")
    }

    @Test func headersAreEmptyWhenNotAuthenticated() async {
        let store = CredentialsStore(keychain: InMemoryKeyValueStore())
        #expect(await store.headers().isEmpty)
    }

    @Test func clearRemovesCredentialsAndDeauthenticates() async {
        let store = CredentialsStore(keychain: InMemoryKeyValueStore())
        await store.save(userToken: "token-123", platform: "web", cookie: "cookie-abc")

        await store.clear()

        #expect(await store.isAuthenticated() == false)
        #expect(await store.currentCredentials() == nil)
    }
}
