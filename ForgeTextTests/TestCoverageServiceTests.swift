import XCTest
@testable import ForgeText

final class TestCoverageServiceTests: XCTestCase {
    func testSummaryParsesPytestCovTotalLine() {
        let output = """
        ---------- coverage: platform darwin ----------
        Name                 Stmts   Miss  Cover
        TOTAL                   12      1  91.7%
        """

        let summary = TestCoverageService.summary(from: output)

        XCTAssertEqual(summary?.toolName, "pytest-cov")
        XCTAssertEqual(summary?.percentage ?? 0, 91.7, accuracy: 0.001)
    }

    func testSummaryParsesGenericCoverageLine() {
        let output = """
        Running tests...
        Coverage: 88.0%
        """

        let summary = TestCoverageService.summary(from: output)

        XCTAssertEqual(summary?.toolName, "coverage")
        XCTAssertEqual(summary?.percentage ?? 0, 88.0, accuracy: 0.001)
    }
}
