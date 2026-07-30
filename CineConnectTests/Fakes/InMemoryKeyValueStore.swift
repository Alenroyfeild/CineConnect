import Foundation
@testable import CineConnect

/// Test double for `SecureKeyValueStoring` - lets `CredentialsStoreTests`
/// verify `CredentialsStore`'s own logic without touching the real
/// Keychain, which `errSecMissingEntitlement` (-34018) makes unreachable
/// from this test-host environment (unsigned build, no code-signing
/// identity available - see `KeychainStore.swift`'s doc comment).
actor InMemoryKeyValueStore: SecureKeyValueStoring {
    private var storage: [String: Data] = [:]

    func set(_ data: Data, forKey key: String) {
        storage[key] = data
    }

    func data(forKey key: String) -> Data? {
        storage[key]
    }

    func removeAll() {
        storage.removeAll()
    }
}
