import Foundation

enum AIRulesService {
    static let candidateFileNames = [
        ".forgetext/ai-rules.md",
        "AGENTS.md",
        "CLAUDE.md",
        "GEMINI.md",
        ".cursorrules",
    ]

    static func loadRules(for workspaceRoot: URL?) -> String? {
        guard let workspaceRoot else {
            return nil
        }

        var sections: [String] = []

        for candidate in candidateFileNames {
            let fileURL = workspaceRoot.appendingPathComponent(candidate)
            guard let text = try? String(contentsOf: fileURL), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }

            sections.append("Rules from \(candidate):\n\(text.trimmingCharacters(in: .whitespacesAndNewlines))")
        }

        return sections.isEmpty ? nil : sections.joined(separator: "\n\n")
    }
}
