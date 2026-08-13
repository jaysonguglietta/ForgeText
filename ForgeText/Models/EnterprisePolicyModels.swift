import Foundation

struct EnterpriseManagedPolicy: Codable, Hashable {
    var version = 1
    var organizationName = ""
    var notes = ""
    var features = EnterpriseManagedFeaturePolicy()
    var ai = EnterpriseManagedAIPolicy()
    var plugins = EnterpriseManagedPluginPolicy()
    var remote = EnterpriseManagedRemotePolicy()
    var updates = EnterpriseManagedUpdatePolicy()
    var support = EnterpriseManagedSupportPolicy()
    var signature: SignedArtifactSignature?
}

struct SignedArtifactSignature: Codable, Hashable {
    var algorithm = "ed25519"
    var keyID: String?
    var publicKey: String
    var value: String
    var signedAt: Date?
}

enum EnterpriseUpdateRing: String, Codable, CaseIterable, Identifiable {
    case stable
    case beta
    case internalRing = "internal"

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

struct EnterpriseManagedPluginCatalog: Codable, Hashable {
    var name: String
    var source: String
    var trustedSigningKeys: [String]?
    var allowsTaskPlugins: Bool?
}

struct EnterpriseApprovedAIProvider: Codable, Hashable, Identifiable {
    var id: UUID
    var name: String
    var kind: AIProviderKind
    var connectionMode: AIProviderConnectionMode
    var baseURLString: String
    var model: String
    var temperature: Double?
}

struct EnterpriseManagedFeaturePolicy: Codable, Hashable {
    var allowEmbeddedTerminal = true
    var allowWorkspaceTasks = true
    var allowExternalFormatters: Bool?
    var allowHTTPRequestRunner: Bool?
    var allowPrivateNetworkRequests: Bool?
    var allowedHTTPRequestHosts: [String]?
    var allowLanguageServers: Bool?
    var allowDebugAdapters: Bool?
    var allowDevContainers: Bool?
    var allowGitHubIntegration: Bool?
}

struct EnterpriseManagedAIPolicy: Codable, Hashable {
    var isEnabled = true
    var allowsCloudProviders = true
    var allowsLocalModels = true
    var allowsSelectionContext = true
    var allowsCurrentDocumentContext = true
    var allowsWorkspaceRulesContext = true
    var allowedProviderKinds: [AIProviderKind] = []
    var allowedModelPrefixes: [String] = []
    var allowedEndpointHosts: [String]?
    var approvedProviders: [EnterpriseApprovedAIProvider]?
    var enforceApprovedProviders: Bool?
}

struct EnterpriseManagedPluginPolicy: Codable, Hashable {
    var allowWorkspacePlugins = false
    var allowUserInstalledPlugins = true
    var allowCustomRegistries = true
    var allowsFileRegistries = true
    var allowTaskCapablePlugins = true
    var allowedRegistryHosts: [String] = []
    var allowedPluginAuthors: [String] = []
    var requireSignedPlugins: Bool?
    var allowedPluginSigningKeys: [String]?
    var allowedPluginManifestDigests: [String]?
    var allowedTaskExecutables: [String]?
    var managedCatalogs: [EnterpriseManagedPluginCatalog]?
}

struct EnterpriseManagedRemotePolicy: Codable, Hashable {
    var allowRemoteFiles = true
    var allowRemoteSearch = true
    var allowRemoteCommands = false
    var allowRemoteAgentInstall = false
}

struct EnterpriseManagedUpdatePolicy: Codable, Hashable {
    var allowUpdateChecks = true
    var ring: EnterpriseUpdateRing?
    var feedURL: String?
    var allowedFeedHosts: [String]?
}

struct EnterpriseManagedSupportPolicy: Codable, Hashable {
    var allowDiagnosticBundles = true
    var includePolicySummaryInDiagnostics = true
    var allowAuditExport: Bool?
    var auditRetentionDays: Int?
    var includeActivityDetailsInAudit: Bool?
}

struct ManagedPolicyState: Hashable {
    var policy: EnterpriseManagedPolicy?
    var sourcePath: String?
    var loadError: String?
    var loadedAt = Date()
    var canonicalSHA256: String?
    var verifiedSigningKey: String?

    var isManaged: Bool {
        sourcePath != nil
    }

    var isValid: Bool {
        policy != nil && loadError == nil
    }

    var hasVerifiedSignature: Bool {
        verifiedSigningKey != nil
    }
}

extension EnterpriseManagedPolicy {
    static var failClosed: EnterpriseManagedPolicy {
        var policy = EnterpriseManagedPolicy()
        policy.organizationName = "Invalid managed policy"
        policy.notes = "ForgeText denied managed capabilities because the policy file could not be validated."
        policy.features.allowEmbeddedTerminal = false
        policy.features.allowWorkspaceTasks = false
        policy.features.allowExternalFormatters = false
        policy.features.allowHTTPRequestRunner = false
        policy.features.allowPrivateNetworkRequests = false
        policy.features.allowedHTTPRequestHosts = []
        policy.features.allowLanguageServers = false
        policy.features.allowDebugAdapters = false
        policy.features.allowDevContainers = false
        policy.features.allowGitHubIntegration = false
        policy.ai.isEnabled = false
        policy.ai.allowsCloudProviders = false
        policy.ai.allowsLocalModels = false
        policy.ai.allowsSelectionContext = false
        policy.ai.allowsCurrentDocumentContext = false
        policy.ai.allowsWorkspaceRulesContext = false
        policy.ai.allowedEndpointHosts = []
        policy.plugins.allowWorkspacePlugins = false
        policy.plugins.allowUserInstalledPlugins = false
        policy.plugins.allowCustomRegistries = false
        policy.plugins.allowsFileRegistries = false
        policy.plugins.allowTaskCapablePlugins = false
        policy.plugins.requireSignedPlugins = true
        policy.plugins.allowedPluginSigningKeys = []
        policy.plugins.allowedPluginManifestDigests = []
        policy.plugins.allowedTaskExecutables = []
        policy.remote.allowRemoteFiles = false
        policy.remote.allowRemoteSearch = false
        policy.remote.allowRemoteCommands = false
        policy.remote.allowRemoteAgentInstall = false
        policy.updates.allowUpdateChecks = false
        policy.support.allowDiagnosticBundles = false
        policy.support.includePolicySummaryInDiagnostics = false
        return policy
    }
}
