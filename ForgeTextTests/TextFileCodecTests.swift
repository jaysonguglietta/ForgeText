import XCTest
import Darwin
@testable import ForgeText

final class TextFileCodecTests: XCTestCase {
    func testLoadDetectsUTF8ByteOrderMarkAndCRLF() throws {
        let url = temporaryFileURL(named: "utf8-bom.txt")
        let payload = Data([0xEF, 0xBB, 0xBF]) + Data("first\r\nsecond".utf8)
        try payload.write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }

        let decoded = try TextFileCodec.load(from: url)

        XCTAssertEqual(decoded.text, "first\r\nsecond")
        XCTAssertEqual(decoded.encoding, .utf8)
        XCTAssertTrue(decoded.includesByteOrderMark)
        XCTAssertEqual(decoded.lineEnding, .crlf)
    }

    func testSavePreservesRequestedLineEndingsAndBOM() throws {
        let url = temporaryFileURL(named: "saved.txt")
        defer { try? FileManager.default.removeItem(at: url) }

        let document = EditorDocument(
            id: UUID(),
            untitledName: "saved.txt",
            text: "hello\nworld",
            fileURL: url,
            encoding: .utf8,
            includesByteOrderMark: true,
            lineEnding: .crlf,
            selectedRange: NSRange(location: 0, length: 0),
            isDirty: true,
            lastSavedText: "",
            language: .plainText,
            findState: .init(),
            hasExternalChanges: false,
            fileMissingOnDisk: false,
            hasRecoveredDraft: false,
            lastKnownDiskFingerprint: nil,
            lastSavedAt: nil,
            statusMessage: nil
        )

        try TextFileCodec.save(document: document, to: url)

        let written = try Data(contentsOf: url)
        XCTAssertEqual(Array(written.prefix(3)), [0xEF, 0xBB, 0xBF])
        XCTAssertEqual(String(data: written.dropFirst(3), encoding: .utf8), "hello\r\nworld")
    }

    func testLineMetricsUseOneBasedCursorCoordinates() {
        let metrics = EditorMetrics(
            text: "alpha\nbeta",
            selectedRange: NSRange(location: 7, length: 0)
        )

        XCTAssertEqual(metrics.lineCount, 2)
        XCTAssertEqual(metrics.cursorLine, 2)
        XCTAssertEqual(metrics.cursorColumn, 2)
    }

    func testOpenRejectsNamedPipes() throws {
        let url = temporaryFileURL(named: "events.fifo")
        XCTAssertEqual(mkfifo(url.path, 0o644), 0)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try TextFileCodec.open(from: url)) { error in
            guard case TextFileCodec.CodecError.unsupportedFileType = error else {
                return XCTFail("Expected unsupportedFileType, got \(error)")
            }
        }
    }

    func testLargeEditableDocumentUsesAdaptiveEditorMode() {
        var document = EditorDocument.untitled(named: "large.log")
        document.fileSize = TextFileCodec.largeFileModeThreshold

        XCTAssertTrue(document.isLargeFileMode)
        XCTAssertEqual(TextFileCodec.maximumEditableFileSize, 32_000_000)
        XCTAssertLessThan(TextFileCodec.largeFileModeThreshold, TextFileCodec.maximumEditableFileSize)
    }

    private func temporaryFileURL(named filename: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(UUID().uuidString)-\(filename)")
    }
}
