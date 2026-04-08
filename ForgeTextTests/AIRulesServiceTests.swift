import XCTest
@testable import ForgeText

final class AIRulesServiceTests: XCTestCase {
    func testLoadRulesCombinesKnownWorkspaceRuleFiles() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let forgeDirectory = root.appendingPathComponent(".forgetext", isDirectory: true)
        try FileManager.default.createDirectory(at: forgeDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try "Prefer safe refactors.".write(to: forgeDirectory.appendingPathComponent("ai-rules.md"), atomically: true, encoding: .utf8)
        try "Respect AGENTS instructions.".write(to: root.appendingPathComponent("AGENTS.md"), atomically: true, encoding: .utf8)

        let rules = AIRulesService.loadRules(for: root)

        XCTAssertTrue(rules?.contains("Prefer safe refactors.") == true)
        XCTAssertTrue(rules?.contains("Respect AGENTS instructions.") == true)
    }

    func testBuildPromptIncludesContextSections() {
        let document = EditorDocument.untitled(named: "Scratch.swift")
        let prompt = AIProviderService.buildPrompt(
            userPrompt: "Explain this code",
            currentDocument: document,
            selectedText: "let value = 1",
            workspaceRules: "Rules from AGENTS.md:\nBe concise.",
            includeCurrentDocument: true,
            includeSelectedText: true,
            includeWorkspaceRules: true,
            quickAction: .explainSelection
        )

        XCTAssertTrue(prompt.systemPrompt.contains("Explain the selected"))
        XCTAssertTrue(prompt.systemPrompt.contains("Be concise."))
        XCTAssertTrue(prompt.userPrompt.contains("Selected text"))
        XCTAssertTrue(prompt.userPrompt.contains("Current document"))
    }
}
