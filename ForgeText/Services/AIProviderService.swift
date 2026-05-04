import Foundation

enum AIProviderService {
    enum AIProviderError: LocalizedError {
        case providerUnavailable
        case missingAPIKey(String)
        case invalidBaseURL(String)
        case insecureBaseURL(String)
        case emptyResponse

        var errorDescription: String? {
            switch self {
            case .providerUnavailable:
                return "Choose an enabled AI provider before sending a prompt."
            case let .missingAPIKey(name):
                return "Add an API key for \(name) before sending requests."
            case let .invalidBaseURL(urlString):
                return "ForgeText couldn’t build a provider URL from \(urlString)."
            case let .insecureBaseURL(urlString):
                return "ForgeText blocked the AI provider URL \(urlString) because remote AI providers must use HTTPS. Localhost model servers can still use HTTP."
            case .emptyResponse:
                return "The AI provider returned an empty response."
            }
        }
    }

    struct PreparedPrompt {
        let systemPrompt: String
        let userPrompt: String
    }

    static func send(
        prompt: PreparedPrompt,
        sessionMessages: [AIChatMessage],
        provider: AIProviderConfiguration
    ) async throws -> String {
        switch provider.kind {
        case .openAI, .openAICompatible:
            return try await sendOpenAICompatible(prompt: prompt, sessionMessages: sessionMessages, provider: provider)
        case .anthropic:
            return try await sendAnthropic(prompt: prompt, sessionMessages: sessionMessages, provider: provider)
        case .googleGemini:
            return try await sendGemini(prompt: prompt, sessionMessages: sessionMessages, provider: provider)
        case .ollama:
            return try await sendOllama(prompt: prompt, sessionMessages: sessionMessages, provider: provider)
        }
    }

    static func buildPrompt(
        userPrompt: String,
        currentDocument: EditorDocument?,
        selectedText: String?,
        workspaceRules: String?,
        includeCurrentDocument: Bool,
        includeSelectedText: Bool,
        includeWorkspaceRules: Bool,
        quickAction: AIQuickAction?
    ) -> PreparedPrompt {
        var systemSections = [
            "You are ForgeText Assistant, a precise software-development helper inside a native macOS editor.",
            "Prefer concise, actionable answers. When suggesting code, optimize for direct insertion into the active file."
        ]

        if let quickAction {
            systemSections.append(quickActionSystemInstruction(for: quickAction))
        }

        if includeWorkspaceRules, let workspaceRules {
            systemSections.append(workspaceRules)
        }

        var userSections: [String] = [userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)]

