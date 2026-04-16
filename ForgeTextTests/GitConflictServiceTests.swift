import XCTest
@testable import ForgeText

final class GitConflictServiceTests: XCTestCase {
    func testSectionsParseCurrentBaseAndIncomingBlocks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let fileURL = root.appendingPathComponent("conflict.txt")
        let text = """
        before
        <<<<<<< HEAD
        current line
        ||||||| base
        base line
        =======
        incoming line
        >>>>>>> feature
        after
        """
        try text.write(to: fileURL, atomically: true, encoding: .utf8)

        let sections = GitConflictService.sections(from: fileURL)

        XCTAssertEqual(sections.count, 1)
        XCTAssertEqual(sections.first?.currentLabel, "HEAD")
        XCTAssertEqual(sections.first?.currentText, "current line")
        XCTAssertEqual(sections.first?.baseText, "base line")
        XCTAssertEqual(sections.first?.incomingLabel, "feature")
        XCTAssertEqual(sections.first?.incomingText, "incoming line")
    }

    func testResolveAllConflictsSupportsCurrentIncomingAndBoth() {
        let text = """
        start
        <<<<<<< HEAD
        current line
        =======
        incoming line
        >>>>>>> feature
        end
        """

        XCTAssertEqual(
            GitConflictService.resolveAllConflicts(in: text, strategy: .current),
            "start\ncurrent line\nend"
        )
        XCTAssertEqual(
            GitConflictService.resolveAllConflicts(in: text, strategy: .incoming),
            "start\nincoming line\nend"
        )
        XCTAssertEqual(
            GitConflictService.resolveAllConflicts(in: text, strategy: .both),
            "start\ncurrent line\nincoming line\nend"
        )
    }
}
