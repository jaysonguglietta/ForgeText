import Foundation

enum AIProviderKind: String, CaseIterable, Codable, Identifiable {
    case openAI
    case anthropic
    case googleGemini
    case ollama
    case openAICompatible

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openAI:
            return "OpenAI"
        case .anthropic:
            return "Anthropic"
        case .googleGemini:
            return "Google Gemini"
        case .ollama:
            return "Ollama"
        case .openAICompatible:
            return "OpenAI Compatible"
        }
    }
}

struct AIProviderConfiguration: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var kind: AIProviderKind
    var baseURLString: String
    var model: String
    var apiKey: String
    var temperature: Double
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        kind: AIProviderKind,
        baseURLString: String,
        model: String,
        apiKey: String = "",
        temperature: Double = 0.2,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.baseURLString = baseURLString
        self.model = model
        self.apiKey = apiKey
        self.temperature = temperature
        self.isEnabled = isEnabled
    }
}

enum AIMessageRole: String, Codable, Hashable {
    case system
    case user
    case assistant
}

struct AIChatMessage: Identifiable, Codable, Hashable {
    let id: UUID
    let role: AIMessageRole
    let content: String
    let createdAt: Date
    let providerName: String
    let model: String

    init(
        id: UUID = UUID(),
        role: AIMessageRole,
        content: String,
        createdAt: Date = Date(),
        providerName: String,
        model: String
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.providerName = providerName
        self.model = model
    }
}

struct AIChatSession: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    var messages: [AIChatMessage]
    var updatedAt: Date

    init(id: UUID = UUID(), title: String, messages: [AIChatMessage] = [], updatedAt: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.updatedAt = updatedAt
    }
}

enum AIQuickAction: String, CaseIterable, Identifiable {
    case explainSelection
    case improveSelection
    case generateTests
    case summarizeFile
    case draftCommitMessage

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .explainSelection:
            return "Explain Selection"
        case .improveSelection:
            return "Improve Selection"
        case .generateTests:
            return "Generate Tests"
        case .summarizeFile:
            return "Summarize File"
        case .draftCommitMessage:
            return "Draft Commit Message"
        }
    }

    var symbolName: String {
        switch self {
        case .explainSelection:
            return "text.magnifyingglass"
        case .improveSelection:
            return "wand.and.stars"
        case .generateTests:
            return "checkmark.circle.badge.questionmark"
        case .summarizeFile:
            return "doc.text.magnifyingglass"
        case .draftCommitMessage:
            return "text.badge.star"
        }
    }
}
