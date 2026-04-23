import XCTest
@testable import ForgeText

final class PluginInfrastructureTests: XCTestCase {
    func testLegacySettingsDecodeDefaultsPluginIDs() throws {
        let json = """
        {
          "theme": "forge",
          "wrapLines": true,
          "autosaveToDisk": true,
          "fontSize": 15,
          "showsOutline": true,
          "showsBreadcrumbs": true,
          "savedLogFilters": []
        }
        """

        let data = Data(json.utf8)
        let settings = try JSONDecoder().decode(AppSettings.self, from: data)

        XCTAssertEqual(settings.enabledPluginIDs, PluginHostService.defaultEnabledPluginIDs)
    }

    func testAIProviderEncodingOmitsAPIKey() throws {
        let provider = AIProviderConfiguration(
            name: "Example",
            kind: .openAI,
            baseURLString: "https://api.example.com",
            model: "example-model",
            apiKey: "sk-test-secret"
        )

        let data = try JSONEncoder().encode(provider)
        let json = String(data: data, encoding: .utf8) ?? ""

        XCTAssertFalse(json.contains("apiKey"))
        XCTAssertFalse(json.contains("sk-test-secret"))
    }

    func testSnippetCatalogFiltersByLanguage() {
        var settings = AppSettings()
        settings.enabledPluginIDs = PluginHostService.defaultEnabledPluginIDs

        let jsonSnippets = PluginHostService.snippets(for: .json, using: settings, workspaceRoot: nil)
        let markdownSnippets = PluginHostService.snippets(for: .markdown, using: settings, workspaceRoot: nil)

        XCTAssertTrue(jsonSnippets.contains(where: { $0.title == "JSON Object" }))
        XCTAssertTrue(markdownSnippets.contains(where: { $0.title == "Checklist" }))
        XCTAssertFalse(jsonSnippets.contains(where: { $0.title == "Checklist" }))
    }

    func testDiagnosticsFindInvalidJSONAndTodoMarkers() {
        let document = EditorDocument(
            id: UUID(),
            untitledName: "broken.json",
            text: "{\n  \"name\": \"ForgeText\",\n  TODO\n}\n",
            fileURL: URL(fileURLWithPath: "/tmp/broken.json"),
            remoteReference: nil,
            encoding: .utf8,
            includesByteOrderMark: false,
            lineEnding: .lf,
            selectedRange: NSRange(location: 0, length: 0),
            isDirty: true,
            lastSavedText: "",
            language: .json,
            findState: .init(),
            hasExternalChanges: false,
            fileMissingOnDisk: false,
            hasRecoveredDraft: false,
            lastKnownDiskFingerprint: nil,
            lastSavedAt: nil,
            statusMessage: nil
        )

        let diagnostics = PluginDiagnosticsService.diagnostics(for: document)

        XCTAssertTrue(diagnostics.contains(where: { $0.source == "JSON" && $0.severity == .error }))
        XCTAssertTrue(diagnostics.contains(where: { $0.source == "Task Marker" && $0.severity == .info }))
    }

    func testWorkspaceTaskDetectionFindsSwiftAndNodeTasks() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try "import PackageDescription\n".write(to: root.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        try """
        {
          "name": "forge-demo",
          "scripts": {
            "build": "vite build",
            "test": "vitest",
            "lint": "eslint ."
          }
        }
        """.write(to: root.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)

        let tasks = WorkspaceTaskService.detectTasks(rootURL: root)

        XCTAssertTrue(tasks.contains(where: { $0.title == "Swift Build" }))
        XCTAssertTrue(tasks.contains(where: { $0.title == "Swift Test" }))
        XCTAssertTrue(tasks.contains(where: { $0.title == "npm build" }))
        XCTAssertTrue(tasks.contains(where: { $0.title == "npm test" }))
        XCTAssertTrue(tasks.contains(where: { $0.title == "npm lint" }))
    }

    func testPluginFormatterPrettyPrintsJSON() throws {
        let document = EditorDocument(
            id: UUID(),
            untitledName: "sample.json",
            text: #"{"b":1,"a":2}"#,
            fileURL: URL(fileURLWithPath: "/tmp/sample.json"),
            remoteReference: nil,
            encoding: .utf8,
            includesByteOrderMark: false,
            lineEnding: .lf,
            selectedRange: NSRange(location: 0, length: 0),
            isDirty: true,
            lastSavedText: "",
            language: .json,
            findState: .init(),
            hasExternalChanges: false,
            fileMissingOnDisk: false,
            hasRecoveredDraft: false,
            lastKnownDiskFingerprint: nil,
            lastSavedAt: nil,
            statusMessage: nil
        )

        let formatted = try PluginFormattingService.format(document)

        XCTAssertTrue(formatted.contains(#""a" : 2"#) || formatted.contains(#""a": 2"#))
        XCTAssertTrue(formatted.contains("\n"))
    }

    func testDiagnosticsDetectLikelySecrets() {
        let document = EditorDocument(
            id: UUID(),
            untitledName: "secrets.env",
            text: """
            API_KEY=supersecret123
            Authorization: Bearer abcdefghijklmnopqrstuvwxyz
            """,
            fileURL: URL(fileURLWithPath: "/tmp/secrets.env"),
            remoteReference: nil,
            encoding: .utf8,
            includesByteOrderMark: false,
            lineEnding: .lf,
            selectedRange: NSRange(location: 0, length: 0),
            isDirty: true,
            lastSavedText: "",
            language: .config,
            findState: .init(),
            hasExternalChanges: false,
            fileMissingOnDisk: false,
            hasRecoveredDraft: false,
            lastKnownDiskFingerprint: nil,
            lastSavedAt: nil,
            statusMessage: nil
        )

        let diagnostics = PluginDiagnosticsService.diagnostics(for: document)

        XCTAssertTrue(diagnostics.contains(where: { $0.source == "Secrets" && $0.message.contains("credential or secret assignment") }))
        XCTAssertTrue(diagnostics.contains(where: { $0.source == "Secrets" && $0.message.contains("Bearer token") }))
    }
}
