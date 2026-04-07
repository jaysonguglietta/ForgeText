import XCTest
@testable import ForgeText

final class TextSearchServiceTests: XCTestCase {
    func testPlainSearchFindsCaseInsensitiveMatches() {
        let result = TextSearchService.search(
            in: "Alpha beta ALPHA gamma",
            query: "alpha",
            options: SearchOptions(isCaseSensitive: false, usesRegularExpression: false)
        )

        XCTAssertNil(result.errorMessage)
        XCTAssertEqual(result.ranges.count, 2)
        XCTAssertEqual(result.ranges[0], NSRange(location: 0, length: 5))
        XCTAssertEqual(result.ranges[1], NSRange(location: 11, length: 5))
    }

    func testRegexReplaceAllUsesCaptureGroups() {
        let replacement = TextSearchService.replaceAll(
            in: "alpha=1\nbeta=2",
            query: #"(\w+)=(\d+)"#,
            replacement: #"$1: $2"#,
            options: SearchOptions(isCaseSensitive: true, usesRegularExpression: true)
        )

        XCTAssertEqual(replacement?.replacementCount, 2)
        XCTAssertEqual(replacement?.text, "alpha: 1\nbeta: 2")
    }

    func testLanguageDetectionUsesFileExtension() {
        XCTAssertEqual(DocumentLanguage.detect(from: URL(fileURLWithPath: "/tmp/example.md")), .markdown)
        XCTAssertEqual(DocumentLanguage.detect(from: URL(fileURLWithPath: "/tmp/example.json")), .json)
        XCTAssertEqual(DocumentLanguage.detect(from: URL(fileURLWithPath: "/tmp/example.toml")), .config)
        XCTAssertEqual(DocumentLanguage.detect(from: URL(fileURLWithPath: "/tmp/example.ts")), .javascript)
        XCTAssertEqual(DocumentLanguage.detect(from: URL(fileURLWithPath: "/tmp/example.py")), .python)
        XCTAssertEqual(DocumentLanguage.detect(from: URL(fileURLWithPath: "/tmp/example.csv")), .csv)
    }

    func testLanguageDetectionUsesFilenameAndContentHeuristics() {
        XCTAssertEqual(
            DocumentLanguage.detect(from: URL(fileURLWithPath: "/tmp/Dockerfile"), text: "FROM swift:latest"),
            .config
        )
        XCTAssertEqual(
            DocumentLanguage.detect(from: nil, text: "#!/usr/bin/env python3\nprint('hello')\n"),
            .python
        )
        XCTAssertEqual(
            DocumentLanguage.detect(from: nil, text: "{\n  \"name\": \"ForgeText\"\n}\n"),
            .json
        )
        XCTAssertEqual(
            DocumentLanguage.detect(from: nil, text: "SELECT * FROM projects WHERE active = 1;\n"),
            .sql
        )
        XCTAssertEqual(
            DocumentLanguage.detect(from: nil, text: "import Foundation\nfunc greet() {}\n"),
            .swift
        )
        XCTAssertEqual(
            DocumentLanguage.detect(from: nil, text: "name,email\nAda,ada@example.com\nGrace,grace@example.com\n"),
            .csv
        )
        XCTAssertEqual(
            DocumentLanguage.detect(from: nil, text: "2026-04-06 12:14:33 ERROR [worker] job_id=42 Failed job\n"),
            .log
        )
    }
}
