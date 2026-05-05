import AppKit
import XCTest
@testable import ForgeText

@MainActor
final class SyntaxHighlighterTests: XCTestCase {
    func testApplyPreservesMidDocumentInsertionSelectionForMarkdown() {
        let text = """
        Title

        - first item
        - second item
        """
        let textView = NSTextView(frame: .zero)
        textView.string = text

        let insertionPoint = (text as NSString).range(of: "first").location
        let expectedSelection = NSRange(location: insertionPoint, length: 0)
        textView.setSelectedRange(expectedSelection)

        SyntaxHighlighter.apply(
            to: textView,
            theme: .forge,
            language: .markdown,
            fontSize: 14,
            findState: .init(),
            largeFileMode: false
        )

        XCTAssertEqual(textView.selectedRange(), expectedSelection)
    }

    func testApplyPreservesRangeSelections() {
        let text = """
        alpha
        beta
        gamma
        """
        let textView = NSTextView(frame: .zero)
        textView.string = text

        let expectedSelection = (text as NSString).range(of: "beta")
        textView.setSelectedRange(expectedSelection)

        SyntaxHighlighter.apply(
            to: textView,
            theme: .forge,
            language: .plainText,
            fontSize: 14,
            findState: .init(),
            largeFileMode: false
        )

        XCTAssertEqual(textView.selectedRange(), expectedSelection)
    }
}
