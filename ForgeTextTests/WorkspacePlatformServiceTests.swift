import XCTest
@testable import ForgeText

final class WorkspacePlatformServiceTests: XCTestCase {
    func testWorkspaceFileRoundTripPreservesRootsActiveRootAndProfile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let repoA = root.appendingPathComponent("RepoA", isDirectory: true)
        let repoB = root.appendingPathComponent("RepoB", isDirectory: true)
        try FileManager.default.createDirectory(at: repoA, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: repoB, withIntermediateDirectories: true)

        let workspaceURL = root.appendingPathComponent("Ops.forgetext-workspace")
        let profileID = UUID()
        let descriptor = WorkspacePlatformService.descriptor(
            name: "",
            roots: [repoA, repoB, repoA],
            activeRoot: repoB,
            workspaceFileURL: workspaceURL,
            selectedProfileID: profileID
        )

        try WorkspacePlatformService.saveWorkspace(descriptor, to: workspaceURL)
        let loaded = try WorkspacePlatformService.loadWorkspace(from: workspaceURL)

        XCTAssertEqual(loaded.name, "RepoA +1")
        XCTAssertEqual(loaded.rootURLs.map(\.path), [repoA.standardizedFileURL.path, repoB.standardizedFileURL.path])
        XCTAssertEqual(loaded.activeRootURL?.path, repoB.standardizedFileURL.path)
        XCTAssertEqual(loaded.workspaceFileURL?.path, workspaceURL.standardizedFileURL.path)
        XCTAssertEqual(loaded.selectedProfileID, profileID)
    }

    func testTrustModeRequiresEveryRootToBeTrusted() {
        let repoA = URL(fileURLWithPath: "/tmp/forge-A", isDirectory: true)
        let repoB = URL(fileURLWithPath: "/tmp/forge-B", isDirectory: true)
        var settings = AppSettings()

        WorkspacePlatformService.markTrusted(roots: [repoA], settings: &settings)
        XCTAssertEqual(WorkspacePlatformService.trustMode(for: [repoA, repoB], settings: settings), .restricted)

        WorkspacePlatformService.markTrusted(roots: [repoB], settings: &settings)
        XCTAssertEqual(WorkspacePlatformService.trustMode(for: [repoA, repoB], settings: settings), .trusted)

        WorkspacePlatformService.markRestricted(roots: [repoA], settings: &settings)
        XCTAssertEqual(WorkspacePlatformService.trustMode(for: [repoA, repoB], settings: settings), .restricted)
    }
}
