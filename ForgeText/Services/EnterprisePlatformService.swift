import Foundation

enum DevContainerService {
    enum DevContainerError: LocalizedError {
        case invalidConfiguration
        case configurationTooLarge
        case cliUnavailable
        case workspaceMismatch

        var errorDescription: String? {
            switch self {
            case .invalidConfiguration:
                return "The development-container configuration is invalid or unsafe to read."
            case .configurationTooLarge:
                return "The development-container configuration exceeds the 1 MB safety limit."
            case .cliUnavailable:
                return "Install the trusted Dev Container CLI before starting this environment."
            case .workspaceMismatch:
                return "The development-container configuration no longer belongs to the active workspace."
            }
        }
    }

    static func inspect(workspaceRoot: URL?) -> DevContainerConfiguration? {
        guard let workspaceRoot else { return nil }
        let root = workspaceRoot.resolvingSymlinksInPath().standardizedFileURL
        let candidates = [
            root.appendingPathComponent(".devcontainer/devcontainer.json"),
            root.appendingPathComponent(".devcontainer.json"),
        ]

        guard let url = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
              isContained(url, in: root),
              let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              values.isRegularFile == true,
              values.isSymbolicLink != true,
              (values.fileSize ?? 0) <= 1_024 * 1_024,
              let data = try? BoundedFileReadService.read(url, maximumBytes: 1_024 * 1_024),
              let text = String(data: data, encoding: .utf8),
              let normalized = stripJSONCommentsAndTrailingCommas(text).data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: normalized) as? [String: Any]
        else {
            return nil
        }

        let features = (object["features"] as? [String: Any])?.keys.sorted() ?? []
        let lifecycleKeys = ["initializeCommand", "onCreateCommand", "updateContentCommand", "postCreateCommand", "postStartCommand", "postAttachCommand"]
        return DevContainerConfiguration(
            configurationPath: url.path,
            workspaceRootPath: root.path,
            name: (object["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty ?? root.lastPathComponent,
            remoteUser: (object["remoteUser"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines).nonEmpty,
            featureIdentifiers: features,
            declaresLifecycleCommands: lifecycleKeys.contains { object[$0] != nil },
            cliPath: ToolchainService.trustedExecutablePath(named: "devcontainer")
        )
    }

    static func start(_ configuration: DevContainerConfiguration, activeWorkspaceRoot: URL?) throws -> CommandExecutionService.CommandResult {
        guard let activeWorkspaceRoot,
              activeWorkspaceRoot.resolvingSymlinksInPath().standardizedFileURL.path == configuration.workspaceRootPath
        else {
            throw DevContainerError.workspaceMismatch
        }
        guard let cliPath = configuration.cliPath,
              ToolchainService.isTrustedAbsoluteExecutablePath(cliPath)
        else {
            throw DevContainerError.cliUnavailable
        }

        return try CommandExecutionService.execute(
            cliPath,
            arguments: ["up", "--workspace-folder", configuration.workspaceRootPath],
            currentDirectoryURL: activeWorkspaceRoot,
            environment: ["NO_COLOR": "1", "GIT_TERMINAL_PROMPT": "0"],
            limits: .interactiveTask
        )
    }

    static func stripJSONCommentsAndTrailingCommas(_ text: String) -> String {
        var output = ""
        var index = text.startIndex
        var inString = false
        var isEscaped = false
        var inLineComment = false
        var inBlockComment = false

        while index < text.endIndex {
            let character = text[index]
            let nextIndex = text.index(after: index)
            let next = nextIndex < text.endIndex ? text[nextIndex] : nil

            if inLineComment {
                if character == "\n" {
                    inLineComment = false
                    output.append(character)
                }
                index = nextIndex
                continue
            }
            if inBlockComment {
                if character == "*", next == "/" {
                    inBlockComment = false
                    index = text.index(after: nextIndex)
                } else {
                    if character == "\n" { output.append("\n") }
                    index = nextIndex
                }
                continue
            }
            if inString {
                output.append(character)
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    inString = false
                }
                index = nextIndex
                continue
            }
            if character == "\"" {
                inString = true
                output.append(character)
                index = nextIndex
                continue
            }
            if character == "/", next == "/" {
                inLineComment = true
                index = text.index(after: nextIndex)
                continue
            }
            if character == "/", next == "*" {
                inBlockComment = true
                index = text.index(after: nextIndex)
                continue
            }
            output.append(character)
            index = nextIndex
        }

        var normalized = ""
        var cursor = output.startIndex
        inString = false
        isEscaped = false
        while cursor < output.endIndex {
            let character = output[cursor]
            if inString {
                normalized.append(character)
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    inString = false
                }
                cursor = output.index(after: cursor)
                continue
            }
            if character == "\"" {
                inString = true
                normalized.append(character)
                cursor = output.index(after: cursor)
                continue
            }
            if character == "," {
                var lookahead = output.index(after: cursor)
                while lookahead < output.endIndex, output[lookahead].isWhitespace {
                    lookahead = output.index(after: lookahead)
                }
                if lookahead < output.endIndex,
                   (output[lookahead] == "}" || output[lookahead] == "]") {
                    cursor = output.index(after: cursor)
                    continue
                }
            }
            normalized.append(character)
            cursor = output.index(after: cursor)
        }
        return normalized
    }

