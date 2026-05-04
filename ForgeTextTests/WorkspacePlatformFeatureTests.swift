import XCTest
@testable import ForgeText

final class WorkspacePlatformFeatureTests: XCTestCase {
    func testStructuredConfigParsesNestedYAML() {
        let text = """
        service:
          name: forge
          ports:
            - 8080
            - 8443
        """

        let url = URL(fileURLWithPath: "/tmp/config.yaml")
        let document = StructuredConfigService.parse(text, url: url)

        XCTAssertEqual(document?.format.rawValue, ConfigFormatKind.yaml.rawValue)
        XCTAssertEqual(document?.topLevelCount, 1)
        XCTAssertEqual(document?.nodes.first?.key, "service")
        XCTAssertEqual(document?.nodes.first?.children.first?.key, "name")
        XCTAssertEqual(document?.nodes.first?.children.dropFirst().first?.key, "ports")
    }

    func testStructuredConfigParsesEnvironmentFiles() {
        let text = """
        APP_ENV=production
        LOG_LEVEL=debug
        """

        let url = URL(fileURLWithPath: "/tmp/.env")
        let document = StructuredConfigService.parse(text, url: url)

        XCTAssertEqual(document?.format.rawValue, ConfigFormatKind.env.rawValue)
        XCTAssertEqual(document?.itemCount, 2)
        XCTAssertEqual(document?.nodes.first?.key, "APP_ENV")
        XCTAssertEqual(document?.nodes.first?.value, "production")
    }

    func testGzipRoundTripPreservesPayload() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).txt.gz")
        defer { try? FileManager.default.removeItem(at: url) }

        let original = Data("forge-text\nline-two".utf8)
        let compressed = try CompressedFileService.compressGzip(original)
        try compressed.write(to: url)

        let decompressed = try CompressedFileService.decompressGzip(at: url)

        XCTAssertEqual(decompressed, original)
        XCTAssertEqual(CompressedFileService.underlyingURL(forGzipURL: url).pathExtension, "txt")
    }

    func testLargeGzipOpensAsReadOnlyPreview() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).log.gz")
        defer { try? FileManager.default.removeItem(at: url) }

        let largeText = String(repeating: "forge-log-line\n", count: 700_000)
        let compressed = try CompressedFileService.compressGzip(Data(largeText.utf8))
        try compressed.write(to: url)

        let decoded = try TextFileCodec.open(from: url)

        XCTAssertTrue(decoded.isReadOnly)
        XCTAssertTrue(decoded.isPartialPreview)
        XCTAssertEqual(decoded.presentationMode, .readOnlyPreview)
        XCTAssertEqual(decoded.preferredLanguage, .log)
        XCTAssertEqual(decoded.statusMessage, "Large gzip preview loaded read-only")
    }

    func testRemoteFileReferenceParsesSSHLocation() {
        let reference = RemoteFileReference.parse("ops@example.com:/etc/nginx/nginx.conf")

        XCTAssertEqual(reference?.connection, "ops@example.com")
        XCTAssertEqual(reference?.path, "/etc/nginx/nginx.conf")
        XCTAssertEqual(reference?.displayName, "nginx.conf")
    }

    func testArchiveBrowserRecognizesCommonArchiveExtensions() {
        XCTAssertTrue(ArchiveBrowserService.canBrowse(URL(fileURLWithPath: "/tmp/logs.zip")))
        XCTAssertTrue(ArchiveBrowserService.canBrowse(URL(fileURLWithPath: "/tmp/logs.tar.gz")))
        XCTAssertTrue(ArchiveBrowserService.canBrowse(URL(fileURLWithPath: "/tmp/logs.tgz")))
        XCTAssertFalse(ArchiveBrowserService.canBrowse(URL(fileURLWithPath: "/tmp/logs.txt")))
    }
}
