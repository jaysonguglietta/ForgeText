import CryptoKit
import Darwin
import Foundation
import Security

enum SensitiveDataStore {
    private static let service = "com.jaysonguglietta.ForgeText.sensitive-data"
    private static let account = "default"
    private static let keyCacheLock = NSLock()
    private static let maximumStoreBytes = 64 * 1_024 * 1_024
    nonisolated(unsafe) private static var cachedKeyData: Data?
    private static let ephemeralTestKeyData: Data = {
        var data = Data(count: 32)
        _ = data.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, bytes.count, bytes.baseAddress!)
        }
        return data
    }()

    private struct Envelope: Codable {
        let version: Int
        let combined: Data
    }

    static func load<Value: Codable>(_ type: Value.Type, from fileURL: URL, defaultsKey: String? = nil) -> Value? {
        if let data = securelyReadData(from: fileURL) {
            if let value: Value = decryptedValue(type, from: data) {
                return value
            }

            if canMigrateLegacyFile(at: fileURL),
               let legacyValue = try? ForgeTextJSONDecoder.make(trustLevel: .trustedLocalStore).decode(type, from: data) {
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

        guard let legacyValue = try? ForgeTextJSONDecoder.make(trustLevel: .trustedLocalStore).decode(type, from: data) else {
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
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)

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

        return try? ForgeTextJSONDecoder.make(trustLevel: .trustedLocalStore).decode(type, from: plaintext)
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
        guard envelope.version == 1 else {
            throw EncryptionError.unsupportedVersion
        }
        let sealedBox = try AES.GCM.SealedBox(combined: envelope.combined)
        return try AES.GCM.open(sealedBox, using: key)
    }

    private static func encryptionKey() -> SymmetricKey? {
        if ForgeTextRuntime.isRunningUnitTests {
            return SymmetricKey(data: ephemeralTestKeyData)
        }

        keyCacheLock.lock()
        if let cachedKeyData {
            keyCacheLock.unlock()
            return SymmetricKey(data: cachedKeyData)
        }
        keyCacheLock.unlock()

        if let keyData = keyDataFromKeychain() {
            keyCacheLock.lock()
            cachedKeyData = keyData
            keyCacheLock.unlock()
            return SymmetricKey(data: keyData)
        }

        var keyData = Data(count: 32)
        let status = keyData.withUnsafeMutableBytes { bytes in
            SecRandomCopyBytes(kSecRandomDefault, bytes.count, bytes.baseAddress!)
        }
        guard status == errSecSuccess, storeKeyDataInKeychain(keyData) else {
            return nil
        }

        keyCacheLock.lock()
        cachedKeyData = keyData
        keyCacheLock.unlock()
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
        addQuery[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
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
        case unsupportedVersion
    }

    private static func securelyReadData(from fileURL: URL) -> Data? {
        guard let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              values.isRegularFile == true,
              values.isSymbolicLink != true,
              (values.fileSize ?? 0) <= maximumStoreBytes,
              let data = try? BoundedFileReadService.read(fileURL, maximumBytes: maximumStoreBytes)
        else {
            return nil
        }
        return data
    }

    private static func canMigrateLegacyFile(at fileURL: URL) -> Bool {
        guard !StoragePathService.isPortableDataURL(fileURL),
              let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
              (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid(),
              let permissions = (attributes[.posixPermissions] as? NSNumber)?.uint16Value,
              permissions & 0o077 == 0
        else {
            return false
        }
        return true
    }
}
