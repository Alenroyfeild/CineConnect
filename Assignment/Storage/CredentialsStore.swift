import Foundation

/// The single owner of where authentication credentials live and how
/// they're read back as request headers. Replaces the plaintext
/// `UserDefaults` storage `AuthManager` used before Phase 5.
///
/// Returns an immutable, `Sendable` snapshot (`Credentials`) rather than
/// exposing the Keychain directly - callers (like `AuthManager`) never see
/// a mutable reference to stored secrets, only values they already asked
/// for.
actor CredentialsStore {
    private let keychain: SecureKeyValueStoring
    private let userTokenKey = "x-hs-usertoken"
    private let platformKey = "x-hs-platform"
    private let cookieKey = "cookie"

    struct Credentials: Sendable {
        let userToken: String
        let platform: String
        let cookie: String
    }

    /// Depends on `SecureKeyValueStoring`, not the concrete `KeychainStore`
    /// - see that protocol's doc comment for exactly why this seam exists.
    /// No default value: constructing a `KeychainStore()` from inside
    /// another actor's own initializer runs into the same actor-isolation
    /// restrictions default-argument expressions do elsewhere in this
    /// project (see `AppDependencyContainer.init`'s comment) - simplest fix
    /// here is requiring the caller to pass one explicitly. `AuthManager.init`
    /// (which runs on `@MainActor`, not inside another actor's init) is the
    /// one production call site that supplies the real `KeychainStore()`.
    init(keychain: SecureKeyValueStoring) {
        self.keychain = keychain
    }

    func save(userToken: String, platform: String, cookie: String) async {
        await keychain.set(Data(userToken.utf8), forKey: userTokenKey)
        await keychain.set(Data(platform.utf8), forKey: platformKey)
        await keychain.set(Data(cookie.utf8), forKey: cookieKey)
    }

    func currentCredentials() async -> Credentials? {
        guard
            let tokenData = await keychain.data(forKey: userTokenKey),
            let cookieData = await keychain.data(forKey: cookieKey),
            let userToken = String(data: tokenData, encoding: .utf8),
            let cookie = String(data: cookieData, encoding: .utf8)
        else {
            return nil
        }
        let platform = await keychain.data(forKey: platformKey).flatMap { String(data: $0, encoding: .utf8) } ?? "web"
        return Credentials(userToken: userToken, platform: platform, cookie: cookie)
    }

    func isAuthenticated() async -> Bool {
        await currentCredentials() != nil
    }

    /// Never logs the values themselves or any prefix of them - see
    /// docs/Learning/Architecture/Phase-05-Authentication.md for why the
    /// pre-Phase-5 code that did this was a real problem, not a style nit.
    func headers() async -> [String: String] {
        guard let credentials = await currentCredentials() else { return [:] }
        return [
            "x-hs-platform": credentials.platform,
            "x-hs-usertoken": credentials.userToken,
            "Cookie": credentials.cookie
        ]
    }

    func clear() async {
        await keychain.removeAll()
    }
}
