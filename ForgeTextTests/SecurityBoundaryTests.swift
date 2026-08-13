import CryptoKit
import XCTest
@testable import ForgeText

final class SecurityBoundaryTests: XCTestCase {
    func testPublicNetworkPolicyRejectsLoopbackDestinations() {
        XCTAssertThrowsError(
            try SecureNetworkService.validate(
                url: URL(string: "https://127.0.0.1/internal")!,
                policy: .publicInternet()
            )
        ) { error in
            XCTAssertEqual(
                error as? SecureNetworkService.NetworkError,
                .privateNetworkRequiresConfirmation("127.0.0.1")
            )
        }
    }

    func testLocalServicePolicyAcceptsLoopbackDestinations() throws {
        try SecureNetworkService.validate(
            url: URL(string: "http://127.0.0.1:11434/api/chat")!,
            policy: .localService(allowedHosts: ["127.0.0.1"])
        )
    }

    func testHostAllowlistRequiresAnExactMatch() {
        XCTAssertThrowsError(
            try SecureNetworkService.validate(
                url: URL(string: "https://attacker.api.example.com/data")!,
                policy: .publicInternet(allowedHosts: ["api.example.com"])
            )
        ) { error in
            XCTAssertEqual(
                error as? SecureNetworkService.NetworkError,
                .hostNotAllowed("attacker.api.example.com")
            )
        }
    }

    func testNetworkPolicyRejectsCredentialsEmbeddedInURL() {
        XCTAssertThrowsError(
            try SecureNetworkService.validate(
                url: URL(string: "https://user:secret@example.com/data")!,
                policy: .publicInternet()
            )
        ) { error in
            XCTAssertEqual(error as? SecureNetworkService.NetworkError, .credentialsInURL)
        }
    }

    func testPluginManifestSignatureDetectsTampering() throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        var object: [String: Any] = [
            "id": "com.example.signed",
            "name": "Signed Plugin",
            "version": "1.0.0",
            "author": "Example",
            "signingPublicKey": privateKey.publicKey.rawRepresentation.base64EncodedString(),
        ]
        let canonicalData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        object["signature"] = try privateKey.signature(for: canonicalData).base64EncodedString()
        let signedData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])

        let verified = try XCTUnwrap(PluginSignatureService.provenance(for: signedData))
        XCTAssertTrue(verified.isSignatureVerified)

        object["name"] = "Tampered Plugin"
        let tamperedData = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        let tampered = try XCTUnwrap(PluginSignatureService.provenance(for: tamperedData))
        XCTAssertFalse(tampered.isSignatureVerified)
        XCTAssertNotEqual(tampered.canonicalSHA256, verified.canonicalSHA256)
    }

    func testBoundedReaderRejectsOversizedAndSymbolicLinkFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let fileURL = root.appendingPathComponent("payload")
        try Data(repeating: 0x41, count: 5).write(to: fileURL)
        XCTAssertThrowsError(try BoundedFileReadService.read(fileURL, maximumBytes: 4))

        let linkURL = root.appendingPathComponent("payload-link")
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: fileURL)
        XCTAssertThrowsError(try BoundedFileReadService.read(linkURL, maximumBytes: 10))
    }

    func testSignedArtifactsRequireTrustedKeysAndDetectTampering() throws {
        let privateKey = Curve25519.Signing.PrivateKey()
        let publicKey = privateKey.publicKey.rawRepresentation.base64EncodedString()
        var object: [String: Any] = ["schemaVersion": 1, "organizationName": "Acme"]
        let canonical = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        object["signature"] = [
            "algorithm": "ed25519",
            "publicKey": publicKey,
            "value": try privateKey.signature(for: canonical).base64EncodedString(),
        ]
        let signed = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])

        let verification = try SignedArtifactService.verify(
            data: signed,
            trustedPublicKeys: [publicKey],
            requiresSignature: true
        )
        XCTAssertEqual(verification.verifiedSigningKey, publicKey)

        object["organizationName"] = "Attacker"
        let tampered = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys])
        XCTAssertThrowsError(
            try SignedArtifactService.verify(
                data: tampered,
                trustedPublicKeys: [publicKey],
                requiresSignature: true
            )
        ) { error in
            XCTAssertEqual(error as? SignedArtifactService.VerificationError, .invalidSignature)
        }
    }

    func testChunkedTextReaderSearchesAndRejectsSymbolicLinks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let fileURL = root.appendingPathComponent("large.log")
        let text = String(repeating: "0123456789\n", count: 8_000) + "SECURITY_MARKER\n"
        try Data(text.utf8).write(to: fileURL)
        let window = try ChunkedTextFileService.readWindow(from: fileURL, offset: 40_000, maximumBytes: 8_192)
        let match = try ChunkedTextFileService.find("SECURITY_MARKER", in: fileURL, startingAt: 0)
        let outOfRangeMatch = try ChunkedTextFileService.find("SECURITY_MARKER", in: fileURL, startingAt: Int64.max)

        XCTAssertGreaterThan(window.startOffset, 0)
        XCTAssertLessThanOrEqual(window.text.utf8.count, 8_192)
        XCTAssertNotNil(match)
        XCTAssertNil(outOfRangeMatch)

        let linkURL = root.appendingPathComponent("large-link.log")
        try FileManager.default.createSymbolicLink(at: linkURL, withDestinationURL: fileURL)
        XCTAssertThrowsError(try ChunkedTextFileService.readWindow(from: linkURL, offset: 0))
    }

    func testSFTPArgumentsAndListingParserStayBounded() {
        let arguments = SFTPDirectoryService.arguments(connection: "ops@example.com")
        let listing = """
        drwxr-xr-x  3 ops staff 96 Apr 15 10:00 configs
        -rw-r--r--  1 ops staff 42 Apr 15 10:01 app.conf
        lrwxr-xr-x  1 ops staff 11 Apr 15 10:02 current -> app.conf
        malformed row
        """
        let entries = SFTPDirectoryService.parseListing(listing, rootPath: "/etc/forge")

        XCTAssertTrue(arguments.contains("StrictHostKeyChecking=yes"))
        XCTAssertTrue(arguments.contains("ClearAllForwardings=yes"))
        XCTAssertEqual(entries.map(\.name), ["configs", "app.conf", "current"])
        XCTAssertEqual(entries.map(\.path), ["/etc/forge/configs", "/etc/forge/app.conf", "/etc/forge/current"])
        XCTAssertEqual(entries.last?.kind, .symbolicLink)
    }
}
