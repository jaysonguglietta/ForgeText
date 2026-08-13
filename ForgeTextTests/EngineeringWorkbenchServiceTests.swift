import XCTest
@testable import ForgeText

final class EngineeringWorkbenchServiceTests: XCTestCase {
    func testLanguageSymbolUsesSelectionAndCursorWord() {
        let text = "let serviceName = buildService()"
        let selected = NSRange(location: 4, length: 11)
        XCTAssertEqual(LanguageIntelligenceService.symbol(at: selected, in: text), "serviceName")

        let cursor = NSRange(location: 24, length: 0)
        XCTAssertEqual(LanguageIntelligenceService.symbol(at: cursor, in: text), "buildService")
    }

    func testLanguageNavigationFindsDefinitionsAndReferences() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let fileURL = root.appendingPathComponent("Service.swift")
        try "func buildService() {}\nlet value = buildService()\n".write(to: fileURL, atomically: true, encoding: .utf8)
        let entry = WorkspaceIndexEntry(
            id: fileURL.path,
            url: fileURL,
            rootPath: root.path,
            relativePath: "Service.swift",
            language: .swift,
            lineCount: 2,
            byteCount: 51,
            symbolCount: 1,
            todoCount: 0,
            warningCount: 0,
            isLikelyConfig: false,
            modifiedAt: nil
        )
        let symbol = WorkspaceSymbolEntry(
            id: "service",
            title: "buildService",
            detail: "func buildService()",
            fileURL: fileURL,
            relativePath: "Service.swift",
            language: .swift,
            lineNumber: 1,
            level: 0
        )
        var index = WorkspaceIndexSummary.empty
        index.entries = [entry]
        index.symbols = [symbol]

        let hits = LanguageIntelligenceService.navigationHits(for: "buildService", index: index)

        XCTAssertEqual(hits.filter { $0.kind == .definition }.count, 1)
        XCTAssertEqual(hits.filter { $0.kind == .reference }.count, 2)
    }

    func testTestDiscoveryRecognizesSwiftPythonAndJavaScriptTests() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let fixtures: [(String, DocumentLanguage, String)] = [
            ("Tests/ServiceTests.swift", .swift, "func testServiceStarts() {}\n"),
            ("tests/test_api.py", .python, "def test_api_health():\n    pass\n"),
            ("src/app.test.js", .javascript, "test('renders dashboard', () => {})\n"),
        ]
        var entries: [WorkspaceIndexEntry] = []
        for fixture in fixtures {
            let url = root.appendingPathComponent(fixture.0)
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fixture.2.write(to: url, atomically: true, encoding: .utf8)
            entries.append(
                WorkspaceIndexEntry(
                    id: url.path,
                    url: url,
                    rootPath: root.path,
                    relativePath: fixture.0,
                    language: fixture.1,
                    lineCount: 2,
                    byteCount: Int64(fixture.2.utf8.count),
                    symbolCount: 0,
                    todoCount: 0,
                    warningCount: 0,
                    isLikelyConfig: false,
                    modifiedAt: nil
                )
            )
        }
        var index = WorkspaceIndexSummary.empty
        index.entries = entries

        let tests = TestDiscoveryService.discover(in: index)

        XCTAssertEqual(Set(tests.map(\.name)), ["testServiceStarts", "test_api_health", "renders dashboard"])
    }

    func testAIChangeSetRequiresExplicitHunkApproval() throws {
        let response = """
        ```diff
        diff --git a/README.md b/README.md
        --- a/README.md
        +++ b/README.md
        @@ -1 +1 @@
        -Old
        +New
        ```
        """

        var changeSet = try AIChangeSetService.parse(response: response)
        XCTAssertEqual(changeSet.hunkCount, 1)
        XCTAssertThrowsError(try AIChangeSetService.approvedPatch(for: changeSet))

        changeSet.files[0].hunks[0].isApproved = true
        let patch = try AIChangeSetService.approvedPatch(for: changeSet)
        XCTAssertTrue(patch.contains("diff --git a/README.md b/README.md"))
        XCTAssertTrue(patch.contains("+New"))
    }

    func testAIChangeSetRejectsTraversalPaths() {
        let response = """
        diff --git a/../outside.txt b/../outside.txt
        --- a/../outside.txt
        +++ b/../outside.txt
        @@ -1 +1 @@
        -Old
        +New
        """

        XCTAssertThrowsError(try AIChangeSetService.parse(response: response)) { error in
            guard case AIChangeSetService.ChangeSetError.unsafePath = error else {
                return XCTFail("Expected unsafe path error, got \(error)")
            }
        }
    }

    func testForcedMDMPolicyLoadsAndUnforcedValueIsIgnored() throws {
        var policy = EnterpriseManagedPolicy()
        policy.organizationName = "Acme Managed"
        let json = String(data: try JSONEncoder().encode(policy), encoding: .utf8)!

        let ignored = EnterprisePolicyService.loadManagedPolicyJSON(json, isForced: false)
        XCTAssertFalse(ignored.isManaged)

        let loaded = EnterprisePolicyService.loadManagedPolicyJSON(json, isForced: true)
        XCTAssertTrue(loaded.isManaged)
        XCTAssertEqual(loaded.policy?.organizationName, "Acme Managed")
        XCTAssertEqual(loaded.sourcePath, "mdm://ManagedPolicyJSON")
    }
}
