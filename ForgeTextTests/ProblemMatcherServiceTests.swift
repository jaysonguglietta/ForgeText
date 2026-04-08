import XCTest
@testable import ForgeText

final class ProblemMatcherServiceTests: XCTestCase {
    func testProblemMatcherParsesStandardCompilerFormat() {
        let output = """
        /tmp/project/Sources/App/main.swift:12:5: error: cannot find 'name' in scope
        /tmp/project/Sources/App/main.swift:18:9: warning: variable was never mutated
        """

        let records = ProblemMatcherService.parseProblems(from: output, source: "Swift Build")

        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records.first?.severity, .error)
        XCTAssertEqual(records.first?.lineNumber, 12)
        XCTAssertEqual(records.first?.columnNumber, 5)
        XCTAssertTrue(records.first?.message.contains("cannot find") == true)
    }
}
