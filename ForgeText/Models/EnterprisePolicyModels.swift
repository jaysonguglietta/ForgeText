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
}

struct EnterpriseManagedFeaturePolicy: Codable, Hashable {
    var allowEmbeddedTerminal = true
    var allowWorkspaceTasks = true
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
}

struct EnterpriseManagedPluginPolicy: Codable, Hashable {
    var allowWorkspacePlugins = false
    var allowUserInstalledPlugins = true
    var allowCustomRegistries = true
    var allowsFileRegistries = true
    var allowTaskCapablePlugins = true
    var allowedRegistryHosts: [String] = []
    var allowedPluginAuthors: [String] = []
}

struct EnterpriseManagedRemotePolicy: Codable, Hashable {
    var allowRemoteFiles = true
    var allowRemoteSearch = true
    var allowRemoteCommands = false
    var allowRemoteAgentInstall = false
}

struct EnterpriseManagedUpdatePolicy: Codable, Hashable {
    var allowUpdateChecks = true
}

struct EnterpriseManagedSupportPolicy: Codable, Hashable {
    var allowDiagnosticBundles = true
    var includePolicySummaryInDiagnostics = true
}

struct ManagedPolicyState: Hashable {
    var policy: EnterpriseManagedPolicy?
    var sourcePath: String?
    var loadError: String?
    var loadedAt = Date()

    var isManaged: Bool {
        policy != nil
    }
}
