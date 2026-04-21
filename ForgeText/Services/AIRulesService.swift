import Foundation

enum AIRulesService {
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

    static func loadRules(for workspaceRoot: URL?) -> String? {
        let sections = loadRuleFiles(for: workspaceRoot).map {
            "Rules from \($0.relativePath):\n\($0.text.trimmingCharacters(in: .whitespacesAndNewlines))"
        }

        return sections.isEmpty ? nil : sections.joined(separator: "\n\n")
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
            guard let text = try? String(contentsOf: fileURL),
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
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: promptDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return files
            .filter { ["md", "txt", "prompt"].contains($0.pathExtension.lowercased()) }
            .compactMap { fileURL in
                guard let text = try? String(contentsOf: fileURL),
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
