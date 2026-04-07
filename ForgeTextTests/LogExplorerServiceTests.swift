import XCTest
@testable import ForgeText

final class LogExplorerServiceTests: XCTestCase {
    func testParseCapturesSeveritySourceMetadataAndContinuationLines() {
        let text = """
        2026-04-06T10:00:00Z INFO [web] request_id=abc Started request
          GET /health
        2026-04-06T10:00:01Z ERROR [worker] job_id=42 Failed job
          at Worker.run
        """

        let document = LogExplorerService.parse(text, requireLogSignals: true)

        XCTAssertEqual(document?.entries.count, 2)
        XCTAssertEqual(document?.entries.first?.severity, .info)
        XCTAssertEqual(document?.entries.first?.source, "web")
        XCTAssertEqual(document?.entries.first?.metadata.first?.key, "request_id")
        XCTAssertEqual(document?.entries.first?.metadata.first?.value, "abc")
        XCTAssertEqual(document?.entries.first?.details.count, 1)
        XCTAssertEqual(document?.errorCount, 1)
    }

    func testRequireLogSignalsRejectsPlainText() {
        let text = """
        hello there
        this is just some prose
        not a log stream
        """

        XCTAssertNil(LogExplorerService.parse(text, requireLogSignals: true))
    }
}
