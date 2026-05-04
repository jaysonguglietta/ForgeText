import XCTest
@testable import ForgeText

final class ExternalPluginServiceTests: XCTestCase {
    func testDiscoverPluginsLoadsWorkspaceManifest() throws {
        let workspaceRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let pluginDirectory = workspaceRoot
            .appendingPathComponent(".forgetext", isDirectory: true)
            .appendingPathComponent("plugins", isDirectory: true)

        try FileManager.default.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workspaceRoot) }

        let manifestURL = pluginDirectory.appendingPathComponent("demo.json")
        try """
        {
          "id": "demo.http-tools",
          "name": "HTTP Tools",
          "version": "1.0.0",
          "author": "ForgeText",
          "summary": "Adds HTTP helpers.",
          "category": "languageTools",
          "capabilities": ["snippets", "tasks", "languagePacks"],
          "defaultEnabled": false,
          "snippets": [
            {
              "id": "demo.http-snippet",
              "title": "Health Check",
              "detail": "Insert a health endpoint request.",
              "symbolName": "network",
              "languages": ["http"],
              "body": "GET https://example.com/health"
            }
          ],
          "tasks": [
            {
              "id": "demo.http-test",
              "title": "Run HTTP Smoke",
              "subtitle": "Execute smoke checks",
              "symbolName": "play",
              "executable": "echo",
              "arguments": ["smoke"],
              "workingDirectory": "workspaceRoot",
              "role": "run"
            }
          ]
        }
        """.write(to: manifestURL, atomically: true, encoding: .utf8)

        let plugins = ExternalPluginService.discoverPlugins(workspaceRoot: workspaceRoot)

        XCTAssertEqual(plugins.count, 1)
        XCTAssertEqual(plugins.first?.manifest.id, "demo.http-tools")
        XCTAssertEqual(plugins.first?.manifest.defaultEnabled, false)
        XCTAssertTrue(plugins.first?.manifest.capabilities.contains(.languagePacks) == true)
        XCTAssertEqual(plugins.first?.snippets.first?.languages, [.http])
        XCTAssertEqual(plugins.first?.tasks.first?.role, .run)
    }

    func testDiscoverPluginsDefaultsWorkspacePluginsToDisabled() throws {
        let workspaceRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let pluginDirectory = workspaceRoot
            .appendingPathComponent(".forgetext", isDirectory: true)
            .appendingPathComponent("plugins", isDirectory: true)

        try FileManager.default.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workspaceRoot) }

        let manifestURL = pluginDirectory.appendingPathComponent("demo.json")
        try """
        {
          "id": "demo.default-off",
          "name": "Default Off",
          "version": "1.0.0",
          "author": "ForgeText",
          "summary": "Workspace plugin without an explicit default.",
          "category": "snippets",
          "capabilities": ["snippets"],
          "snippets": []
        }
        """.write(to: manifestURL, atomically: true, encoding: .utf8)

        let plugins = ExternalPluginService.discoverPlugins(workspaceRoot: workspaceRoot)

        XCTAssertEqual(plugins.first?.manifest.defaultEnabled, false)
    }

    func testDiscoverPluginsDropsUnsafeTaskExecutables() throws {
        let workspaceRoot = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let pluginDirectory = workspaceRoot
            .appendingPathComponent(".forgetext", isDirectory: true)
            .appendingPathComponent("plugins", isDirectory: true)

        try FileManager.default.createDirectory(at: pluginDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: workspaceRoot) }

        let manifestURL = pluginDirectory.appendingPathComponent("unsafe.json")
        try """
        {
          "id": "demo.unsafe-task",
          "name": "Unsafe Task",
          "version": "1.0.0",
          "author": "ForgeText",
          "summary": "Contains a repo-local executable path.",
          "category": "workspaceAutomation",
          "capabilities": ["tasks"],
          "tasks": [
            {
              "id": "demo.bad-task",
              "title": "Unsafe",
              "subtitle": "Should be rejected",
              "symbolName": "xmark.octagon",
              "executable": "./payload",
              "arguments": [],
              "workingDirectory": "workspaceRoot",
              "role": "run"
            }
          ]
        }
        """.write(to: manifestURL, atomically: true, encoding: .utf8)

        let plugins = ExternalPluginService.discoverPlugins(workspaceRoot: workspaceRoot)

        XCTAssertEqual(plugins.first?.tasks, [])
        XCTAssertFalse(plugins.first?.manifest.capabilities.contains(.tasks) == true)
    }
}
