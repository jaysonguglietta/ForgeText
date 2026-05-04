import CryptoKit
import Foundation
import Security

enum SensitiveDataStore {
    private static let service = "com.jaysonguglietta.ForgeText.sensitive-data"
    private static let account = "default"

    private struct Envelope: Codable {
        let version: Int
        let combined: Data
    }

    static func load<Value: Codable>(_ type: Value.Type, from fileURL: URL, defaultsKey: String? = nil) -> Value? {
        if let data = try? Data(contentsOf: fileURL) {
            if let value: Value = decryptedValue(type, from: data) {
                return value
            }

            if let legacyValue = try? JSONDecoder().decode(type, from: data) {
                save(legacyValue, to: fileURL, defaultsKey: defaultsKey)
                return legacyValue
            }
        }

        guard let defaultsKey,
              let data = UserDefaults.standard.data(forKey: defaultsKey)
        else {
            return nil
        }

        if let value: Value = decryptedValue(type, from: data) {
            return value
        }

        guard let legacyValue = try? JSONDecoder().decode(type, from: data) else {
            return nil
        }

        save(legacyValue, to: fileURL, defaultsKey: defaultsKey)
        return legacyValue
    }

    static func save<Value: Encodable>(_ value: Value, to fileURL: URL, defaultsKey: String? = nil) {
        guard let key = encryptionKey(),
              let plaintext = try? JSONEncoder().encode(value),
              let sealedData = try? encrypt(plaintext, using: key)
        else {
            return
        }

        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? sealedData.write(to: fileURL, options: .atomic)

        if let defaultsKey {
            UserDefaults.standard.removeObject(forKey: defaultsKey)
        }
    }

    private static func decryptedValue<Value: Decodable>(_ type: Value.Type, from data: Data) -> Value? {
        guard let key = encryptionKey(),
              let plaintext = try? decrypt(data, using: key)
        else {
            return nil
        }

        return try? JSONDecoder().decode(type, from: plaintext)
    }

    private static func encrypt(_ plaintext: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(plaintext, using: key)
        guard let combined = sealedBox.combined else {
            throw EncryptionError.missingCombinedData
        }

        return try JSONEncoder().encode(Envelope(version: 1, combined: combined))
    }

    private static func decrypt(_ ciphertext: Data, using key: SymmetricKey) throws -> Data {
        let envelope = try JSONDecoder().decode(Envelope.self, from: ciphertext)
        let sealedBox = try AES.GCM.SealedBox(combined: envelope.combined)
        return try AES.GCM.open(sealedBox, using: key)
    }

    private static func encryptionKey() -> SymmetricKey? {
        if let keyData = keyDataFromKeychain() {
            return SymmetricKey(data: keyData)
        }

        var keyData = Data(count: 32)
        let status = keyData.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, bytes.count, bytes.baseAddress!)
        }
        guard status == errSecSuccess, storeKeyDataInKeychain(keyData) else {
            return nil
        }

        return SymmetricKey(data: keyData)
    }

    private static func keyDataFromKeychain() -> Data? {
        var query = baseQuery()
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            return nil
        }

        return result as? Data
    }

    private static func storeKeyDataInKeychain(_ keyData: Data) -> Bool {
        let query = baseQuery()
        let update = [kSecValueData as String: keyData]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)

        if updateStatus == errSecSuccess {
            return true
        }

        guard updateStatus == errSecItemNotFound else {
            return false
        }

        var addQuery = query
        addQuery[kSecValueData as String] = keyData
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    private static func baseQuery() -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]
    }

    private enum EncryptionError: Error {
        case missingCombinedData
    }
}
