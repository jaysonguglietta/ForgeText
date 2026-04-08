import XCTest
@testable import ForgeText

final class GitServiceTests: XCTestCase {
    func testChangedFilesReportsTrackedModification() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try CommandExecutionService.runString("/usr/bin/git", arguments: ["init", root.path])
        _ = try CommandExecutionService.runString("/usr/bin/git", arguments: ["-C", root.path, "config", "user.email", "forge@example.com"])
        _ = try CommandExecutionService.runString("/usr/bin/git", arguments: ["-C", root.path, "config", "user.name", "ForgeText"])

        let fileURL = root.appendingPathComponent("README.md")
        try "# ForgeText\n".write(to: fileURL, atomically: true, encoding: .utf8)
        _ = try CommandExecutionService.runString("/usr/bin/git", arguments: ["-C", root.path, "add", "README.md"])
        _ = try CommandExecutionService.runString("/usr/bin/git", arguments: ["-C", root.path, "commit", "-m", "Initial commit"])

        try "# ForgeText\nUpdated\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let changedFiles = GitService.changedFiles(for: root)

        XCTAssertEqual(changedFiles.count, 1)
        XCTAssertEqual(changedFiles.first?.relativePath, "README.md")
    }
}
