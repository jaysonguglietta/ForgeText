import Foundation

enum PluginFormattingService {
    enum FormattingError: LocalizedError {
        case unsupportedLanguage(DocumentLanguage)
        case invalidUTF8
        case formatterUnavailable(DocumentLanguage)
        case externalToolsRestricted(DocumentLanguage)

        var errorDescription: String? {
            switch self {
            case let .unsupportedLanguage(language):
                return "No built-in formatter is available for \(language.displayName) yet."
            case .invalidUTF8:
                return "ForgeText couldn’t convert the formatted result back into UTF-8 text."
            case let .formatterUnavailable(language):
                return "ForgeText couldn’t find a local formatter for \(language.displayName)."
            case let .externalToolsRestricted(language):
                return "Formatting \(language.displayName) requires an external tool, which is disabled in restricted workspaces or by managed policy."
            }
        }
    }

    static func format(_ document: EditorDocument, allowsExternalTools: Bool = false) throws -> String {
        if allowsExternalTools, let externallyFormatted = try formatUsingExternalTool(document) {
            return externallyFormatted
        }

        if !allowsExternalTools,
           [.markdown, .swift, .shell, .javascript, .css, .config].contains(document.language) {
            throw FormattingError.externalToolsRestricted(document.language)
        }

        switch document.language {
        case .json:
            return try formatJSON(document.text)
        case .xml:
            return try formatXML(document.text)
        case .http:
            return normalizeHTTPRequest(document.text)
        case .plainText, .csv, .markdown, .swift, .shell, .javascript, .python, .css, .sql, .config, .log:
            throw FormattingError.formatterUnavailable(document.language)
        }
    }

    private static func formatJSON(_ text: String) throws -> String {
        guard let data = text.data(using: .utf8) else {
            throw FormattingError.invalidUTF8
        }

        let object = try JSONSerialization.jsonObject(with: data)
        let formattedData = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])

        guard let formattedText = String(data: formattedData, encoding: .utf8) else {
            throw FormattingError.invalidUTF8
        }

        return formattedText
    }

    private static func formatXML(_ text: String) throws -> String {
        let document = try XMLDocument(xmlString: text, options: [.nodePreserveAll])
        let data = document.xmlData(options: [.nodePrettyPrint])

        guard let formattedText = String(data: data, encoding: .utf8) else {
            throw FormattingError.invalidUTF8
        }

        return formattedText
    }

    private static func formatUsingExternalTool(_ document: EditorDocument) throws -> String? {
        guard let data = document.text.data(using: .utf8) else {
            throw FormattingError.invalidUTF8
        }

        switch document.language {
        case .javascript, .css, .markdown, .config:
            return try runPrettier(on: data, sourceURL: document.sourceURL)
        case .shell:
            return try runFormatter(named: "shfmt", arguments: [], input: data)
        case .swift:
            guard ToolchainService.isAvailable("swift-format") else {
                return nil
            }

            let sourcePath = document.sourceURL?.path ?? "stdin.swift"
            return try runFormatter(
                named: "swift-format",
                arguments: ["format", "--assume-filename", sourcePath],
                input: data
            )
        case .http:
            return nil
        case .json, .xml, .plainText, .csv, .python, .sql, .log:
            return nil
        }
    }

    private static func runPrettier(on data: Data, sourceURL: URL?) throws -> String? {
        guard ToolchainService.trustedExecutablePath(named: "prettier") != nil else {
            return nil
        }

        let sourcePath = sourceURL?.path ?? "stdin.txt"
        return try runFormatter(
            named: "prettier",
            arguments: ["--no-config", "--no-editorconfig", "--stdin-filepath", sourcePath],
            input: data
        )
    }

    private static func runFormatter(named executable: String, arguments: [String], input: Data) throws -> String? {
        guard let executablePath = ToolchainService.trustedExecutablePath(named: executable) else {
            return nil
        }

        let output = try CommandExecutionService.run(
            executablePath,
            arguments: arguments,
            input: input,
            environment: ["NO_COLOR": "1"],
            limits: .formatter
        )

        guard let text = String(data: output, encoding: .utf8) else {
            throw FormattingError.invalidUTF8
        }

        return text
    }

    private static func normalizeHTTPRequest(_ text: String) -> String {
        guard let requestDocument = HTTPRequestService.parse(text) else {
            return text
        }

        return requestDocument.requests.map { request in
            let headerLines = request.headers.map { "\($0.name): \($0.value)" }
            let bodyBlock = request.body.isEmpty ? "" : "\n\n\(request.body)"

            let commentLine = request.name == "\(request.method) \(request.urlString)" ? "" : "### \(request.name)\n"
            return commentLine + "\(request.method) \(request.urlString)\n" + headerLines.joined(separator: "\n") + bodyBlock
        }
        .joined(separator: "\n\n")
    }
}
