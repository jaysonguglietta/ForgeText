import XCTest
@testable import ForgeText

final class EditorBehaviorTests: XCTestCase {
    func testNewlineAfterOpeningBraceAddsIndentation() {
        let mutation = EditorBehavior.newlineMutation(
            in: "if ready {",
            selectedRange: NSRange(location: 10, length: 0),
            language: .swift
        )

        XCTAssertEqual(mutation.replacementText, "\n    ")
        XCTAssertEqual(mutation.selectedRange, NSRange(location: 15, length: 0))
    }

    func testNewlineBetweenBracesCreatesBalancedIndentedBlock() {
        let mutation = EditorBehavior.newlineMutation(
            in: "{}",
            selectedRange: NSRange(location: 1, length: 0),
            language: .swift
        )

        XCTAssertEqual(mutation.replacementText, "\n    \n")
        XCTAssertEqual(mutation.selectedRange, NSRange(location: 6, length: 0))
    }

    func testTabMutationIndentsSelectedLines() {
        let mutation = EditorBehavior.tabMutation(
            in: "alpha\nbeta",
            selectedRange: NSRange(location: 0, length: 10),
            language: .swift
        )

        XCTAssertEqual(mutation.replacementText, "    alpha\n    beta")
        XCTAssertEqual(mutation.selectedRange, NSRange(location: 0, length: 18))
    }

    func testBacktabMutationOutdentsSelectedLines() {
        let mutation = EditorBehavior.backtabMutation(
            in: "    alpha\n    beta",
            selectedRange: NSRange(location: 0, length: 18),
            language: .swift
        )

        XCTAssertEqual(mutation?.replacementText, "alpha\nbeta")
    }

    func testToggleCommentCommentsAndUncommentsCurrentLine() {
        let commented = EditorBehavior.toggleCommentMutation(
            in: "let value = 1",
            selectedRange: NSRange(location: 4, length: 0),
            language: .swift
        )

        XCTAssertEqual(commented?.replacementText, "// let value = 1")

        let uncommented = EditorBehavior.toggleCommentMutation(
            in: commented?.replacementText ?? "",
            selectedRange: NSRange(location: 7, length: 0),
            language: .swift
        )

        XCTAssertEqual(uncommented?.replacementText, "let value = 1")
    }

    func testBracketMatchingFindsPairedBraces() {
        let ranges = EditorBehavior.matchedBracketRanges(
            in: "func call() { return items[0] }",
            selectedRange: NSRange(location: 11, length: 0),
            language: .swift
        )

        XCTAssertEqual(ranges, [NSRange(location: 9, length: 1), NSRange(location: 10, length: 1)])
    }
}