    private static func isContained(_ candidate: URL, in workspaceRoot: URL) -> Bool {
        let rootPath = workspaceRoot.resolvingSymlinksInPath().standardizedFileURL.path
        let candidatePath = candidate.resolvingSymlinksInPath().standardizedFileURL.path
        return candidatePath.hasPrefix(rootPath + "/")
    }
}

enum PluginGovernanceService {
    static func findings(plugins: [EditorPlugin], policy: EnterpriseManagedPolicy?) -> [PluginGovernanceFinding] {
        let external = plugins.filter { !$0.manifest.isBuiltIn }
        var findings = [
            PluginGovernanceFinding(
                id: "declarative-boundary",
                pluginName: "Extension boundary",
                detail: "External plugins are data-only manifests. ForgeText does not load third-party binaries or dynamic libraries into the app process.",
                tone: .healthy
            )
        ]

        for plugin in external {
            let isSigned = plugin.manifest.verifiedSigningKey != nil
            let hasTasks = plugin.manifest.capabilities.contains(.tasks)
            let requiresSignature = policy?.plugins.requireSignedPlugins == true
            let tone: WorkbenchHealthTone = (!isSigned && requiresSignature) ? .blocked : (hasTasks || !isSigned ? .attention : .healthy)
            var detail = isSigned ? "Verified manifest signature." : "Manifest is not signed."
            if hasTasks {
                detail += " Task capability executes only through the trusted workspace, executable allowlist, and bounded task runner."
            }
            findings.append(
                PluginGovernanceFinding(
                    id: plugin.manifest.id,
                    pluginName: plugin.manifest.name,
                    detail: detail,
                    tone: tone
                )
            )
        }
        return findings
    }
}

enum EffectivePolicyReportService {
    static func decisions(
        state: ManagedPolicyState,
        trustMode: WorkspaceTrustMode,
        safeMode: Bool,
        advancedSettings: AdvancedEditorSettings = AdvancedEditorSettings()
    ) -> [EffectivePolicyDecision] {
        let policy = state.policy
        let source = state.sourcePath ?? "Local user configuration"
        let trustedExecution = trustMode == .trusted && !safeMode

        func decision(_ id: String, _ capability: String, _ policyAllows: Bool, _ reason: String) -> EffectivePolicyDecision {
            let allowed = trustedExecution && policyAllows
            let effectiveReason: String
            if safeMode {
                effectiveReason = "Safe Mode blocks this execution capability."
            } else if trustMode != .trusted {
                effectiveReason = "Restricted Workspace blocks this execution capability."
            } else {
                effectiveReason = reason
            }
            return EffectivePolicyDecision(id: id, capability: capability, isAllowed: allowed, source: source, reason: effectiveReason)
        }

        return [
            decision("language", "Language servers", policy == nil || policy?.features.allowLanguageServers == true, "Allowed by the effective policy."),
            decision("debug", "Debug adapters", policy == nil || policy?.features.allowDebugAdapters == true, "Allowed by the effective policy."),
            decision("containers", "Development containers", policy == nil || policy?.features.allowDevContainers == true, "Allowed by the effective policy."),
            decision("github", "Authenticated GitHub integration", policy == nil || policy?.features.allowGitHubIntegration == true, "Allowed by the effective policy."),
            decision(
                "tasks",
                "Workspace tasks",
                (policy?.features.allowWorkspaceTasks ?? true) && advancedSettings.plugins.allowTaskCapablePlugins,
                advancedSettings.plugins.allowTaskCapablePlugins ? "Allowed by the effective policy." : "Local advanced settings block task-capable plugins."
            ),
            decision("terminal", "Embedded terminal", policy?.features.allowEmbeddedTerminal ?? true, "Allowed by the effective policy."),
            EffectivePolicyDecision(
                id: "remote",
                capability: "Remote commands",
                isAllowed: trustMode == .trusted
                    && (policy?.remote.allowRemoteCommands ?? true)
                    && advancedSettings.remote.allowRemoteCommands
                    && (!safeMode || advancedSettings.safeMode.allowsRemoteConnections),
                source: source,
                reason: trustMode != .trusted
                    ? "Restricted Workspace blocks this execution capability."
                    : (safeMode && !advancedSettings.safeMode.allowsRemoteConnections
                        ? "Safe Mode blocks remote connections."
                        : (advancedSettings.remote.allowRemoteCommands ? "Allowed by the effective policy." : "Local advanced settings block remote commands."))
            ),
            EffectivePolicyDecision(
                id: "ai",
                capability: "AI providers",
                isAllowed: trustMode == .trusted
                    && (policy?.ai.isEnabled ?? true)
                    && (!safeMode || advancedSettings.safeMode.allowsAI),
                source: source,
                reason: trustMode != .trusted
                    ? "Restricted Workspace blocks AI requests."
                    : (safeMode && !advancedSettings.safeMode.allowsAI
                        ? "Safe Mode blocks AI requests."
                        : ((policy?.ai.isEnabled ?? true) ? "Allowed within provider, endpoint, model, and context rules." : "Managed policy disables AI."))
            ),
        ]
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
