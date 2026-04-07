import XCTest
@testable import ForgeText

final class JSONTreeServiceTests: XCTestCase {
    func testParseBuildsStructuredTreeSummary() {
        let text = """
        {
          "service": "forge",
          "ports": [80, 443],
          "enabled": true,
          "owner": {
            "team": "ops"
          }
        }
        """

        let tree = JSONTreeService.parse(text)

        XCTAssertEqual(tree?.topLevelType, .object)
        XCTAssertEqual(tree?.topLevelCount, 4)
        XCTAssertEqual(tree?.nodeCount, 8)
        XCTAssertEqual(tree?.maxDepth, 3)
    }

    func testFilterKeepsMatchingNestedBranches() {
        let text = """
        {
          "service": "forge",
          "owner": {
            "team": "ops"
          }
        }
        """

        guard let tree = JSONTreeService.parse(text) else {
            return XCTFail("Expected valid JSON tree")
        }

        let filtered = JSONTreeService.filteredNodes(in: tree, matching: "ops")

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.key, "owner")
        XCTAssertEqual(filtered.first?.children.first?.key, "team")
    }
}
