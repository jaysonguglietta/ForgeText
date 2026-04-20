import XCTest
@testable import ForgeText

final class PluginRegistryServiceTests: XCTestCase {
    func testCatalogLoadsEnabledCustomRegistryEntries() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let registryURL = root.appendingPathComponent("registry.json")
        let registryJSON = """
        {
          "entries": [
            {
              "id": "example.registry-plugin",
              "name": "Example Registry Plugin",
              "version": "1.2.3",
              "author": "ForgeText",
              "summary": "Loads from a custom registry file.",
              "category": "snippets",
              "capabilities": ["snippets"],
              "defaultEnabled": true,
              "sourceDescription": "Example Registry",
              "snippets": [],
              "tasks": [],
              "installFileName": "example-registry-plugin.json"
            }
          ]
        }
        """
        try registryJSON.write(to: registryURL, atomically: true, encoding: .utf8)

        var settings = AppSettings()
        settings.pluginRegistries = [
            PluginRegistryConfiguration(name: "Example", source: registryURL.path, isEnabled: true)
        ]

        let catalog = await PluginRegistryService.catalog(using: settings)

        XCTAssertTrue(catalog.contains(where: { $0.id == "example.registry-plugin" }))
    }

    func testCatalogSkipsDisabledRegistryEntries() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let registryURL = root.appendingPathComponent("registry.json")
        let registryJSON = """
        {
          "entries": [
            {
              "id": "example.disabled-plugin",
              "name": "Disabled Registry Plugin",
              "version": "1.0.0",
              "author": "ForgeText",
              "summary": "Should not load when the registry is disabled.",
              "category": "snippets",
              "capabilities": ["snippets"],
              "defaultEnabled": true,
              "sourceDescription": "Disabled Registry",
              "snippets": [],
              "tasks": [],
              "installFileName": "disabled-registry-plugin.json"
            }
          ]
        }
        """
        try registryJSON.write(to: registryURL, atomically: true, encoding: .utf8)

        var settings = AppSettings()
        settings.pluginRegistries = [
            PluginRegistryConfiguration(name: "Disabled", source: registryURL.path, isEnabled: false)
        ]

        let catalog = await PluginRegistryService.catalog(using: settings)

        XCTAssertFalse(catalog.contains(where: { $0.id == "example.disabled-plugin" }))
    }

    func testInstallRejectsPathTraversalInstallFileNames() {
        let entry = PluginRegistryEntry(
            id: "example.unsafe-plugin",
            name: "Unsafe Plugin",
            version: "1.0.0",
            author: "ForgeText",
            summary: "Attempts to escape the plugin directory.",
            category: .snippets,
            capabilities: [.snippets],
            defaultEnabled: true,
            sourceDescription: "Unsafe Registry",
            snippets: [],
            tasks: [],
            installFileName: "../../tmp/unsafe-plugin.json"
        )

        XCTAssertThrowsError(try PluginRegistryService.install(entry))
    }
}
