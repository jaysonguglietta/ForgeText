import XCTest
@testable import ForgeText

final class AIProviderServiceTests: XCTestCase {
    func testExternalImportDecoderIgnoresLegacyAPIKeys() throws {
        let providerID = UUID()
        AIProviderKeychainStore.deleteAPIKey(for: providerID)
        defer { AIProviderKeychainStore.deleteAPIKey(for: providerID) }

        let data = try XCTUnwrap(
            """
            {
              "aiProviders": [
                {
                  "id": "\(providerID.uuidString)",
                  "name": "Imported Gateway",
                  "kind": "openAICompatible",
                  "connectionMode": "bringYourOwnKey",
                  "baseURLString": "https://attacker.example.com",
                  "model": "exfil-model",
                  "apiKey": "legacy-secret",
                  "temperature": 0.2,
                  "isEnabled": true
                }
              ]
            }
            """.data(using: .utf8)
        )

        let imported = try ForgeTextJSONDecoder.make(trustLevel: .externalImport).decode(AppSettings.self, from: data)

        XCTAssertEqual(imported.aiProviders.first?.apiKey, "")
        XCTAssertNil(AIProviderKeychainStore.apiKey(for: providerID))
    }

    func testGeminiURLDoesNotEmbedAPIKeyInQueryString() throws {
        let provider = AIProviderConfiguration(
            name: "Gemini",
            kind: .googleGemini,
            baseURLString: "https://generativelanguage.googleapis.com",
            model: "gemini-2.5-pro",
            apiKey: "secret-key"
        )

        let url = try AIProviderService.geminiURL(
            baseURL: URL(string: provider.baseURLString)!,
            provider: provider
        )
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)

        XCTAssertNil(components?.query)
        XCTAssertFalse(url.absoluteString.contains("secret-key"))
        XCTAssertTrue(url.absoluteString.hasSuffix("/v1beta/models/gemini-2.5-pro:generateContent"))
    }

    func testOpenAICompatibleDefaultsToLocalModelModeWithoutAPIKeyRequirement() {
        let provider = AIProviderConfiguration(
            name: "LM Studio",
            kind: .openAICompatible,
            baseURLString: "http://localhost:1234",
            model: "local-model"
        )

        XCTAssertEqual(provider.effectiveConnectionMode, .localModel)
        XCTAssertFalse(provider.requiresAPIKey)
    }

    func testOpenAICompatibleCanOptIntoBringYourOwnKeyMode() {
        let provider = AIProviderConfiguration(
            name: "Hosted Gateway",
            kind: .openAICompatible,
            connectionMode: .bringYourOwnKey,
            baseURLString: "https://example.com",
            model: "gateway-model"
        )

        XCTAssertEqual(provider.effectiveConnectionMode, .bringYourOwnKey)
        XCTAssertTrue(provider.requiresAPIKey)
    }

    func testCloudProvidersFallBackToBringYourOwnKeyMode() {
        let provider = AIProviderConfiguration(
            name: "OpenAI",
            kind: .openAI,
            connectionMode: .localModel,
            baseURLString: "https://api.openai.com",
            model: "gpt-5.4"
        )

        XCTAssertEqual(provider.effectiveConnectionMode, .bringYourOwnKey)
        XCTAssertTrue(provider.requiresAPIKey)
    }

    func testPreparedPromptDisclosesEveryIncludedContextSource() {
        let document = EditorDocument.untitled(named: "Service.swift")
        var populatedDocument = document
        populatedDocument.text = "func launch() {}"
        populatedDocument.language = .swift

        let prompt = AIProviderService.buildPrompt(
            userPrompt: "Review this",
            currentDocument: populatedDocument,
            selectedText: "launch()",
            workspaceRules: "Never expose secrets.",
            includeCurrentDocument: true,
            includeSelectedText: true,
            includeWorkspaceRules: true,
            quickAction: .explainSelection
        )

        XCTAssertEqual(
            Set(prompt.manifest.entries.map(\.kind)),
            [.instruction, .userPrompt, .selection, .currentDocument, .workspaceRules]
        )
        XCTAssertEqual(prompt.manifest.preparedCharacterCount, prompt.systemPrompt.count + prompt.userPrompt.count)
        XCTAssertFalse(prompt.manifest.redactionApplied)
        XCTAssertFalse(prompt.manifest.truncationApplied)
    }
}
