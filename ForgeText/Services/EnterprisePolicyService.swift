import Foundation

enum EnterprisePolicyService {
    enum PluginOrigin: String {
        case builtIn
        case workspaceLocal
        case userInstalled
        case externalUnknown
    }

    private static let envPathKey = "FORGETEXT_MANAGED_POLICY_FILE"
    private static let filename = "managed-policy.json"

    static func loadState(policyFileURL: URL? = nil) -> ManagedPolicyState {
        let resolvedURL: URL?
        if let policyFileURL {
            resolvedURL = policyFileURL.standardizedFileURL
        } else {
            resolvedURL = discoveredPolicyURLs().first(where: { FileManager.default.fileExists(atPath: $0.path) })
        }

        guard let resolvedURL else {
            return ManagedPolicyState()
        }

        do {
            let data = try Data(contentsOf: resolvedURL)
            let policy = try JSONDecoder().decode(EnterpriseManagedPolicy.self, from: data)
            return ManagedPolicyState(
                policy: policy,
                sourcePath: resolvedURL.path,
                loadError: nil,
                loadedAt: Date()
            )
        } catch {
            return ManagedPolicyState(
                policy: nil,
                sourcePath: resolvedURL.path,
                loadError: error.localizedDescription,
                loadedAt: Date()
            )
        }
    }

    static func defaultPolicyFileURL() -> URL {
        StoragePathService.appDataDirectoryURL()
            .appendingPathComponent(filename, isDirectory: false)
            .standardizedFileURL
    }

    static func discoveredPolicyURLs(processInfo: ProcessInfo = .processInfo) -> [URL] {
        var urls: [URL] = []

        if let explicitPath = processInfo.environment[envPathKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !explicitPath.isEmpty {
            urls.append(URL(fileURLWithPath: explicitPath, isDirectory: false).standardizedFileURL)
        }

        if let localDomainURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .localDomainMask).first {
            urls.append(
                localDomainURL
                    .appendingPathComponent("ForgeText", isDirectory: true)
                    .appendingPathComponent(filename, isDirectory: false)
                    .standardizedFileURL
            )
        }

        urls.append(defaultPolicyFileURL())
        return urls
    }

    static func summaryLines(for state: ManagedPolicyState) -> [String] {
        if let loadError = state.loadError {
            return ["Policy file could not be loaded: \(loadError)"]
        }

        guard let policy = state.policy else {
            return [
                "No managed policy is active.",
                "Drop a \(filename) file into \(defaultPolicyFileURL().path) or set \(envPathKey)."
            ]
        }

        var lines: [String] = []
        lines.append(policy.organizationName.isEmpty ? "Managed policy is active." : "\(policy.organizationName) policy is active.")

        if !policy.ai.isEnabled {
            lines.append("AI features are disabled.")
        } else {
            if !policy.ai.allowsCloudProviders {
                lines.append("AI is restricted to local model endpoints.")
            }
            if !policy.ai.allowsSelectionContext || !policy.ai.allowsCurrentDocumentContext || !policy.ai.allowsWorkspaceRulesContext {
                var contextRules: [String] = []
                if !policy.ai.allowsSelectionContext {
                    contextRules.append("selection")
                }
                if !policy.ai.allowsCurrentDocumentContext {
                    contextRules.append("current file")
                }
                if !policy.ai.allowsWorkspaceRulesContext {
                    contextRules.append("workspace rules")
                }
                lines.append("AI context is limited: \(contextRules.joined(separator: ", ")).")
            }
        }

        var pluginRules: [String] = []
        if !policy.plugins.allowWorkspacePlugins {
            pluginRules.append("workspace plugins blocked")
        }
        if !policy.plugins.allowUserInstalledPlugins {
            pluginRules.append("user-installed plugins blocked")
        }
        if !policy.plugins.allowCustomRegistries {
            pluginRules.append("custom registries blocked")
        }
        if !policy.plugins.allowTaskCapablePlugins {
            pluginRules.append("task-capable plugins blocked")
        }
        if !pluginRules.isEmpty {
            lines.append("Plugins: \(pluginRules.joined(separator: "; ")).")
        }

        var remoteRules: [String] = []
        if !policy.remote.allowRemoteFiles {
            remoteRules.append("remote file access blocked")
        }
        if !policy.remote.allowRemoteSearch {
            remoteRules.append("remote search blocked")
        }
        if !policy.remote.allowRemoteCommands {
            remoteRules.append("remote commands blocked")
        }
        if !policy.remote.allowRemoteAgentInstall {
            remoteRules.append("remote agent install blocked")
        }
        if !remoteRules.isEmpty {
            lines.append("Remote: \(remoteRules.joined(separator: "; ")).")
        }

        var runtimeRules: [String] = []
        if !policy.features.allowWorkspaceTasks {
            runtimeRules.append("workspace tasks blocked")
        }
        if !policy.features.allowEmbeddedTerminal {
            runtimeRules.append("embedded terminal blocked")
        }
        if !policy.updates.allowUpdateChecks {
            runtimeRules.append("manual update checks blocked")
        }
        if !policy.support.allowDiagnosticBundles {
            runtimeRules.append("diagnostic bundle export blocked")
        }
        if !runtimeRules.isEmpty {
            lines.append("Runtime: \(runtimeRules.joined(separator: "; ")).")
        }

        if !policy.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            lines.append(policy.notes)
        }

