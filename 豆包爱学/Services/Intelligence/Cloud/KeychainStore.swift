//
//  KeychainStore.swift
//  豆包爱学 — Services/Intelligence/Cloud
//
//  Minimal Keychain wrapper for storing per-provider API keys. Secrets belong in
//  the Keychain, not @AppStorage/UserDefaults — this keeps the keys out of the
//  app's plist and encrypted at rest, and it works in the macOS App Sandbox.
//
//  Pure value type → `nonisolated`. SecItem APIs are thread-safe.
//

import Foundation
import Security

nonisolated struct KeychainStore: Sendable {
    /// Service namespace for all豆包爱学 secrets.
    private let service: String

    init(service: String = "com.doubaoaixue.ai") {
        self.service = service
    }

    /// Store (or overwrite) a secret for `account`. Empty string clears it.
    @discardableResult
    func set(_ value: String, account: String) -> Bool {
        guard !value.isEmpty else { return remove(account: account) }
        guard let data = value.data(using: .utf8) else { return false }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        // Try update first; insert if absent.
        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecSuccess { return true }
        if updateStatus == errSecItemNotFound {
            var insert = query
            insert[kSecValueData as String] = data
            insert[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
            return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
        }
        return false
    }

    /// Read the secret for `account`, or `nil` if none.
    func get(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else { return nil }
        return value
    }

    /// Delete the secret for `account`. Returns true if removed or already absent.
    @discardableResult
    func remove(account: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }
}
