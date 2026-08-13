import Foundation

enum AIRulesService {
    private static let maximumRuleFileBytes = 64 * 1_024
    private static let maximumPromptFileBytes = 128 * 1_024
    private static let maximumPromptFiles = 50
    private static let maximumScopeFileBytes = 128 * 1_024
    private static let maximumScopedInstructionCharacters = 64 * 1_024

    static let candidateFileNames = [
        ".forgetext/ai-rules.md",
        ".forgetext/rules.md",
        ".github/copilot-instructions.md",
        "AGENTS.md",
        "CLAUDE.md",
        "GEMINI.md",
        "CODEX.md",
        ".cursorrules",
    ]

    static func loadRules(
        for workspaceRoot: URL?,
        document: EditorDocument? = nil,
        task: AIQuickAction? = nil
    ) -> String? {
        var sections = loadRuleFiles(for: workspaceRoot).map {
            "Rules from \($0.relativePath):\n\($0.text.trimmingCharacters(in: .whitespacesAndNewlines))"
        }
        sections += matchingScopedRules(for: workspaceRoot, document: document, task: task).map {
            "Scoped rules (\($0.name)):\n\($0.instructions.trimmingCharacters(in: .whitespacesAndNewlines))"
        }

        return sections.isEmpty ? nil : sections.joined(separator: "\n\n")
    }

