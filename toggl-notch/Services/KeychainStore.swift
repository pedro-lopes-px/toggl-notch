import Foundation
import Security

nonisolated enum KeychainStore {
    private static let legacyAccount = "com.yourcompany.togglnotch.apitoken"
    private static let account = "api-token"
    private static let defaultsKey = "togglApiToken"

    private static var service: String {
        Bundle.main.bundleIdentifier ?? "pedro-lopes-px.toggl-notch"
    }

    /// Ad-hoc / unsigned builds lack a team identifier, so Security.framework
    /// signature checks log DetachedSignatures noise and keychain writes fail anyway.
    private static let usesKeychain: Bool = {
        guard let url = Bundle.main.url(forResource: "embedded", withExtension: "provisionprofile"),
              let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any],
              let teams = plist["TeamIdentifier"] as? [String],
              teams.contains(where: { !$0.isEmpty })
        else { return false }
        return true
    }()

    static func readToken() -> String? {
        if let stored = UserDefaults.standard.string(forKey: defaultsKey), !stored.isEmpty {
            return stored
        }
        guard usesKeychain else { return nil }
        return readKeychainItem(account: account, service: service)
            ?? readKeychainItem(account: legacyAccount, service: nil)
    }

    /// Persists the token. Keychain is preferred for signed builds; UserDefaults is
    /// used for ad-hoc local development where keychain access is unavailable.
    static func saveToken(_ token: String) {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard usesKeychain else {
            UserDefaults.standard.set(trimmed, forKey: defaultsKey)
            return
        }

        deleteAllKeychainItems()
        UserDefaults.standard.set(trimmed, forKey: defaultsKey)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(trimmed.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]

        if SecItemAdd(query as CFDictionary, nil) == errSecSuccess {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
    }

    static func deleteToken() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        guard usesKeychain else { return }
        deleteAllKeychainItems()
    }

    private static func readKeychainItem(account: String, service: String?) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        if let service {
            query[kSecAttrService as String] = service
        }

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteAllKeychainItems() {
        for service in [service, nil] as [String?] {
            for account in [account, legacyAccount] {
                var query: [String: Any] = [
                    kSecClass as String: kSecClassGenericPassword,
                    kSecAttrAccount as String: account,
                ]
                if let service {
                    query[kSecAttrService as String] = service
                }
                SecItemDelete(query as CFDictionary)
            }
        }
    }
}
