import Foundation
#if canImport(Security)
import Security
#endif

/// Version-proof preference storage. Marketing version bumps must never
/// change the key or wipe favorites / reviewer identity.
///
/// Read order: Keychain → App Group → standard, then any legacy / versioned
/// keys. An empty App Group array does not hide a populated standard or
/// Keychain value (the usual TestFlight migration trap).
public enum DurableStore {
    public static let favoritesKey = SharedDefaults.favoritesKey
    public static let campusFavoritesKey = SharedDefaults.campusFavoritePlaceIDsKey
    public static let reviewerIDKey = "zoteats.reviewerID"

    private static let keychainService = "com.atharvgupta.zoteats.durable"

    /// Known historical names — never include a marketing version.
    public static let favoriteLegacyKeys = [
        "zoteats.favorites",
        "favoriteDishNames",
        "favorites",
        "zoteats.favoriteDishes",
    ]

    public static func loadStringArray(key: String, legacyKeys: [String] = []) -> [String] {
        SharedDefaults.suite.synchronize()
        UserDefaults.standard.synchronize()
        var buckets: [[String]] = []
        if let stored = keychainStringArray(account: key), !stored.isEmpty {
            buckets.append(stored)
        }
        for candidate in keysToRead(primary: key, legacyKeys: legacyKeys) {
            if let stored = nonEmptyArray(in: SharedDefaults.suite, key: candidate) {
                buckets.append(stored)
            }
            if SharedDefaults.suite !== UserDefaults.standard,
               let stored = nonEmptyArray(in: .standard, key: candidate) {
                buckets.append(stored)
            }
        }
        return uniqued(buckets.flatMap { $0 })
    }

    public static func saveStringArray(_ values: [String], key: String) {
        let payload = uniqued(values)
        SharedDefaults.suite.set(payload, forKey: key)
        UserDefaults.standard.set(payload, forKey: key)
        SharedDefaults.suite.synchronize()
        UserDefaults.standard.synchronize()
        setKeychainStringArray(payload, account: key)
    }

    public static func loadString(key: String) -> String? {
        if let stored = keychainString(account: key), !stored.isEmpty {
            return stored
        }
        if let stored = SharedDefaults.suite.string(forKey: key), !stored.isEmpty {
            return stored
        }
        if let stored = UserDefaults.standard.string(forKey: key), !stored.isEmpty {
            return stored
        }
        return nil
    }

    public static func saveString(_ value: String, key: String) {
        SharedDefaults.suite.set(value, forKey: key)
        UserDefaults.standard.set(value, forKey: key)
        setKeychainString(value, account: key)
    }

    /// Stable anonymous reviewer id — created once, never version-scoped.
    public static func reviewerID() -> String {
        if let existing = loadString(key: reviewerIDKey), !existing.isEmpty {
            return existing
        }
        let created = UUID().uuidString
        saveString(created, key: reviewerIDKey)
        return created
    }

    /// True when `key` looks version-scoped (`zoteats.favoriteDishNames.1.0.323`).
    public static func isVersionScopedKey(_ key: String, prefix: String) -> Bool {
        guard key.hasPrefix(prefix) else { return false }
        let rest = String(key.dropFirst(prefix.count))
        guard rest.first == "." || rest.first == "-" else { return false }
        return rest.range(of: #"^\.?\d"#, options: .regularExpression) != nil
            || rest.range(of: #"^-\d"#, options: .regularExpression) != nil
    }

    // MARK: - Private

    private static func keysToRead(primary: String, legacyKeys: [String]) -> [String] {
        var keys = [primary]
        keys.append(contentsOf: legacyKeys)
        keys.append(contentsOf: versionedKeys(matching: primary, in: SharedDefaults.suite))
        keys.append(contentsOf: versionedKeys(matching: primary, in: .standard))
        return uniqued(keys)
    }

    private static func versionedKeys(matching prefix: String, in defaults: UserDefaults) -> [String] {
        defaults.dictionaryRepresentation().keys.filter { isVersionScopedKey($0, prefix: prefix) }.sorted()
    }

    private static func nonEmptyArray(in defaults: UserDefaults, key: String) -> [String]? {
        guard defaults.object(forKey: key) != nil else { return nil }
        let values = defaults.stringArray(forKey: key) ?? []
        return values.isEmpty ? nil : values
    }

    private static func uniqued(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed.lowercased()).inserted else { continue }
            result.append(trimmed)
        }
        return result
    }

    // MARK: - Keychain (Apple platforms). Linux tests use UserDefaults only.

    private static func keychainStringArray(account: String) -> [String]? {
        guard let data = keychainData(account: account) else { return nil }
        return (try? JSONDecoder().decode([String].self, from: data))
    }

    private static func setKeychainStringArray(_ values: [String], account: String) {
        guard let data = try? JSONEncoder().encode(values) else { return }
        setKeychainData(data, account: account)
    }

    private static func keychainString(account: String) -> String? {
        guard let data = keychainData(account: account) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func setKeychainString(_ value: String, account: String) {
        guard let data = value.data(using: .utf8) else { return }
        setKeychainData(data, account: account)
    }

    private static func keychainData(account: String) -> Data? {
        #if canImport(Security)
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return data
        #else
        return nil
        #endif
    }

    private static func setKeychainData(_ data: Data, account: String) {
        #if canImport(Security)
        let base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(base as CFDictionary)
        var add = base
        add[kSecValueData as String] = data
        add[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        SecItemAdd(add as CFDictionary, nil)
        #endif
    }
}