        return lines
    }

    static func aiRestrictionReason(for provider: AIProviderConfiguration, policy: EnterpriseManagedPolicy?) -> String? {
        guard let policy else {
            return nil
        }

        guard policy.ai.isEnabled else {
            return "Managed policy disabled AI features for this ForgeText installation."
        }

        if !policy.ai.allowedProviderKinds.isEmpty,
           !policy.ai.allowedProviderKinds.contains(provider.kind) {
            return "Managed policy only allows specific AI provider types, and \(provider.kind.displayName) is not on the allowlist."
        }

        switch provider.effectiveConnectionMode {
        case .bringYourOwnKey:
            if !policy.ai.allowsCloudProviders {
                return "Managed policy only allows local model endpoints and blocks cloud AI providers."
            }
        case .localModel:
            if !policy.ai.allowsLocalModels {
                return "Managed policy blocks local model endpoints for this installation."
            }
        }

        let allowedModelPrefixes = policy.ai.allowedModelPrefixes
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        if !allowedModelPrefixes.isEmpty {
            let normalizedModel = provider.model.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let matches = allowedModelPrefixes.contains(where: { normalizedModel.hasPrefix($0) })
            if !matches {
                return "Managed policy only allows approved model names for AI requests."
            }
        }

        return nil
    }

    static func effectiveAIContextSelectionEnabled(_ isEnabled: Bool, policy: EnterpriseManagedPolicy?) -> Bool {
        isEnabled && (policy?.ai.allowsSelectionContext ?? true)
    }

    static func effectiveAICurrentDocumentEnabled(_ isEnabled: Bool, policy: EnterpriseManagedPolicy?) -> Bool {
        isEnabled && (policy?.ai.allowsCurrentDocumentContext ?? true)
    }

    static func effectiveAIWorkspaceRulesEnabled(_ isEnabled: Bool, policy: EnterpriseManagedPolicy?) -> Bool {
        isEnabled && (policy?.ai.allowsWorkspaceRulesContext ?? true)
    }

    static func taskExecutionRestrictionReason(policy: EnterpriseManagedPolicy?) -> String? {
        guard let policy, !policy.features.allowWorkspaceTasks else {
            return nil
        }

        return "Managed policy blocks workspace task execution in this ForgeText installation."
    }

    static func embeddedTerminalRestrictionReason(policy: EnterpriseManagedPolicy?) -> String? {
        guard let policy, !policy.features.allowEmbeddedTerminal else {
            return nil
        }

        return "Managed policy blocks embedded terminal commands in this ForgeText installation."
    }

    static func diagnosticBundleRestrictionReason(policy: EnterpriseManagedPolicy?) -> String? {
        guard let policy, !policy.support.allowDiagnosticBundles else {
            return nil
        }

        return "Managed policy blocks diagnostic bundle export."
    }

    static func updateRestrictionReason(policy: EnterpriseManagedPolicy?) -> String? {
        guard let policy, !policy.updates.allowUpdateChecks else {
            return nil
        }

        return "Managed policy blocks manual update checks."
    }

    static func remoteRestrictionReason(for capability: RemoteCapability, policy: EnterpriseManagedPolicy?) -> String? {
        guard let policy else {
            return nil
        }

        switch capability {
        case .fileAccess:
            return policy.remote.allowRemoteFiles ? nil : "Managed policy blocks remote file access."
        case .search:
            return policy.remote.allowRemoteSearch ? nil : "Managed policy blocks remote search."
        case .commands:
            return policy.remote.allowRemoteCommands ? nil : "Managed policy blocks remote command execution."
        case .agentInstall:
            return policy.remote.allowRemoteAgentInstall ? nil : "Managed policy blocks remote agent installation."
        }
    }

    static func registrySourceRestrictionReason(_ source: String, policy: EnterpriseManagedPolicy?) -> String? {
        guard let policy else {
            return nil
        }

        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty else {
            return nil
        }

        if !policy.plugins.allowCustomRegistries {
            return "Managed policy blocks adding custom plugin registries."
        }

        if let sourceURL = URL(string: trimmedSource),
           let scheme = sourceURL.scheme?.lowercased(),
           !scheme.isEmpty {
            if scheme == "file" {
                return policy.plugins.allowsFileRegistries ? nil : "Managed policy blocks file-based plugin registries."
            }

            if !policy.plugins.allowedRegistryHosts.isEmpty {
                let host = sourceURL.host?.lowercased() ?? ""
                let isAllowed = policy.plugins.allowedRegistryHosts.contains(where: {
                    host == $0.lowercased() || host.hasSuffix(".\($0.lowercased())")
                })
                if !isAllowed {
                    return "Managed policy only allows plugin registries from approved hosts."
                }
            }
        } else if !policy.plugins.allowsFileRegistries {
            return "Managed policy blocks file-based plugin registries."
        }

        return nil
    }

    static func registryEntryRestrictionReason(_ entry: PluginRegistryEntry, policy: EnterpriseManagedPolicy?) -> String? {
        guard let policy else {
            return nil
        }

        if !policy.plugins.allowTaskCapablePlugins,
           (entry.capabilities.contains(.tasks) || !entry.tasks.isEmpty) {
            return "Managed policy blocks installing task-capable plugins."
        }

        if !policy.plugins.allowedPluginAuthors.isEmpty,
           !policy.plugins.allowedPluginAuthors.contains(where: { $0.caseInsensitiveCompare(entry.author) == .orderedSame }) {
            return "Managed policy only allows plugins from approved authors."
        }

        return nil
    }

    static func pluginRestrictionReason(
        _ plugin: EditorPlugin,
        workspaceRoots: [URL],
        policy: EnterpriseManagedPolicy?
    ) -> String? {
        guard let policy else {
            return nil
        }

        let origin = pluginOrigin(for: plugin, workspaceRoots: workspaceRoots)
        switch origin {
        case .builtIn:
            break
        case .workspaceLocal:
            if !policy.plugins.allowWorkspacePlugins {
                return "Managed policy blocks workspace-local plugins."
            }
        case .userInstalled, .externalUnknown:
            if !policy.plugins.allowUserInstalledPlugins {
                return "Managed policy blocks user-installed external plugins."
            }
        }

        if !policy.plugins.allowTaskCapablePlugins,
           plugin.manifest.capabilities.contains(.tasks) {
            return "Managed policy blocks task-capable plugins."
        }

        if origin != .builtIn,
           !policy.plugins.allowedPluginAuthors.isEmpty,
           !policy.plugins.allowedPluginAuthors.contains(where: { $0.caseInsensitiveCompare(plugin.manifest.author) == .orderedSame }) {
            return "Managed policy only allows external plugins from approved authors."
        }

        return nil
    }

    static func pluginOrigin(for plugin: EditorPlugin, workspaceRoots: [URL]) -> PluginOrigin {
        if plugin.manifest.isBuiltIn {
            return .builtIn
        }

        guard let sourceDescription = plugin.manifest.sourceDescription else {
            return .externalUnknown
        }

        let sourceURL = URL(fileURLWithPath: sourceDescription).standardizedFileURL
        let parentDirectory = sourceURL.deletingLastPathComponent()
        let userPluginDirectory = StoragePathService.userPluginDirectoryURL().standardizedFileURL
        if parentDirectory == userPluginDirectory {
            return .userInstalled
        }

        for workspaceRoot in workspaceRoots.map(\.standardizedFileURL) {
            let workspacePluginDirectory = workspaceRoot
                .appendingPathComponent(".forgetext", isDirectory: true)
                .appendingPathComponent("plugins", isDirectory: true)
                .standardizedFileURL
            if parentDirectory == workspacePluginDirectory {
                return .workspaceLocal
            }
        }

        return .externalUnknown
    }
}

extension EnterprisePolicyService {
    enum RemoteCapability {
        case fileAccess
        case search
        case commands
        case agentInstall
    }
}
