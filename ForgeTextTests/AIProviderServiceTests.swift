import XCTest
@testable import ForgeText

final class AIProviderServiceTests: XCTestCase {
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
}
