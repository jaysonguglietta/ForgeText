import CryptoKit
import Foundation

struct PluginManifestProvenance: Hashable {
    let canonicalSHA256: String
    let verifiedSigningKey: String?

    var isSignatureVerified: Bool {
        verifiedSigningKey != nil
    }
}

enum PluginSignatureService {
    static func provenance(for data: Data) -> PluginManifestProvenance? {
        guard var object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let signatureText = object.removeValue(forKey: "signature") as? String
        let signingKeyText = object["signingPublicKey"] as? String
        guard let canonicalData = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]) else {
            return nil
        }

        let digest = SHA256.hash(data: canonicalData).map { String(format: "%02x", $0) }.joined()
        let verifiedSigningKey: String?
        if let signatureText,
           let signingKeyText,
           let signature = Data(base64Encoded: signatureText),
           let keyData = Data(base64Encoded: signingKeyText),
           let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData),
           publicKey.isValidSignature(signature, for: canonicalData) {
            verifiedSigningKey = signingKeyText
        } else {
            verifiedSigningKey = nil
        }

        return PluginManifestProvenance(
            canonicalSHA256: digest,
            verifiedSigningKey: verifiedSigningKey
        )
    }

    static func provenance(for entry: PluginRegistryEntry) -> PluginManifestProvenance? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(entry) else {
            return nil
        }
        return provenance(for: data)
    }
}
