import Foundation
import Security

struct KeychainStore {
    private let service: String
    private let account = "personal-api-key"
    init(service: String = "app.veloxnutrition.openai") { self.service = service }
    private var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword, kSecAttrService as String: service,
         kSecAttrAccount as String: account, kSecAttrSynchronizable as String: false]
    }
    func read() throws -> String? {
        var request = query
        request[kSecReturnData as String] = true
        request[kSecMatchLimit as String] = kSecMatchLimitOne
        var result: CFTypeRef?
        let status = SecItemCopyMatching(request as CFDictionary, &result)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = result as? Data, let key = String(data: data, encoding: .utf8) else { throw StoreError.keychain }
        return key
    }
    func save(_ key: String) throws {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: { $0.isWhitespace }) else { throw APIError.invalidKey }
        let attributes: [String: Any] = [kSecValueData as String: Data(trimmed.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly]
        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            var item = query
            attributes.forEach { item[$0.key] = $0.value }
            guard SecItemAdd(item as CFDictionary, nil) == errSecSuccess else { throw StoreError.keychain }
        } else if status != errSecSuccess { throw StoreError.keychain }
    }
    func remove() throws {
        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else { throw StoreError.keychain }
    }
}

enum StoreError: LocalizedError {
    case keychain, photo, invalidMeal, save
    var errorDescription: String? {
        switch self {
        case .keychain: return "Der Schlüsselbund ist nicht verfügbar. Entsperre das iPhone und versuche es erneut."
        case .photo: return "Das Foto konnte nicht verarbeitet oder gespeichert werden. Bitte wähle es erneut."
        case .invalidMeal: return "Bitte trage einen Namen und gültige, nicht negative Nährwerte ein."
        case .save: return "Die Daten konnten nicht gespeichert werden. Bitte prüfe den freien Speicherplatz."
        }
    }
}
