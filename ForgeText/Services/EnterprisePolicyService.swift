import Darwin
import Foundation

enum EnterprisePolicyService {
    struct PolicyTrustConfiguration: Hashable {
        var trustedPublicKeys: [String] = []
        var requiresSignature = false
    }

    enum PolicyLoadError: LocalizedError {
        case unsupportedVersion(Int)
        case invalidFileType
        case insecurePermissions
        case invalidOwner
        case fileTooLarge

        var errorDescription: String? {
            switch self {
            case let .unsupportedVersion(version):
                return "Managed policy version \(version) is not supported."
            case .invalidFileType:
                return "Managed policy must be a regular file and may not be a symbolic link."
            case .insecurePermissions:
                return "Managed policy is writable by another local account."
            case .invalidOwner:
                return "Managed policy is not owned by the current user or system administrator."
            case .fileTooLarge:
                return "Managed policy exceeds the 1 MB size limit."
            }
        }
    }

    enum PluginOrigin: String {
        case builtIn
        case workspaceLocal
        case userInstalled
        case externalUnknown
    }

    private static let envPathKey = "FORGETEXT_MANAGED_POLICY_FILE"
    private static let filename = "managed-policy.json"
    private static let managedPolicyJSONKey = "ManagedPolicyJSON"
    private static let trustedSigningKeysKey = "ManagedPolicyTrustedSigningKeys"
    private static let requireSignatureKey = "RequireSignedManagedPolicy"
    private static let trustedSigningKeysEnvironmentKey = "FORGETEXT_POLICY_TRUSTED_SIGNING_KEYS"

