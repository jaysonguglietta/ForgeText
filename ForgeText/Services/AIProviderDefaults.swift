import Foundation

enum AIProviderDefaults {
    static let profiles: [AIProviderConfiguration] = [
        AIProviderConfiguration(
            name: "OpenAI",
            kind: .openAI,
            connectionMode: .bringYourOwnKey,
            baseURLString: "https://api.openai.com",
            model: "gpt-5.4"
        ),
        AIProviderConfiguration(
            name: "Anthropic",
            kind: .anthropic,
            connectionMode: .bringYourOwnKey,
            baseURLString: "https://api.anthropic.com",
            model: "claude-sonnet-4-5"
        ),
        AIProviderConfiguration(
            name: "Google Gemini",
            kind: .googleGemini,
            connectionMode: .bringYourOwnKey,
            baseURLString: "https://generativelanguage.googleapis.com",
            model: "gemini-2.5-pro"
        ),
        AIProviderConfiguration(
            name: "Ollama",
            kind: .ollama,
            connectionMode: .localModel,
            baseURLString: "http://localhost:11434",
            model: "llama3.1"
        ),
        AIProviderConfiguration(
            name: "LM Studio / OpenAI-Compatible",
            kind: .openAICompatible,
            connectionMode: .localModel,
            baseURLString: "http://localhost:1234",
            model: "local-model"
        ),
    ]
}
