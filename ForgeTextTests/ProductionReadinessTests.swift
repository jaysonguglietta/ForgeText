import XCTest
@testable import ForgeText

final class ProductionReadinessTests: XCTestCase {
    func testOpenFallsBackToBinaryHexPreviewForUndecodableFiles() throws {
        let url = temporaryFileURL(named: "binary.bin")
        defer { try? FileManager.default.removeItem(at: url) }

        let binaryPayload = Data([0x00, 0xFF, 0x10, 0x80, 0x7F, 0x01])
        try binaryPayload.write(to: url)

        let opened = try TextFileCodec.open(from: url)

        XCTAssertTrue(opened.isReadOnly)
        XCTAssertEqual(opened.presentationMode, .binaryHex)
        XCTAssertTrue(opened.text.contains("Binary preview"))
    }

    func testSearchableTextSkipsLargeFilesOverLimit() throws {
        let url = temporaryFileURL(named: "big.log")
        defer { try? FileManager.default.removeItem(at: url) }

        let payload = String(repeating: "alpha", count: 500_000)
        try payload.write(to: url, atomically: true, encoding: .utf8)

        let searchableText = TextFileCodec.searchableText(from: url, maxBytes: 32)

        XCTAssertNil(searchableText)
    }

    func testComparisonServicePerformanceBaseline() {
        let left = Array(repeating: "alpha", count: 180).joined(separator: "\n")
        let right = Array(repeating: "alpha", count: 179).joined(separator: "\n") + "\nbeta"

        measure {
            _ = DocumentComparisonService.compare(left: left, right: right)
        }
    }

    private func temporaryFileURL(named filename: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)-\(filename)")
    }
}
