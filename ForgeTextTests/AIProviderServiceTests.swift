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
}
