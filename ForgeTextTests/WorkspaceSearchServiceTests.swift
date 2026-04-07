import XCTest
@testable import ForgeText

final class WorkspaceSearchServiceTests: XCTestCase {
    func testWorkspaceSearchFindsMatchesAcrossFiles() throws {
        let rootURL = temporaryDirectoryURL()
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: rootURL) }

        try "alpha beta\n".write(to: rootURL.appendingPathComponent("first.txt"), atomically: true, encoding: .utf8)
        try "gamma alpha\n".write(to: rootURL.appendingPathComponent("second.txt"), atomically: true, encoding: .utf8)

        let summary = WorkspaceSearchService.search(
            root: rootURL,
            query: "alpha",
            options: SearchOptions(isCaseSensitive: false, usesRegularExpression: false),
            includeHiddenFiles: false
        )

        XCTAssertEqual(summary.hits.count, 2)
        XCTAssertEqual(summary.scannedFileCount, 2)
    }

    func testDocumentComparisonMarksInsertedAndDeletedLines() {
        let lines = DocumentComparisonService.compare(
            left: "alpha\nbeta\ngamma",
            right: "alpha\ngamma\ndelta"
        )

        XCTAssertTrue(lines.contains(where: { $0.kind == .deleted && $0.leftText == "beta" }))
        XCTAssertTrue(lines.contains(where: { $0.kind == .inserted && $0.rightText == "delta" }))
    }

    private func temporaryDirectoryURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
    }
}