    static func matchingScopedRules(
        for workspaceRoot: URL?,
        document: EditorDocument?,
        task: AIQuickAction?
    ) -> [AIContextScopeRule] {
        guard let workspaceRoot else { return [] }
        let fileURL = workspaceRoot
            .appendingPathComponent(".forgetext", isDirectory: true)
            .appendingPathComponent("ai-scopes.json")
        guard let text = readWorkspaceText(
            at: fileURL,
            workspaceRoot: workspaceRoot,
            maximumBytes: maximumScopeFileBytes
        ),
              let data = text.data(using: .utf8),
              let configuration = try? ForgeTextJSONDecoder.make(trustLevel: .externalImport)
                .decode(AIContextScopeConfiguration.self, from: data),
              configuration.version == 1
        else { return [] }

        let matchingRelativePath: String?
        if let documentURL = document?.fileURL {
            matchingRelativePath = relativePath(for: documentURL, root: workspaceRoot)
        } else {
            matchingRelativePath = nil
        }
        let fileExtension = document?.fileURL?.pathExtension.lowercased()
            ?? document.map { URL(fileURLWithPath: $0.displayName).pathExtension.lowercased() }
        let taskName = task?.rawValue.lowercased()
        var characterCount = 0
        return configuration.scopes.prefix(100).filter { scope in
            guard scope.isEnabled,
                  !scope.instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else { return false }
            let paths = scope.pathPrefixes.compactMap(normalizedPathPrefix)
            if !paths.isEmpty {
                guard let matchingRelativePath,
                      paths.contains(where: { matchingRelativePath == $0 || matchingRelativePath.hasPrefix($0 + "/") })
                else {
                    return false
                }
            }
            let extensions = scope.fileExtensions.map {
                $0.trimmingCharacters(in: CharacterSet(charactersIn: " .")).lowercased()
            }.filter { !$0.isEmpty }
            if !extensions.isEmpty, !extensions.contains(fileExtension ?? "") { return false }
            let tasks = scope.tasks.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }.filter { !$0.isEmpty }
            if !tasks.isEmpty, !tasks.contains(taskName ?? "") { return false }
            guard characterCount + scope.instructions.count <= maximumScopedInstructionCharacters else { return false }
            characterCount += scope.instructions.count
            return true
        }
    }

    static func contextState(for workspaceRoot: URL?) -> AIContextState {
        guard workspaceRoot != nil else {
            return AIContextState(statusMessage: "Choose a workspace folder to load AI rules and prompt files.")
        }

        let rules = loadRuleFiles(for: workspaceRoot)
        let prompts = loadPromptFiles(for: workspaceRoot)
        let message: String
        if rules.isEmpty && prompts.isEmpty {
            message = "No AI rules or prompts were found. Add .forgetext/rules.md or .forgetext/prompts/*.md to the workspace."
        } else {
            message = "Loaded \(rules.count) rule file\(rules.count == 1 ? "" : "s") and \(prompts.count) prompt file\(prompts.count == 1 ? "" : "s")."
        }

        return AIContextState(
            ruleFiles: rules,
            promptFiles: prompts,
            refreshedAt: Date(),
            statusMessage: message
        )
    }

    static func loadRuleFiles(for workspaceRoot: URL?) -> [AIRuleFile] {
        guard let workspaceRoot else {
            return []
        }

        return candidateFileNames.compactMap { candidate in
            let fileURL = workspaceRoot.appendingPathComponent(candidate)
            guard let text = readWorkspaceText(
                at: fileURL,
                workspaceRoot: workspaceRoot,
                maximumBytes: maximumRuleFileBytes
            ),
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            else {
                return nil
            }

            return AIRuleFile(
                id: fileURL.path,
                url: fileURL,
                relativePath: candidate,
                text: text
            )
        }
    }

    static func loadPromptFiles(for workspaceRoot: URL?) -> [AIPromptFile] {
        guard let workspaceRoot else {
            return []
        }

        let promptDirectory = workspaceRoot
            .appendingPathComponent(".forgetext", isDirectory: true)
            .appendingPathComponent("prompts", isDirectory: true)
        guard let directoryValues = try? promptDirectory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
              directoryValues.isDirectory == true,
              directoryValues.isSymbolicLink != true,
              isContained(promptDirectory, in: workspaceRoot)
        else {
            return []
        }
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: promptDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return files
            .filter { ["md", "txt", "prompt"].contains($0.pathExtension.lowercased()) }
            .prefix(maximumPromptFiles)
            .compactMap { fileURL in
                guard let text = readWorkspaceText(
                    at: fileURL,
                    workspaceRoot: workspaceRoot,
                    maximumBytes: maximumPromptFileBytes
                ),
                      !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                else {
                    return nil
                }

                let relativePath = ".forgetext/prompts/\(fileURL.lastPathComponent)"
                return AIPromptFile(
                    id: fileURL.path,
                    url: fileURL,
                    relativePath: relativePath,
                    title: promptTitle(from: fileURL, text: text),
                    text: text
                )
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private static func readWorkspaceText(at fileURL: URL, workspaceRoot: URL, maximumBytes: Int) -> String? {
        guard isContained(fileURL, in: workspaceRoot),
              let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              values.isRegularFile == true,
              values.isSymbolicLink != true,
              let fileSize = values.fileSize,
              fileSize <= maximumBytes,
              let data = try? BoundedFileReadService.read(fileURL, maximumBytes: maximumBytes)
        else {
            return nil
        }

        return String(data: data, encoding: .utf8)
    }

    private static func isContained(_ candidate: URL, in workspaceRoot: URL) -> Bool {
        let rootPath = workspaceRoot.resolvingSymlinksInPath().standardizedFileURL.path
        let candidatePath = candidate.resolvingSymlinksInPath().standardizedFileURL.path
        let rootPrefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        return candidatePath.hasPrefix(rootPrefix)
    }

    private static func relativePath(for candidate: URL, root: URL) -> String? {
        let rootPath = root.resolvingSymlinksInPath().standardizedFileURL.path
        let candidatePath = candidate.resolvingSymlinksInPath().standardizedFileURL.path
        let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
        guard candidatePath.hasPrefix(prefix) else { return nil }
        return String(candidatePath.dropFirst(prefix.count))
    }

    private static func normalizedPathPrefix(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let components = trimmed.split(separator: "/", omittingEmptySubsequences: false)
        guard !trimmed.isEmpty,
              !trimmed.hasPrefix("/"),
              !components.contains(where: { $0 == "." || $0 == ".." || $0.isEmpty }),
              !trimmed.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
        else { return nil }
        return components.joined(separator: "/")
    }

    private static func promptTitle(from url: URL, text: String) -> String {
        if let heading = text.split(whereSeparator: \.isNewline)
            .map(String.init)
            .first(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("#") }) {
            return heading
                .replacingOccurrences(of: "#", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return url.deletingPathExtension().lastPathComponent
    }
}
