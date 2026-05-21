import XCTest
@testable import ForgeText

final class EnterprisePolicyServiceTests: XCTestCase {
    func testLoadStateReadsManagedPolicyFile() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let policyURL = root.appendingPathComponent("managed-policy.json")
        let policy = EnterpriseManagedPolicy(
            organizationName: "Acme Ops",
            notes: "Local models only."
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(policy).write(to: policyURL, options: .atomic)

        let state = EnterprisePolicyService.loadState(policyFileURL: policyURL)

        XCTAssertTrue(state.isManaged)
        XCTAssertEqual(state.policy?.organizationName, "Acme Ops")
        XCTAssertEqual(state.sourcePath, policyURL.path)
        XCTAssertNil(state.loadError)
    }

    func testAIRestrictionBlocksCloudProvidersWhenPolicyRequiresLocalModels() {
        var policy = EnterpriseManagedPolicy()
        policy.ai.allowsCloudProviders = false

        let provider = AIProviderConfiguration(
            name: "OpenAI",
            kind: .openAI,
            connectionMode: .bringYourOwnKey,
            baseURLString: "https://api.openai.com",
            model: "gpt-5.4"
        )

        let reason = EnterprisePolicyService.aiRestrictionReason(for: provider, policy: policy)

        XCTAssertNotNil(reason)
        XCTAssertTrue(reason?.localizedCaseInsensitiveContains("local model") == true)
    }

    func testWorkspaceLocalPluginBlockedWhenPolicyDisallowsWorkspacePlugins() {
        let workspaceRoot = URL(fileURLWithPath: "/tmp/forge-enterprise", isDirectory: true)
        let workspacePluginURL = workspaceRoot
            .appendingPathComponent(".forgetext", isDirectory: true)
            .appendingPathComponent("plugins", isDirectory: true)
            .appendingPathComponent("demo.json", isDirectory: false)

        let plugin = EditorPlugin(
            manifest: EditorPluginManifest(
                id: "demo.workspace",
                name: "Workspace Demo",
                version: "1.0.0",
                author: "Acme",
                summary: "Workspace plugin",
                category: .workspaceAutomation,
                capabilities: [.commands],
                isBuiltIn: false,
                sourceDescription: workspacePluginURL.path,
                defaultEnabled: false
            ),
            commands: [],
            snippets: [],
            tasks: []
        )

        var policy = EnterpriseManagedPolicy()
        policy.plugins.allowWorkspacePlugins = false

        let reason = EnterprisePolicyService.pluginRestrictionReason(
            plugin,
            workspaceRoots: [workspaceRoot],
            policy: policy
        )

        XCTAssertNotNil(reason)
        XCTAssertTrue(reason?.localizedCaseInsensitiveContains("workspace-local") == true)
    }

    func testRegistrySourceAllowlistBlocksUnapprovedHosts() {
        var policy = EnterpriseManagedPolicy()
        policy.plugins.allowedRegistryHosts = ["plugins.example.com"]

        let reason = EnterprisePolicyService.registrySourceRestrictionReason(
            "https://malicious.example.net/registry.json",
            policy: policy
        )

        XCTAssertNotNil(reason)
        XCTAssertTrue(reason?.localizedCaseInsensitiveContains("approved hosts") == true)
    }
}
