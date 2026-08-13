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

    func testDiscoveredPolicyURLsPreferLocalDomainPolicyOverEnvironmentOverride() {
        let localDomainURL = URL(fileURLWithPath: "/Library/Application Support", isDirectory: true)
        let defaultPolicyURL = URL(fileURLWithPath: "/Users/test/ForgeText/managed-policy.json", isDirectory: false)
        let discovered = EnterprisePolicyService.discoveredPolicyURLs(
            environment: ["FORGETEXT_MANAGED_POLICY_FILE": "/tmp/override.json"],
            localDomainApplicationSupportURL: localDomainURL,
            defaultPolicyURL: defaultPolicyURL
        )

        XCTAssertEqual(
            discovered.map(\.path),
            [
                "/Library/Application Support/ForgeText/managed-policy.json",
                "/tmp/override.json",
                "/Users/test/ForgeText/managed-policy.json"
            ]
        )
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

    func testMalformedManagedPolicyFailsClosed() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let policyURL = root.appendingPathComponent("managed-policy.json")
        try Data("{not-json".utf8).write(to: policyURL, options: .atomic)

        let state = EnterprisePolicyService.loadState(policyFileURL: policyURL)

        XCTAssertTrue(state.isManaged)
        XCTAssertFalse(state.isValid)
        XCTAssertNotNil(state.loadError)
        XCTAssertEqual(state.policy?.ai.isEnabled, false)
        XCTAssertNotNil(EnterprisePolicyService.httpRequestRestrictionReason(policy: state.policy))
    }

    func testAIEndpointAllowlistDoesNotTrustSubdomains() {
        var policy = EnterpriseManagedPolicy()
        policy.ai.allowedEndpointHosts = ["gateway.example.com"]
        let provider = AIProviderConfiguration(
            name: "Unapproved subdomain",
            kind: .openAICompatible,
            connectionMode: .bringYourOwnKey,
            baseURLString: "https://attacker.gateway.example.com",
            model: "gateway-model"
        )

        XCTAssertNotNil(EnterprisePolicyService.aiRestrictionReason(for: provider, policy: policy))
    }

    func testApprovedAIProviderProfilesRequireAnExactMatch() {
        let id = UUID()
        let approved = EnterpriseApprovedAIProvider(
            id: id,
            name: "Acme Gateway",
            kind: .openAICompatible,
            connectionMode: .bringYourOwnKey,
            baseURLString: "https://ai.example.com/v1",
            model: "acme-secure",
            temperature: 0.2
        )
        var policy = EnterpriseManagedPolicy()
        policy.ai.approvedProviders = [approved]
        policy.ai.enforceApprovedProviders = true
        let matching = AIProviderConfiguration(
            id: id,
            name: "Acme Gateway",
            kind: .openAICompatible,
            connectionMode: .bringYourOwnKey,
            baseURLString: approved.baseURLString,
            model: approved.model
        )
        var modified = matching
        modified.model = "unapproved-model"

        XCTAssertNil(EnterprisePolicyService.aiRestrictionReason(for: matching, policy: policy))
        XCTAssertNotNil(EnterprisePolicyService.aiRestrictionReason(for: modified, policy: policy))
    }

    func testOnlyVerifiedOrForcedPolicyCanRedirectUpdateFeed() {
        var policy = EnterpriseManagedPolicy()
        policy.updates.feedURL = "https://updates.example.com/appcast.xml"
        policy.updates.allowedFeedHosts = ["updates.example.com"]
        let unsigned = ManagedPolicyState(policy: policy, sourcePath: "/tmp/managed-policy.json")
        let verified = ManagedPolicyState(
            policy: policy,
            sourcePath: "/tmp/managed-policy.json",
            verifiedSigningKey: "trusted-key"
        )

        XCTAssertEqual(
            EnterprisePolicyService.managedUpdateFeedURL(state: unsigned, fallback: "https://public.example/appcast.xml"),
            "https://public.example/appcast.xml"
        )
        XCTAssertEqual(
            EnterprisePolicyService.managedUpdateFeedURL(state: verified, fallback: nil),
            "https://updates.example.com/appcast.xml"
        )
    }
}
