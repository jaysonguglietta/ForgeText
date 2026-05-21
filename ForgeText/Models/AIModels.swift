import Foundation
import Security

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

    var supportedConnectionModes: [AIProviderConnectionMode] {
        switch self {
        case .openAI, .anthropic, .googleGemini:
            return [.bringYourOwnKey]
        case .ollama:
            return [.localModel]
        case .openAICompatible:
            return [.bringYourOwnKey, .localModel]
        }
    }

    var defaultConnectionMode: AIProviderConnectionMode {
        switch self {
        case .openAI, .anthropic, .googleGemini:
            return .bringYourOwnKey
        case .ollama, .openAICompatible:
            return .localModel
        }
    }
}

enum AIProviderConnectionMode: String, CaseIterable, Codable, Identifiable {
    case bringYourOwnKey
    case localModel

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .bringYourOwnKey:
            return "Bring Your Own Key"
        case .localModel:
            return "Local Model"
        }
    }

    var symbolName: String {
        switch self {
        case .bringYourOwnKey:
            return "key.horizontal"
        case .localModel:
            return "desktopcomputer"
        }
    }
}

struct AIProviderConfiguration: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var kind: AIProviderKind
    var connectionMode: AIProviderConnectionMode
    var baseURLString: String
    var model: String
    var apiKey: String
    var temperature: Double
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        kind: AIProviderKind,
        connectionMode: AIProviderConnectionMode? = nil,
        baseURLString: String,
        model: String,
        apiKey: String = "",
        temperature: Double = 0.2,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.connectionMode = connectionMode ?? kind.defaultConnectionMode
        self.baseURLString = baseURLString
        self.model = model
        self.apiKey = apiKey
        self.temperature = temperature
        self.isEnabled = isEnabled
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
        case connectionMode
        case baseURLString
        case model
        case apiKey
        case temperature
        case isEnabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? "AI Provider"
        kind = try container.decodeIfPresent(AIProviderKind.self, forKey: .kind) ?? .openAICompatible
        let decodedConnectionMode = try container.decodeIfPresent(AIProviderConnectionMode.self, forKey: .connectionMode)
        connectionMode = kind.supportedConnectionModes.contains(decodedConnectionMode ?? kind.defaultConnectionMode)
            ? (decodedConnectionMode ?? kind.defaultConnectionMode)
            : kind.defaultConnectionMode
        baseURLString = try container.decodeIfPresent(String.self, forKey: .baseURLString) ?? ""
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
        temperature = try container.decodeIfPresent(Double.self, forKey: .temperature) ?? 0.2
        isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true

        let legacyAPIKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        let keychainAPIKey = AIProviderKeychainStore.apiKey(for: id) ?? ""
        if keychainAPIKey.isEmpty, !legacyAPIKey.isEmpty {
            AIProviderKeychainStore.saveAPIKey(legacyAPIKey, for: id)
        }
        apiKey = keychainAPIKey.isEmpty ? legacyAPIKey : keychainAPIKey
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(kind, forKey: .kind)
        try container.encode(effectiveConnectionMode, forKey: .connectionMode)
        try container.encode(baseURLString, forKey: .baseURLString)
        try container.encode(model, forKey: .model)
        try container.encode(temperature, forKey: .temperature)
        try container.encode(isEnabled, forKey: .isEnabled)
    }

    var effectiveConnectionMode: AIProviderConnectionMode {
        kind.supportedConnectionModes.contains(connectionMode) ? connectionMode : kind.defaultConnectionMode
    }

    var requiresAPIKey: Bool {
        effectiveConnectionMode == .bringYourOwnKey
    }

    var modeDescription: String {
        switch effectiveConnectionMode {
        case .bringYourOwnKey:
            if kind == .openAICompatible {
                return "Use your own hosted endpoint and send your stored API key with each request."
            }
            return "Use your own cloud-provider API key. ForgeText stores the key in your macOS Keychain."
        case .localModel:
            if kind == .ollama {
                return "Talk directly to your local Ollama server. No cloud key is required."
            }
            return "Talk to a local model server such as LM Studio or another OpenAI-compatible endpoint. ForgeText will not require or send an API key in this mode."
        }
    }

    var baseURLDescription: String {
        switch effectiveConnectionMode {
        case .bringYourOwnKey:
            return "Cloud endpoints should use HTTPS."
        case .localModel:
            return "Local model endpoints can use http://localhost or another local loopback address."
        }
    }
}

enum AIProviderKeychainStore {
    private static let service = "com.jaysonguglietta.ForgeText.ai-provider-keys"

    static func apiKey(for providerID: UUID) -> String? {
        var query = baseQuery(for: providerID)
        query[kSecMatchLimit as String] = kSecMatchLimitOne
        query[kSecReturnData as String] = true

        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess,
              let data = result as? Data,
              let apiKey = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return apiKey
    }

    @discardableResult
    static func saveAPIKey(_ apiKey: String, for providerID: UUID) -> Bool {
        if apiKey.isEmpty {
            return deleteAPIKey(for: providerID)
        }

        let data = Data(apiKey.utf8)
        let query = baseQuery(for: providerID)
        let update = [kSecValueData as String: data]
        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)

        if updateStatus == errSecSuccess {
            return true
        }

        guard updateStatus == errSecItemNotFound else {
            return false
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        return SecItemAdd(addQuery as CFDictionary, nil) == errSecSuccess
    }

    @discardableResult
    static func deleteAPIKey(for providerID: UUID) -> Bool {
        let status = SecItemDelete(baseQuery(for: providerID) as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    static func persistKeys(for providers: [AIProviderConfiguration]) {
        providers.forEach { provider in
            saveAPIKey(provider.apiKey, for: provider.id)
        }
    }

    private static func baseQuery(for providerID: UUID) -> [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: providerID.uuidString
        ]
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
