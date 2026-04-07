import XCTest
@testable import ForgeText

final class EditorDocumentPresentationTests: XCTestCase {
    func testLoadedJSONDocumentsDefaultToStructuredTree() {
        let file = TextFileCodec.DecodedFile(
            text: "{\n  \"service\": \"ForgeText\"\n}\n",
            encoding: .utf8,
            includesByteOrderMark: false,
            lineEnding: .lf,
            isReadOnly: false,
            isPartialPreview: false,
            fileSize: 32,
            presentationMode: .editor,
            preferredLanguage: .json,
            statusMessage: nil
        )

        let document = EditorDocument.loaded(file: file, url: URL(fileURLWithPath: "/tmp/config.json"))

        XCTAssertEqual(document.language, .json)
        XCTAssertEqual(document.presentationMode, .structuredJSON)
        XCTAssertTrue(document.prefersStructuredPresentation)
    }

    func testLoadedLogDocumentsDefaultToLogExplorer() {
        let file = TextFileCodec.DecodedFile(
            text: "2026-04-06 10:00:00 INFO started\n",
            encoding: .utf8,
            includesByteOrderMark: false,
            lineEnding: .lf,
            isReadOnly: false,
            isPartialPreview: false,
            fileSize: 34,
            presentationMode: .editor,
            preferredLanguage: .log,
            statusMessage: nil
        )

        let document = EditorDocument.loaded(file: file, url: URL(fileURLWithPath: "/tmp/service.log"))

        XCTAssertEqual(document.language, .log)
        XCTAssertEqual(document.presentationMode, .logExplorer)
        XCTAssertTrue(document.prefersStructuredPresentation)
    }

    func testUntitledJSONContentStaysInEditorUntilStructuredViewIsRequested() {
        var document = EditorDocument.untitled(named: "Untitled")
        document.text = "{\n  \"service\": \"ForgeText\"\n}\n"

        document.refreshLanguageIfNeeded()

        XCTAssertEqual(document.language, .json)
        XCTAssertEqual(document.presentationMode, .editor)
        XCTAssertFalse(document.prefersStructuredPresentation)
    }
}
