import CryptoKit
import Foundation

struct SignedArtifactVerification: Hashable {
    let canonicalSHA256: String
    let verifiedSigningKey: String?
}

enum SignedArtifactService {
    enum VerificationError: LocalizedError, Equatable {
        case invalidJSON
        case unsupportedAlgorithm
        case signatureRequired
        case missingTrustRoots
        case untrustedSigningKey
        case malformedSignature
        case invalidSignature

        var errorDescription: String? {
            switch self {
            case .invalidJSON: return "The signed artifact is not a JSON object."
            case .unsupportedAlgorithm: return "The artifact uses an unsupported signature algorithm."
            case .signatureRequired: return "This installation requires a signed artifact."
            case .missingTrustRoots: return "The artifact is signed, but no administrator-trusted signing keys are configured."
            case .untrustedSigningKey: return "The artifact signing key is not trusted by this installation."
            case .malformedSignature: return "The artifact signature or public key is malformed."
            case .invalidSignature: return "The artifact signature does not match its canonical payload."
            }
        }
    }

    static func verify(
        data: Data,
        trustedPublicKeys: [String],
        requiresSignature: Bool
    ) throws -> SignedArtifactVerification {
        guard var object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw VerificationError.invalidJSON
        }
        let signatureObject = object.removeValue(forKey: "signature")
        let canonicalData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        let digest = SHA256.hash(data: canonicalData).map { String(format: "%02x", $0) }.joined()

        guard let signatureObject else {
            if requiresSignature { throw VerificationError.signatureRequired }
            return SignedArtifactVerification(canonicalSHA256: digest, verifiedSigningKey: nil)
        }
        guard let signatureDictionary = signatureObject as? [String: Any],
              let signatureData = try? JSONSerialization.data(withJSONObject: signatureDictionary),
              let signature = try? JSONDecoder().decode(SignedArtifactSignature.self, from: signatureData)
        else {
            throw VerificationError.malformedSignature
        }
        guard signature.algorithm.lowercased() == "ed25519" else {
            throw VerificationError.unsupportedAlgorithm
        }

        let trusted = Set(trustedPublicKeys.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty })
        guard !trusted.isEmpty else { throw VerificationError.missingTrustRoots }
        guard trusted.contains(signature.publicKey) else { throw VerificationError.untrustedSigningKey }
        guard let publicKeyData = Data(base64Encoded: signature.publicKey),
              let valueData = Data(base64Encoded: signature.value),
              let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData)
        else {
            throw VerificationError.malformedSignature
        }
        guard publicKey.isValidSignature(valueData, for: canonicalData) else {
            throw VerificationError.invalidSignature
        }
        return SignedArtifactVerification(canonicalSHA256: digest, verifiedSigningKey: signature.publicKey)
    }
}
