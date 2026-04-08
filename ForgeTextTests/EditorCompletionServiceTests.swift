import XCTest
@testable import ForgeText

final class EditorCompletionServiceTests: XCTestCase {
    func testJSONKeyCompletionUsesQuotedKeyInsertion() {
        let text = "{\n  \"na"
        let selection = NSRange(location: (text as NSString).length, length: 0)

        let session = EditorCompletionService.session(
            in: text,
            selectedRange: selection,
            language: .json,
            sourceURL: URL(fileURLWithPath: "/tmp/example.json")
        )

        XCTAssertEqual(session?.prefix, "na")
        XCTAssertEqual(session?.suggestions.first?.insertText, "name\": ")
    }

    func testMarkdownBlankLineOffersListAndHeadingSnippets() {
        let text = ""
        let session = EditorCompletionService.session(
            in: text,
            selectedRange: NSRange(location: 0, length: 0),
            language: .markdown,
            sourceURL: URL(fileURLWithPath: "/tmp/notes.md")
        )

        let displayValues = session?.suggestions.map(\.displayText) ?? []
        XCTAssertTrue(displayValues.contains("# "))
        XCTAssertTrue(displayValues.contains("- [ ] "))
    }

    func testDotEnvProfileOffersEnvironmentVariablePredictions() {
        let text = "PO"
        let selection = NSRange(location: 2, length: 0)

        let session = EditorCompletionService.session(
            in: text,
            selectedRange: selection,
            language: .config,
            sourceURL: URL(fileURLWithPath: "/tmp/.env")
        )

        XCTAssertEqual(session?.suggestions.first?.insertText, "PORT=")
    }

    func testDocumentDerivedSuggestionsSurfaceExistingSymbols() {
        let text = "version = 1\nversion_name = \"ForgeText\"\nver"
        let selection = NSRange(location: (text as NSString).length, length: 0)

        let session = EditorCompletionService.session(
            in: text,
            selectedRange: selection,
            language: .config,
            sourceURL: URL(fileURLWithPath: "/tmp/app.conf")
        )

        let displayValues = session?.suggestions.map(\.displayText) ?? []
        XCTAssertTrue(displayValues.contains("version_name"))
    }

    func testCompletionMutationReplacesCurrentPrefix() {
        let text = "sel"
        let selection = NSRange(location: 3, length: 0)
        let session = EditorCompletionService.session(
            in: text,
            selectedRange: selection,
            language: .sql,
            sourceURL: URL(fileURLWithPath: "/tmp/query.sql")
        )

        guard let session, let suggestion = session.suggestions.first else {
            return XCTFail("Expected SQL completion suggestions")
        }

        let mutation = EditorCompletionService.mutation(for: suggestion, in: session)
        XCTAssertEqual(mutation.replacementRange, NSRange(location: 0, length: 3))
        XCTAssertEqual(mutation.replacementText, "SELECT")
    }
}
