import Foundation
import Security

/// What `CredentialsStore` needs from secure key/value storage - nothing
/// more. `KeychainStore` conforms for production; tests inject an
/// in-memory fake instead (see `InMemoryKeyValueStore` in the test target).
///
/// This exists because of a real, discovered environment constraint, not
/// speculatively: `SecItemAdd`/`SecItemUpdate` return `errSecMissingEntitlement`
/// (-34018) when called from an unsigned or ad-hoc-signed app - which is
/// exactly this project's `xcodebuild test` environment (no valid code
/// signing identity is available here). Without this protocol boundary,
/// `CredentialsStore`'s own logic (credential composition, the
/// authenticated/not-authenticated decision, header formatting) would be
/// completely untestable in this environment - not because the logic is
/// wrong, but because the real Keychain can't be reached at all here. See
/// docs/Learning/Architecture/Phase-05-Authentication.md for the full story.
protocol SecureKeyValueStoring: Sendable {
    func set(_ data: Data, forKey key: String) async
    func data(forKey key: String) async -> Data?
    func removeAll() async
}

/// Keychain-backed key/value storage for small `Data` blobs.
///
/// Why an actor: the Keychain Services C API is itself synchronous and
/// already thread-safe at the OS level - an actor isn't compensating for a
/// data race the way `MemoryCache` (Phase 6) will. Its value here is
/// presenting one async interface behind `SecureKeyValueStoring`.
///
/// Not covered by automated tests in this environment (see the protocol's
/// doc comment above) - verify manually on a properly signed build before
/// relying on it in production.
actor KeychainStore: SecureKeyValueStoring {
    private let service: String

    init(service: String = "com.alenroyfeild.CineConnect.credentials") {
        self.service = service
    }

    func set(_ data: Data, forKey key: String) {
        let query = baseQuery(forKey: key)
        if SecItemCopyMatching(query as CFDictionary, nil) == errSecSuccess {
            let update: [String: Any] = [kSecValueData as String: data]
            SecItemUpdate(query as CFDictionary, update as CFDictionary)
        } else {
            var addQuery = query
            addQuery[kSecValueData as String] = data
            addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    func data(forKey key: String) -> Data? {
        var query = baseQuery(forKey: key)
        query[kSecReturnData as String] = true
        query[kSecMatchLimit as String] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else { return nil }
        return result as? Data
    }

    /// Removes every value this store has ever saved, regardless of key -
    /// used on logout so no credential survives under any key name.
    func removeAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func baseQuery(forKey key: String) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
    }
}
