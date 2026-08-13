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

    func testTimelineClusteringSeparatesEntriesAcrossLargeGaps() throws {
        let document = try XCTUnwrap(LogExplorerService.parse(
            """
            2026-04-06T10:00:00Z INFO [api] Started
            2026-04-06T10:00:15Z WARN [api] Retrying
            2026-04-06T10:04:00Z ERROR [worker] Failed
            """,
            requireLogSignals: true
        ))
        let clusters = LogExplorerService.timelineClusters(entries: document.entries, maximumGap: 60)

        XCTAssertEqual(clusters.count, 2)
        XCTAssertEqual(clusters.map { $0.entries.count }, [2, 1])
    }

    func testMultiFileSessionAttributesSourcesAndOrdersTimestamps() throws {
        let first = try XCTUnwrap(LogExplorerService.parse(
            "2026-04-06T10:00:02Z INFO [api] Second\n",
            requireLogSignals: false
        ))
        let second = try XCTUnwrap(LogExplorerService.parse(
            "2026-04-06T10:00:01Z ERROR First\n",
            requireLogSignals: false
        ))
        let session = try XCTUnwrap(LogExplorerService.mergedSession([
            (name: "api.log", document: first),
            (name: "worker.log", document: second),
        ]))

        XCTAssertEqual(session.entries.map(\.message), ["First", "Second"])
        XCTAssertEqual(session.entries.map(\.source), ["worker.log", "api.log · api"])
        XCTAssertEqual(session.errorCount, 1)
    }
}