    static func loadState(
        policyFileURL: URL? = nil,
        trustConfiguration: PolicyTrustConfiguration? = nil
    ) -> ManagedPolicyState {
        let trust = trustConfiguration ?? configuredPolicyTrust()
        if policyFileURL == nil,
           UserDefaults.standard.objectIsForced(forKey: managedPolicyJSONKey),
           let json = UserDefaults.standard.string(forKey: managedPolicyJSONKey) {
            return loadManagedPolicyJSON(json, isForced: true, trustConfiguration: trust)
        }

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
            let data = try validatedPolicyData(at: resolvedURL)
            let verification = try SignedArtifactService.verify(
                data: data,
                trustedPublicKeys: trust.trustedPublicKeys,
                requiresSignature: trust.requiresSignature
            )
            let policy = try JSONDecoder().decode(EnterpriseManagedPolicy.self, from: data)
            guard policy.version == 1 else {
                throw PolicyLoadError.unsupportedVersion(policy.version)
            }
            return ManagedPolicyState(
                policy: policy,
                sourcePath: resolvedURL.path,
                loadError: nil,
                loadedAt: Date(),
                canonicalSHA256: verification.canonicalSHA256,
                verifiedSigningKey: verification.verifiedSigningKey
            )
        } catch {
            return ManagedPolicyState(
                policy: .failClosed,
                sourcePath: resolvedURL.path,
                loadError: error.localizedDescription,
                loadedAt: Date()
            )
        }
    }

    static func loadManagedPolicyJSON(
        _ json: String,
        isForced: Bool,
        trustConfiguration: PolicyTrustConfiguration? = nil
    ) -> ManagedPolicyState {
        guard isForced else {
            return ManagedPolicyState()
        }

        guard let data = json.data(using: .utf8), data.count <= 1_024 * 1_024 else {
            return ManagedPolicyState(
                policy: .failClosed,
                sourcePath: "mdm://\(managedPolicyJSONKey)",
                loadError: PolicyLoadError.fileTooLarge.localizedDescription,
                loadedAt: Date()
            )
        }

        do {
            let trust = trustConfiguration ?? configuredPolicyTrust()
            let verification = try SignedArtifactService.verify(
                data: data,
                trustedPublicKeys: trust.trustedPublicKeys,
                requiresSignature: trust.requiresSignature
            )
            let policy = try JSONDecoder().decode(EnterpriseManagedPolicy.self, from: data)
            guard policy.version == 1 else {
                throw PolicyLoadError.unsupportedVersion(policy.version)
            }
            return ManagedPolicyState(
                policy: policy,
                sourcePath: "mdm://\(managedPolicyJSONKey)",
                loadError: nil,
                loadedAt: Date(),
                canonicalSHA256: verification.canonicalSHA256,
                verifiedSigningKey: verification.verifiedSigningKey
            )
        } catch {
            return ManagedPolicyState(
                policy: .failClosed,
                sourcePath: "mdm://\(managedPolicyJSONKey)",
                loadError: error.localizedDescription,
                loadedAt: Date()
            )
        }
    }

    static func configuredPolicyTrust(
        userDefaults: UserDefaults = .standard,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> PolicyTrustConfiguration {
        var keys: [String] = []
        if userDefaults.objectIsForced(forKey: trustedSigningKeysKey) {
            if let forcedKeys = userDefaults.array(forKey: trustedSigningKeysKey) as? [String] {
                keys.append(contentsOf: forcedKeys)
            } else if let forcedKeys = userDefaults.string(forKey: trustedSigningKeysKey) {
                keys.append(contentsOf: forcedKeys.components(separatedBy: ","))
            }
        }
        if let environmentKeys = environment[trustedSigningKeysEnvironmentKey] {
            keys.append(contentsOf: environmentKeys.components(separatedBy: ","))
        }
        let normalized = Array(Set(keys.map {
            $0.trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty })).sorted()
        let forcedRequirement = userDefaults.objectIsForced(forKey: requireSignatureKey)
            && userDefaults.bool(forKey: requireSignatureKey)
        return PolicyTrustConfiguration(
            trustedPublicKeys: normalized,
            requiresSignature: forcedRequirement || !normalized.isEmpty
        )
    }

    static func defaultPolicyFileURL() -> URL {
        StoragePathService.appDataDirectoryURL()
            .appendingPathComponent(filename, isDirectory: false)
            .standardizedFileURL
    }

    static func discoveredPolicyURLs(
        processInfo: ProcessInfo = .processInfo,
        environment: [String: String]? = nil,
        localDomainApplicationSupportURL: URL? = FileManager.default.urls(for: .applicationSupportDirectory, in: .localDomainMask).first,
        defaultPolicyURL: URL = defaultPolicyFileURL()
    ) -> [URL] {
        var urls: [URL] = []
        let resolvedEnvironment = environment ?? processInfo.environment

        if let localDomainURL = localDomainApplicationSupportURL {
            urls.append(
                localDomainURL
                    .appendingPathComponent("ForgeText", isDirectory: true)
                    .appendingPathComponent(filename, isDirectory: false)
                    .standardizedFileURL
            )
        }

        if let explicitPath = resolvedEnvironment[envPathKey]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !explicitPath.isEmpty {
            urls.append(URL(fileURLWithPath: explicitPath, isDirectory: false).standardizedFileURL)
        }

        urls.append(defaultPolicyURL)
        return urls
    }

    static func summaryLines(for state: ManagedPolicyState) -> [String] {
        if let loadError = state.loadError {
            return [
                "Managed policy is invalid; protected capabilities are denied by default.",
                "Policy file could not be loaded: \(loadError)",
            ]
        }

        guard let policy = state.policy else {
            return [
                "No managed policy is active.",
                "Drop a \(filename) file into \(defaultPolicyFileURL().path) or set \(envPathKey)."
            ]
        }

        var lines: [String] = []
        lines.append(policy.organizationName.isEmpty ? "Managed policy is active." : "\(policy.organizationName) policy is active.")
        if state.hasVerifiedSignature {
            lines.append("Policy signature is verified against an administrator trust root.")
        } else {
            lines.append("Policy is permission-validated but not cryptographically signed.")
        }
        if let digest = state.canonicalSHA256 {
            lines.append("Policy digest: \(digest.prefix(16))...")
        }

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
        if policy.features.allowExternalFormatters != true {
            runtimeRules.append("external formatters blocked")
        }
        if policy.features.allowHTTPRequestRunner != true {
            runtimeRules.append("HTTP request runner blocked")
        }
        if policy.features.allowLanguageServers != true {
            runtimeRules.append("language servers blocked")
        }
        if policy.features.allowDebugAdapters != true {
            runtimeRules.append("debug adapters blocked")
        }
        if policy.features.allowDevContainers != true {
            runtimeRules.append("development containers blocked")
        }
        if policy.features.allowGitHubIntegration != true {
            runtimeRules.append("GitHub integration blocked")
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
        if let ring = policy.updates.ring {
            lines.append("Update ring: \(ring.displayName).")
        }
        if let catalogs = policy.plugins.managedCatalogs, !catalogs.isEmpty {
            lines.append("Managed plugin catalogs: \(catalogs.count).")
        }
        if let providers = policy.ai.approvedProviders, !providers.isEmpty {
            lines.append("Approved AI provider profiles: \(providers.count).")
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

        if policy.ai.enforceApprovedProviders == true {
            guard let approved = policy.ai.approvedProviders?.first(where: { $0.id == provider.id }),
                  approved.kind == provider.kind,
                  approved.connectionMode == provider.effectiveConnectionMode,
                  approved.baseURLString == provider.baseURLString,
                  approved.model == provider.model
            else {
                return "Managed policy only allows organization-approved AI provider profiles."
            }
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

        if let endpointHost = normalizedHost(from: provider.baseURLString),
           let configuredHosts = policy.ai.allowedEndpointHosts {
            let allowedHosts = normalizedHosts(configuredHosts)
            if allowedHosts.isEmpty || !host(endpointHost, matchesAny: allowedHosts) {
                return "Managed policy does not allow the configured AI endpoint host."
            }
        } else if policy.ai.allowedEndpointHosts != nil {
            return "Managed policy requires AI providers to use an approved endpoint host."
        }

        return nil
    }

    static func managedAIProviders(
        policy: EnterpriseManagedPolicy?,
        existing: [AIProviderConfiguration]
    ) -> [AIProviderConfiguration] {
        guard let approved = policy?.ai.approvedProviders, !approved.isEmpty else { return existing }
        let managed = approved.map { profile in
            let current = existing.first(where: { $0.id == profile.id })
            return AIProviderConfiguration(
                id: profile.id,
                name: profile.name,
                kind: profile.kind,
                connectionMode: profile.connectionMode,
                baseURLString: profile.baseURLString,
                model: profile.model,
                apiKey: current?.apiKey ?? AIProviderKeychainStore.apiKey(for: profile.id) ?? "",
                temperature: min(max(profile.temperature ?? 0.2, 0), 2),
                isEnabled: current?.isEnabled ?? true
            )
        }
        guard policy?.ai.enforceApprovedProviders == true else {
            let managedIDs = Set(managed.map(\.id))
            return managed + existing.filter { !managedIDs.contains($0.id) }
        }
        return managed
    }

    static func externalFormatterRestrictionReason(policy: EnterpriseManagedPolicy?) -> String? {
        guard let policy, policy.features.allowExternalFormatters != true else {
            return nil
        }

        return "Managed policy blocks external formatter processes."
    }

    static func languageServerRestrictionReason(policy: EnterpriseManagedPolicy?) -> String? {
        guard let policy, policy.features.allowLanguageServers != true else { return nil }
        return "Managed policy blocks language-server processes."
    }

    static func debugAdapterRestrictionReason(policy: EnterpriseManagedPolicy?) -> String? {
        guard let policy, policy.features.allowDebugAdapters != true else { return nil }
        return "Managed policy blocks debug-adapter processes."
    }

    static func devContainerRestrictionReason(policy: EnterpriseManagedPolicy?) -> String? {
        guard let policy, policy.features.allowDevContainers != true else { return nil }
        return "Managed policy blocks development-container execution."
    }

    static func gitHubIntegrationRestrictionReason(policy: EnterpriseManagedPolicy?) -> String? {
        guard let policy, policy.features.allowGitHubIntegration != true else { return nil }
        return "Managed policy blocks authenticated GitHub integration."
    }

    static func httpRequestRestrictionReason(policy: EnterpriseManagedPolicy?) -> String? {
        guard let policy, policy.features.allowHTTPRequestRunner != true else {
            return nil
        }

        return "Managed policy blocks HTTP request execution."
    }

    static func allowsPrivateNetworkRequests(policy: EnterpriseManagedPolicy?) -> Bool {
        guard let policy else {
            return false
        }
        return policy.features.allowPrivateNetworkRequests == true
    }

    static func allowedHTTPRequestHosts(policy: EnterpriseManagedPolicy?) -> [String]? {
        guard let policy else {
            return nil
        }
        return normalizedHosts(policy.features.allowedHTTPRequestHosts ?? [])
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

    static func taskExecutableRestrictionReason(_ executable: String, policy: EnterpriseManagedPolicy?) -> String? {
        guard let allowedExecutables = policy?.plugins.allowedTaskExecutables else {
            return nil
        }
        let normalizedExecutable = executable.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard allowedExecutables.contains(where: { $0.lowercased() == normalizedExecutable }) else {
            return "Managed policy does not allow the task executable '\(executable)'."
        }
        return nil
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

    static func auditExportRestrictionReason(policy: EnterpriseManagedPolicy?) -> String? {
        guard let policy, policy.support.allowAuditExport == false else { return nil }
        return "Managed policy blocks audit-log export."
    }

    static func effectiveAuditRetentionDays(policy: EnterpriseManagedPolicy?) -> Int {
        min(max(policy?.support.auditRetentionDays ?? 30, 1), 365)
    }

    static func managedUpdateFeedURL(
        state: ManagedPolicyState,
        fallback: String?
    ) -> String? {
        guard let configured = state.policy?.updates.feedURL?.trimmingCharacters(in: .whitespacesAndNewlines),
              !configured.isEmpty
        else { return fallback }

        // A local unsigned policy may restrict updates, but it may not redirect the updater.
        guard state.hasVerifiedSignature || state.sourcePath?.hasPrefix("mdm://") == true,
              let url = URL(string: configured),
              url.scheme?.lowercased() == "https",
              url.user == nil,
              url.password == nil,
              url.fragment == nil,
              let host = url.host?.lowercased()
        else { return fallback }

        if let allowedHosts = state.policy?.updates.allowedFeedHosts {
            let normalized = normalizedHosts(allowedHosts)
            guard normalized.contains(host) else { return fallback }
        }
        return url.absoluteString
    }

    private static func validatedPolicyData(at url: URL) throws -> Data {
        let resourceValues = try url.resourceValues(forKeys: [
            .isRegularFileKey,
            .isSymbolicLinkKey,
            .fileSizeKey,
        ])
        guard resourceValues.isRegularFile == true, resourceValues.isSymbolicLink != true else {
            throw PolicyLoadError.invalidFileType
        }
        guard (resourceValues.fileSize ?? 0) <= 1_024 * 1_024 else {
            throw PolicyLoadError.fileTooLarge
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let ownerID = (attributes[.ownerAccountID] as? NSNumber)?.uint32Value
        guard ownerID == getuid() || ownerID == 0 else {
            throw PolicyLoadError.invalidOwner
        }
        let permissions = (attributes[.posixPermissions] as? NSNumber)?.uint16Value ?? 0
        guard permissions & 0o022 == 0 else {
            throw PolicyLoadError.insecurePermissions
        }

        return try BoundedFileReadService.read(url, maximumBytes: 1_024 * 1_024)
    }

    private static func normalizedHost(from urlString: String) -> String? {
        URL(string: urlString)?.host?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func normalizedHosts(_ hosts: [String]) -> [String] {
        hosts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty && !$0.hasPrefix(".") && !$0.contains("/") }
    }

    private static func host(_ candidate: String, matchesAny allowedHosts: [String]) -> Bool {
        allowedHosts.contains(candidate)
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

        if let allowedExecutables = policy.plugins.allowedTaskExecutables {
            let normalizedExecutables = Set(allowedExecutables.map { $0.lowercased() })
            if entry.tasks.contains(where: { !normalizedExecutables.contains($0.executable.lowercased()) }) {
                return "The plugin defines a task executable that is not approved by managed policy."
            }
        }

        let provenance = PluginSignatureService.provenance(for: entry)
        if let reason = pluginProvenanceRestrictionReason(
            author: entry.author,
            provenance: provenance,
            policy: policy.plugins
        ) {
            return reason
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

        if origin != .builtIn {
            let provenance = plugin.manifest.canonicalSHA256.map {
                PluginManifestProvenance(
                    canonicalSHA256: $0,
                    verifiedSigningKey: plugin.manifest.verifiedSigningKey
                )
            }
            if let reason = pluginProvenanceRestrictionReason(
                author: plugin.manifest.author,
                provenance: provenance,
                policy: policy.plugins
            ) {
                return reason
            }
        }

        return nil
    }

    private static func pluginProvenanceRestrictionReason(
        author: String,
        provenance: PluginManifestProvenance?,
        policy: EnterpriseManagedPluginPolicy
    ) -> String? {
        let allowedAuthors = policy.allowedPluginAuthors
        if !allowedAuthors.isEmpty,
           !allowedAuthors.contains(where: { $0.caseInsensitiveCompare(author) == .orderedSame }) {
            return "Managed policy only allows plugins from approved authors."
        }

        let allowedSigningKeys = policy.allowedPluginSigningKeys?.filter { !$0.isEmpty }
        if !allowedAuthors.isEmpty, allowedSigningKeys?.isEmpty != false {
            return "Managed policy author allowlists require at least one trusted plugin signing key."
        }

        if policy.requireSignedPlugins == true || allowedSigningKeys != nil {
            guard let verifiedSigningKey = provenance?.verifiedSigningKey else {
                return "Managed policy requires a valid Ed25519 plugin manifest signature."
            }
            if let allowedSigningKeys,
               !allowedSigningKeys.contains(verifiedSigningKey) {
                return "The plugin signature is valid, but its signing key is not approved by managed policy."
            }
        }

        if let allowedDigests = policy.allowedPluginManifestDigests {
            let normalizedDigests = allowedDigests.map { $0.lowercased() }
            guard let digest = provenance?.canonicalSHA256.lowercased(),
                  normalizedDigests.contains(digest) else {
                return "The plugin manifest digest is not approved by managed policy."
            }
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
