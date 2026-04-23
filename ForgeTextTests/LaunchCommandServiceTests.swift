import XCTest
@testable import ForgeText

final class LaunchCommandServiceTests: XCTestCase {
    func testParseCapturesWorkspaceProfileAndDiff() {
        let plan = LaunchCommandService.parse(arguments: [
            "--workspace", "/tmp/ops.forgetext-workspace",
            "--profile", "Ops",
            "--diff", "/tmp/left.txt", "/tmp/right.txt",
        ])

        XCTAssertEqual(plan.workspaceFileURL?.path, "/tmp/ops.forgetext-workspace")
        XCTAssertEqual(plan.profileName, "Ops")
        XCTAssertEqual(plan.diffRequest?.leftURL.path, "/tmp/left.txt")
        XCTAssertEqual(plan.diffRequest?.rightURL.path, "/tmp/right.txt")
    }

    func testParseCapturesLineTargetsAndDeduplicatesFileURLs() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let fileURL = root.appendingPathComponent("main.swift")
        try "print(\"forge\")\n".write(to: fileURL, atomically: true, encoding: .utf8)

        let plan = LaunchCommandService.parse(arguments: [
            "\(fileURL.path):42",
            fileURL.path,
        ])

        XCTAssertEqual(plan.lineTarget?.fileURL.path, fileURL.standardizedFileURL.path)
        XCTAssertEqual(plan.lineTarget?.lineNumber, 42)
        XCTAssertEqual(plan.fileURLs.map(\.path), [fileURL.standardizedFileURL.path])
    }

    func testRemoteFileReferenceRejectsOptionLikeSSHConnections() {
        XCTAssertNotNil(RemoteFileReference.parse("deploy@example.com:/var/log/syslog"))
        XCTAssertNil(RemoteFileReference.parse("-oProxyCommand=touch /tmp/pwn:/etc/passwd"))
        XCTAssertNil(RemoteFileReference.parse("deploy user@example.com:/etc/passwd"))
        XCTAssertNil(RemoteFileReference.parse("../example.com:/etc/passwd"))
    }
}
