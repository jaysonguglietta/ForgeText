import Foundation

enum AIProviderDefaults {
    static let profiles: [AIProviderConfiguration] = [
        AIProviderConfiguration(
            name: "OpenAI",
            kind: .openAI,
            baseURLString: "https://api.openai.com",
            model: "gpt-5.4"
        ),
        AIProviderConfiguration(
            name: "Anthropic",
            kind: .anthropic,
            baseURLString: "https://api.anthropic.com",
            model: "claude-sonnet-4-5"
        ),
        AIProviderConfiguration(
            name: "Google Gemini",
            kind: .googleGemini,
            baseURLString: "https://generativelanguage.googleapis.com",
            model: "gemini-2.5-pro"
        ),
        AIProviderConfiguration(
            name: "Ollama",
            kind: .ollama,
            baseURLString: "http://localhost:11434",
            model: "llama3.1"
        ),
        AIProviderConfiguration(
            name: "OpenAI-Compatible",
            kind: .openAICompatible,
            baseURLString: "http://localhost:1234",
            model: "local-model"
        ),
    ]
}