        if includeSelectedText, let selectedText, !selectedText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            userSections.append("Selected text:\n\(selectedText)")
        }

        if includeCurrentDocument, let currentDocument {
            userSections.append("Current document (\(currentDocument.displayName), language: \(currentDocument.language.displayName)):\n\(currentDocument.text)")
        }

        return PreparedPrompt(
            systemPrompt: systemSections.joined(separator: "\n\n"),
            userPrompt: userSections.joined(separator: "\n\n")
        )
    }

    private static func quickActionSystemInstruction(for action: AIQuickAction) -> String {
        switch action {
        case .explainSelection:
            return "Explain the selected code or text clearly for a developer. Focus on intent, behavior, and risks."
        case .improveSelection:
            return "Rewrite or improve the selected text/code. Return improved content first, then a brief rationale."
        case .generateTests:
            return "Generate high-value tests for the provided code. Prefer concrete test cases over abstract advice."
        case .summarizeFile:
            return "Summarize the file for a developer. Highlight architecture, important flows, and risky areas."
        case .draftCommitMessage:
            return "Draft a concise, professional Git commit message. Prefer a short subject line followed by optional bullets."
        }
    }

    private static func sendOpenAICompatible(
        prompt: PreparedPrompt,
        sessionMessages: [AIChatMessage],
        provider: AIProviderConfiguration
    ) async throws -> String {
        guard !provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || provider.kind == .ollama else {
            throw AIProviderError.missingAPIKey(provider.name)
        }
        let baseURL = try validatedBaseURL(for: provider)

        let url = baseURL.appendingPathComponent("v1/chat/completions")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(provider.apiKey)", forHTTPHeaderField: "Authorization")

        let messages = openAIStyleMessages(prompt: prompt, sessionMessages: sessionMessages)
        let body: [String: Any] = [
            "model": provider.model,
            "temperature": provider.temperature,
            "messages": messages,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)

        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = root["choices"] as? [[String: Any]],
            let firstChoice = choices.first,
            let message = firstChoice["message"] as? [String: Any],
            let content = message["content"] as? String,
            !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw AIProviderError.emptyResponse
        }

        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func sendAnthropic(
        prompt: PreparedPrompt,
        sessionMessages: [AIChatMessage],
        provider: AIProviderConfiguration
    ) async throws -> String {
        guard !provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIProviderError.missingAPIKey(provider.name)
        }
        let baseURL = try validatedBaseURL(for: provider)

        let url = baseURL.appendingPathComponent("v1/messages")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(provider.apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let messages = anthropicMessages(prompt: prompt, sessionMessages: sessionMessages)
        let body: [String: Any] = [
            "model": provider.model,
            "max_tokens": 2048,
            "temperature": provider.temperature,
            "system": prompt.systemPrompt,
            "messages": messages,
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)

        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let content = root["content"] as? [[String: Any]]
        else {
            throw AIProviderError.emptyResponse
        }

        let text = content
            .compactMap { item -> String? in
                guard item["type"] as? String == "text" else {
                    return nil
                }
                return item["text"] as? String
            }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            throw AIProviderError.emptyResponse
        }

        return text
    }

    private static func sendGemini(
        prompt: PreparedPrompt,
        sessionMessages: [AIChatMessage],
        provider: AIProviderConfiguration
    ) async throws -> String {
        guard !provider.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AIProviderError.missingAPIKey(provider.name)
        }
        let baseURL = try validatedBaseURL(for: provider)

        let url = try geminiURL(baseURL: baseURL, provider: provider)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(provider.apiKey, forHTTPHeaderField: "x-goog-api-key")

        let parts = geminiParts(prompt: prompt, sessionMessages: sessionMessages)
        let body: [String: Any] = [
            "systemInstruction": [
                "parts": [
                    ["text": prompt.systemPrompt]
                ]
            ],
            "contents": parts,
            "generationConfig": [
                "temperature": provider.temperature
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)

        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = root["candidates"] as? [[String: Any]],
            let firstCandidate = candidates.first,
            let content = firstCandidate["content"] as? [String: Any],
            let parts = content["parts"] as? [[String: Any]]
        else {
            throw AIProviderError.emptyResponse
        }

        let text = parts
            .compactMap { $0["text"] as? String }
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            throw AIProviderError.emptyResponse
        }

        return text
    }

    private static func sendOllama(
        prompt: PreparedPrompt,
        sessionMessages: [AIChatMessage],
        provider: AIProviderConfiguration
    ) async throws -> String {
        let baseURL = try validatedBaseURL(for: provider)

        let url = baseURL.appendingPathComponent("api/chat")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let messages = openAIStyleMessages(prompt: prompt, sessionMessages: sessionMessages)
        let body: [String: Any] = [
            "model": provider.model,
            "stream": false,
            "messages": messages,
            "options": [
                "temperature": provider.temperature
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, _) = try await URLSession.shared.data(for: request)

        guard
            let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            throw AIProviderError.emptyResponse
        }

        if let message = root["message"] as? [String: Any],
           let content = message["content"] as? String,
           !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let content = root["response"] as? String,
           !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        throw AIProviderError.emptyResponse
    }

    private static func validatedBaseURL(for provider: AIProviderConfiguration) throws -> URL {
        guard let baseURL = URL(string: provider.baseURLString),
              let scheme = baseURL.scheme?.lowercased(),
              let host = baseURL.host?.lowercased(),
              !host.isEmpty
        else {
            throw AIProviderError.invalidBaseURL(provider.baseURLString)
        }

        if scheme == "https" {
            return baseURL
        }

        guard scheme == "http",
              allowsLocalHTTP(for: provider.kind, host: host)
        else {
            throw AIProviderError.insecureBaseURL(provider.baseURLString)
        }

        return baseURL
    }

    private static func allowsLocalHTTP(for kind: AIProviderKind, host: String) -> Bool {
        guard kind == .ollama || kind == .openAICompatible else {
            return false
        }

        return host == "localhost"
            || host == "127.0.0.1"
            || host == "::1"
            || host.hasSuffix(".localhost")
    }

    static func geminiURL(baseURL: URL, provider: AIProviderConfiguration) throws -> URL {
        let endpointURL = baseURL.appendingPathComponent("v1beta/models/\(provider.model):generateContent")
        guard let url = URLComponents(url: endpointURL, resolvingAgainstBaseURL: false)?.url else {
            throw AIProviderError.invalidBaseURL(provider.baseURLString)
        }

        return url
    }

    private static func openAIStyleMessages(prompt: PreparedPrompt, sessionMessages: [AIChatMessage]) -> [[String: String]] {
        var messages: [[String: String]] = [["role": "system", "content": prompt.systemPrompt]]
        messages += sessionMessages.map { ["role": $0.role.rawValue, "content": $0.content] }
        messages.append(["role": "user", "content": prompt.userPrompt])
        return messages
    }

    private static func anthropicMessages(prompt: PreparedPrompt, sessionMessages: [AIChatMessage]) -> [[String: Any]] {
        var messages: [[String: Any]] = sessionMessages.map {
            [
                "role": $0.role == .assistant ? "assistant" : "user",
                "content": [["type": "text", "text": $0.content]]
            ]
        }
        messages.append(
            [
                "role": "user",
                "content": [["type": "text", "text": prompt.userPrompt]]
            ]
        )
        return messages
    }

    private static func geminiParts(prompt: PreparedPrompt, sessionMessages: [AIChatMessage]) -> [[String: Any]] {
        var contents: [[String: Any]] = sessionMessages.map {
            [
                "role": $0.role == .assistant ? "model" : "user",
                "parts": [["text": $0.content]]
            ]
        }
        contents.append(
            [
                "role": "user",
                "parts": [["text": prompt.userPrompt]]
            ]
        )
        return contents
    }
}
