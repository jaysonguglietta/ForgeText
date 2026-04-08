import XCTest
@testable import ForgeText

final class WorkspaceExplorerServiceTests: XCTestCase {
    func testLoadTreeRespectsHiddenFilesAndFavorites() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let visibleFile = root.appendingPathComponent("notes.txt")
        let hiddenFile = root.appendingPathComponent(".secret")
        let folder = root.appendingPathComponent("Configs", isDirectory: true)
        let favoriteFile = folder.appendingPathComponent("app.conf")

        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try "notes".write(to: visibleFile, atomically: true, encoding: .utf8)
        try "hidden".write(to: hiddenFile, atomically: true, encoding: .utf8)
        try "port=8080".write(to: favoriteFile, atomically: true, encoding: .utf8)

        let nodes = WorkspaceExplorerService.loadTree(
            rootURL: root,
            includeHiddenFiles: false,
            favoritePaths: [favoriteFile.path]
        )

        XCTAssertEqual(nodes.count, 1)
        let rootNode = try XCTUnwrap(nodes.first)
        XCTAssertFalse(rootNode.children.contains(where: { $0.name == ".secret" }))
        XCTAssertTrue(rootNode.children.contains(where: { $0.name == "Configs" }))

        let configsNode = try XCTUnwrap(rootNode.children.first(where: { $0.name == "Configs" }))
        XCTAssertTrue(configsNode.children.contains(where: { $0.name == "app.conf" && $0.isFavorite }))
    }

    func testFilteredNodesKeepsMatchingBranchContext() {
        let leaf = WorkspaceExplorerNode(
            id: "/tmp/project/configs/app.conf",
            name: "app.conf",
            url: URL(fileURLWithPath: "/tmp/project/configs/app.conf"),
            isDirectory: false,
            isHidden: false,
            isFavorite: false,
            children: []
        )
        let branch = WorkspaceExplorerNode(
            id: "/tmp/project/configs",
            name: "configs",
            url: URL(fileURLWithPath: "/tmp/project/configs"),
            isDirectory: true,
            isHidden: false,
            isFavorite: false,
            children: [leaf]
        )
        let root = WorkspaceExplorerNode(
            id: "/tmp/project",
            name: "project",
            url: URL(fileURLWithPath: "/tmp/project"),
            isDirectory: true,
            isHidden: false,
            isFavorite: false,
            children: [branch]
        )

        let filtered = WorkspaceExplorerService.filteredNodes([root], matching: "app.conf")

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.children.first?.name, "configs")
        XCTAssertEqual(filtered.first?.children.first?.children.first?.name, "app.conf")
    }
}
