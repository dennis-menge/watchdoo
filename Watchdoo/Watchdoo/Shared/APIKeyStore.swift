import Foundation
import Security

/// Device-local Keychain storage shared by the iOS and watchOS source targets.
/// Each app keeps its own key; WatchConnectivity still transfers configuration.
enum APIKeyStore {
    struct StorageError: LocalizedError {
        let status: OSStatus
        var errorDescription: String? {
            "API-Schlüssel konnte nicht sicher gespeichert oder gelesen werden (\(status))."
        }
    }

    nonisolated static func load(service: String = "Watchdoo.APIKey") throws -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "backend",
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw StorageError(status: status) }
        guard let data = result as? Data, let value = String(data: data, encoding: .utf8) else {
            throw StorageError(status: errSecDecode)
        }
        return value
    }

    nonisolated static func save(_ value: String, service: String = "Watchdoo.APIKey") throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: "backend",
        ]
        if value.isEmpty {
            let status = SecItemDelete(query as CFDictionary)
            guard status == errSecSuccess || status == errSecItemNotFound else {
                throw StorageError(status: status)
            }
            return
        }
        let attributes: [String: Any] = [
            kSecValueData as String: Data(value.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            status = SecItemAdd(query.merging(attributes) { _, new in new } as CFDictionary, nil)
        }
        guard status == errSecSuccess else { throw StorageError(status: status) }
    }

    /// Remove plaintext only after Keychain storage has succeeded.
    nonisolated static func migrate(defaults: UserDefaults = .standard,
                                    service: String = "Watchdoo.APIKey") throws -> String? {
        if let stored = try load(service: service) {
            defaults.removeObject(forKey: "apiKey")
            return stored
        }
        guard let legacy = defaults.string(forKey: "apiKey") else { return nil }
        try save(legacy, service: service)
        defaults.removeObject(forKey: "apiKey")
        return legacy.isEmpty ? nil : legacy
    }
}
