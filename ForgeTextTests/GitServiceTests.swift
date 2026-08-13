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

    func testSnapshotIncludesSummaryBranchesAndChangedFiles() throws {
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
        _ = try CommandExecutionService.runString("/usr/bin/git", arguments: ["-C", root.path, "checkout", "-b", "feature/menu-crash"])

        try "# ForgeText\nUpdated\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let snapshot = GitService.snapshot(for: root)

        XCTAssertEqual(snapshot.summary?.branchName, "feature/menu-crash")
        XCTAssertTrue(snapshot.branches.contains("feature/menu-crash"))
        XCTAssertEqual(snapshot.changedFiles.count, 1)
        XCTAssertEqual(snapshot.changedFiles.first?.relativePath, "README.md")
    }

    func testHeadContentsRejectsSiblingPathThatSharesRepositoryPrefix() throws {
        let tempRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let repositoryRoot = tempRoot.appendingPathComponent("repo", isDirectory: true)
        let siblingRoot = tempRoot.appendingPathComponent("repo-other", isDirectory: true)
        try FileManager.default.createDirectory(at: repositoryRoot, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: siblingRoot, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempRoot) }

        _ = try CommandExecutionService.runString("/usr/bin/git", arguments: ["init", repositoryRoot.path])
        _ = try CommandExecutionService.runString("/usr/bin/git", arguments: ["-C", repositoryRoot.path, "config", "user.email", "forge@example.com"])
        _ = try CommandExecutionService.runString("/usr/bin/git", arguments: ["-C", repositoryRoot.path, "config", "user.name", "ForgeText"])

        let trackedFileURL = repositoryRoot.appendingPathComponent("README.md")
        try "# ForgeText\n".write(to: trackedFileURL, atomically: true, encoding: .utf8)
        _ = try CommandExecutionService.runString("/usr/bin/git", arguments: ["-C", repositoryRoot.path, "add", "README.md"])
        _ = try CommandExecutionService.runString("/usr/bin/git", arguments: ["-C", repositoryRoot.path, "commit", "-m", "Initial commit"])

        let siblingFileURL = siblingRoot.appendingPathComponent("README.md")
        try "outside repo\n".write(to: siblingFileURL, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try GitService.headContents(for: siblingFileURL, workspaceRoot: repositoryRoot)) { error in
            XCTAssertEqual(error as? GitService.GitError, .fileOutsideRepository)
        }
    }

    func testReadOnlyGitInspectionDisablesRepositoryFSMonitor() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try CommandExecutionService.runString("/usr/bin/git", arguments: ["init", root.path])
        let markerURL = root.appendingPathComponent("fsmonitor-executed")
        let hookURL = root.appendingPathComponent("malicious-fsmonitor.sh")
        try "#!/bin/sh\ntouch \"\(markerURL.path)\"\nexit 0\n".write(to: hookURL, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: hookURL.path)
        _ = try CommandExecutionService.runString(
            "/usr/bin/git",
            arguments: ["-C", root.path, "config", "core.fsmonitor", hookURL.path]
        )

        _ = GitService.changedFiles(for: root)

        XCTAssertFalse(FileManager.default.fileExists(atPath: markerURL.path))
    }

    func testReviewedPatchCanBeAppliedAndReverted() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        _ = try CommandExecutionService.runString("/usr/bin/git", arguments: ["init", root.path])
        _ = try CommandExecutionService.runString("/usr/bin/git", arguments: ["-C", root.path, "config", "user.email", "forge@example.com"])
        _ = try CommandExecutionService.runString("/usr/bin/git", arguments: ["-C", root.path, "config", "user.name", "ForgeText"])
        let fileURL = root.appendingPathComponent("README.md")
        try "Old\n".write(to: fileURL, atomically: true, encoding: .utf8)
        _ = try CommandExecutionService.runString("/usr/bin/git", arguments: ["-C", root.path, "add", "README.md"])
        _ = try CommandExecutionService.runString("/usr/bin/git", arguments: ["-C", root.path, "commit", "-m", "Initial"])

        let patch = """
        diff --git a/README.md b/README.md
        --- a/README.md
        +++ b/README.md
        @@ -1 +1 @@
        -Old
        +New

        """

        try GitService.applyReviewedPatch(patch, at: root)
        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), "New\n")

        try GitService.applyReviewedPatch(patch, at: root, reverse: true)
        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), "Old\n")
    }

    func testReviewedHunksCanBeStagedWithoutChangingWorkingFile() throws {
        let root = try makeRepository()
        defer { try? FileManager.default.removeItem(at: root) }
        let fileURL = root.appendingPathComponent("README.md")
        try "One\nTwo changed\nThree\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let patch = try GitService.workingTreePatch(for: fileURL, workspaceRoot: root)
        XCTAssertTrue(patch.contains("Two changed"))

        try GitService.stageReviewedPatch(patch, at: root)
        let staged = try CommandExecutionService.runString(
            "/usr/bin/git",
            arguments: ["-C", root.path, "diff", "--cached"]
        )
        XCTAssertTrue(staged.contains("Two changed"))
        XCTAssertEqual(try String(contentsOf: fileURL, encoding: .utf8), "One\nTwo changed\nThree\n")
    }

    func testFileHistoryAndWorktreeInventoryAreBounded() throws {
        let root = try makeRepository()
        defer { try? FileManager.default.removeItem(at: root) }
        let fileURL = root.appendingPathComponent("README.md")

        let history = try GitService.fileHistory(for: fileURL, workspaceRoot: root, limit: 5)
        let worktrees = GitService.worktrees(for: root)

        XCTAssertEqual(history.count, 1)
        XCTAssertEqual(history.first?.summary, "Initial")
        XCTAssertEqual(worktrees.count, 1)
        XCTAssertEqual(
            URL(fileURLWithPath: worktrees.first?.path ?? "").resolvingSymlinksInPath().path,
            root.resolvingSymlinksInPath().path
        )
    }

    private func makeRepository() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        _ = try CommandExecutionService.runString("/usr/bin/git", arguments: ["init", root.path])
        _ = try CommandExecutionService.runString("/usr/bin/git", arguments: ["-C", root.path, "config", "user.email", "forge@example.com"])
        _ = try CommandExecutionService.runString("/usr/bin/git", arguments: ["-C", root.path, "config", "user.name", "ForgeText"])
        let fileURL = root.appendingPathComponent("README.md")
        try "One\nTwo\nThree\n".write(to: fileURL, atomically: true, encoding: .utf8)
        _ = try CommandExecutionService.runString("/usr/bin/git", arguments: ["-C", root.path, "add", "README.md"])
        _ = try CommandExecutionService.runString("/usr/bin/git", arguments: ["-C", root.path, "commit", "-m", "Initial"])
        return root
    }
}
