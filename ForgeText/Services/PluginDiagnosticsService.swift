import Foundation

enum PluginDiagnosticsService {
    static func diagnostics(for document: EditorDocument) -> [PluginDiagnostic] {
        var diagnostics: [PluginDiagnostic] = []

        switch document.language {
        case .json:
            diagnostics += jsonDiagnostics(in: document.text)
        case .http:
            diagnostics += httpDiagnostics(in: document.text)
        case .xml:
            diagnostics += xmlDiagnostics(in: document.text)
        case .csv:
            diagnostics += delimitedDiagnostics(in: document)
        case .config:
            diagnostics += configDiagnostics(in: document)
        case .markdown, .plainText, .swift, .shell, .javascript, .python, .css, .sql, .log:
            break
        }

        diagnostics += secretDiagnostics(in: document.text)
        diagnostics += todoDiagnostics(in: document.text)

        return diagnostics.sorted { lhs, rhs in
            severityRank(lhs.severity) > severityRank(rhs.severity)
        }
    }

    private static func jsonDiagnostics(in text: String) -> [PluginDiagnostic] {
        guard let data = text.data(using: .utf8) else {
            return [
                PluginDiagnostic(
                    source: "JSON",
                    severity: .error,
                    message: "The document could not be read as UTF-8 JSON."
                )
            ]
        }

        do {
            _ = try JSONSerialization.jsonObject(with: data)
            return []
        } catch {
            let nsError = error as NSError
            let index = nsError.userInfo["NSJSONSerializationErrorIndex"] as? Int
            let parsedLineNumber = index.map { utf16Offset in
                lineNumber(atUTF16Offset: utf16Offset, in: text)
            }
            let detail = nsError.userInfo["NSDebugDescription"] as? String

            return [
                PluginDiagnostic(
                    source: "JSON",
                    severity: .error,
                    message: "JSON parsing failed.",
                    lineNumber: parsedLineNumber,
                    detail: detail ?? error.localizedDescription
                )
            ]
        }
    }

    private static func xmlDiagnostics(in text: String) -> [PluginDiagnostic] {
        guard let data = text.data(using: .utf8) else {
            return [
                PluginDiagnostic(
                    source: "XML",
                    severity: .error,
                    message: "The document could not be read as UTF-8 XML."
                )
            ]
        }

        let delegate = XMLParserErrorDelegate()
        let parser = XMLParser(data: data)
        parser.delegate = delegate

        if parser.parse() {
            return []
        }

        return [
            PluginDiagnostic(
                source: "XML",
                severity: .error,
                message: "XML parsing failed.",
                lineNumber: delegate.lineNumber > 0 ? delegate.lineNumber : nil,
                detail: delegate.message ?? parser.parserError?.localizedDescription
            )
        ]
    }

    private static func httpDiagnostics(in text: String) -> [PluginDiagnostic] {
        guard HTTPRequestService.parse(text) != nil else {
            return [
                PluginDiagnostic(
                    source: "HTTP Runner",
                    severity: .warning,
                    message: "ForgeText could not parse a valid HTTP request block from this document."
                ),
            ]
        }

        return []
    }

    private static func delimitedDiagnostics(in document: EditorDocument) -> [PluginDiagnostic] {
        let detectedDelimiter = preferredDelimiter(for: document.fileURL)
        let rows = parseDelimitedRows(document.text, preferredDelimiter: detectedDelimiter)

        switch rows {
        case .failure:
            return [
                PluginDiagnostic(
                    source: "Delimited Text",
                    severity: .error,
                    message: "The file has unbalanced quotes or malformed row boundaries."
                )
            ]
        case let .success(parsedRows):
            guard let expectedWidth = parsedRows.first?.cells.count else {
                return []
            }

            return parsedRows.compactMap { row in
                guard row.cells.count != expectedWidth else {
                    return nil
                }

                return PluginDiagnostic(
                    source: "Delimited Text",
                    severity: .warning,
                    message: "Expected \(expectedWidth) columns but found \(row.cells.count).",
                    lineNumber: row.lineNumber
                )
            }
        }
    }

    private static func configDiagnostics(in document: EditorDocument) -> [PluginDiagnostic] {
        guard let parsed = StructuredConfigService.parse(document.text, url: document.fileURL) else {
            return [
                PluginDiagnostic(
                    source: "Config Inspector",
                    severity: .warning,
                    message: "ForgeText could not extract structured configuration entries from this document."
                )
            ]
        }

        var diagnostics: [PluginDiagnostic] = []
        collectDuplicateKeyDiagnostics(in: parsed.nodes, into: &diagnostics)
        return diagnostics
    }

    private static func todoDiagnostics(in text: String) -> [PluginDiagnostic] {
        var diagnostics: [PluginDiagnostic] = []
        var lineNumber = 0

        text.enumerateLines { line, _ in
            lineNumber += 1
            let uppercaseLine = line.uppercased()
            let marker: String?

            if uppercaseLine.contains("FIXME") {
                marker = "FIXME"
            } else if uppercaseLine.contains("TODO") {
                marker = "TODO"
            } else if uppercaseLine.contains("XXX") {
                marker = "XXX"
            } else {
                marker = nil
            }

            guard let marker else {
                return
            }

            diagnostics.append(
                PluginDiagnostic(
                    source: "Task Marker",
                    severity: .info,
                    message: "\(marker) marker found in document.",
                    lineNumber: lineNumber,
                    detail: line.trimmingCharacters(in: .whitespacesAndNewlines)
                )
            )
        }

        return diagnostics
    }

    private static func secretDiagnostics(in text: String) -> [PluginDiagnostic] {
        let patterns: [(source: String, severity: PluginDiagnosticSeverity, pattern: String, message: String)] = [
            ("Secrets", .error, #"(?m)-----BEGIN [A-Z ]*PRIVATE KEY-----"#, "Private key material detected."),
            ("Secrets", .warning, #"\bAKIA[0-9A-Z]{16}\b"#, "Possible AWS access key detected."),
            ("Secrets", .warning, #"\bgh[pousr]_[A-Za-z0-9]{20,}\b"#, "Possible GitHub token detected."),
            ("Secrets", .warning, #"(?mi)\b(?:api[_-]?key|secret|token|password)\s*[:=]\s*["']?[A-Za-z0-9_\-\/+=]{8,}"#, "Possible credential or secret assignment detected."),
            ("Secrets", .warning, #"(?mi)\bAuthorization:\s*Bearer\s+[A-Za-z0-9\-._~+/]+=*"#, "Bearer token header detected."),
        ]

        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        var diagnostics: [PluginDiagnostic] = []

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern.pattern) else {
                continue
            }

            for match in regex.matches(in: text, range: fullRange) {
                let matchedText = nsText.substring(with: match.range)
                diagnostics.append(
                    PluginDiagnostic(
                        source: pattern.source,
                        severity: pattern.severity,
                        message: pattern.message,
                        lineNumber: lineNumber(atUTF16Offset: match.range.location, in: text),
                        detail: matchedText
                    )
                )
            }
        }

        return diagnostics
    }

    private static func collectDuplicateKeyDiagnostics(
        in nodes: [StructuredConfigNode],
        into diagnostics: inout [PluginDiagnostic]
    ) {
        let duplicates = Dictionary(
            grouping: nodes.filter { $0.kind != .arrayItem },
            by: { $0.key.lowercased() }
        )
            .values
            .filter { $0.count > 1 }

        for duplicateGroup in duplicates {
            for node in duplicateGroup {
                diagnostics.append(
                    PluginDiagnostic(
                        source: "Config Inspector",
                        severity: .warning,
                        message: "Duplicate key '\(node.key)' appears multiple times in this section.",
                        lineNumber: node.lineNumber
                    )
                )
            }
        }

        for node in nodes where !node.children.isEmpty {
            collectDuplicateKeyDiagnostics(in: node.children, into: &diagnostics)
        }
    }

    private static func preferredDelimiter(for url: URL?) -> Character? {
        switch url?.pathExtension.lowercased() {
        case "tsv", "tab":
            return "\t"
        case "csv":
            return ","
        default:
            return nil
        }
    }

    private static func parseDelimitedRows(
        _ text: String,
        preferredDelimiter: Character?
    ) -> Result<[(lineNumber: Int, cells: [String])], Error> {
        let delimiterCandidates: [Character]
        if let preferredDelimiter {
            delimiterCandidates = [preferredDelimiter]
        } else {
            delimiterCandidates = [",", "\t", ";", "|"]
        }

        for delimiter in delimiterCandidates {
            if let parsed = parseDelimitedRows(text, delimiter: delimiter) {
                return .success(parsed)
            }
        }

        return .failure(NSError(domain: "ForgeText.Delimited", code: 1))
    }

    private static func parseDelimitedRows(
        _ text: String,
        delimiter: Character
    ) -> [(lineNumber: Int, cells: [String])]? {
        var rows: [(lineNumber: Int, cells: [String])] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false
        var currentLineNumber = 1
        var rowStartLine = 1
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]

            if insideQuotes {
                if character == "\"" {
                    let nextIndex = text.index(after: index)
                    if nextIndex < text.endIndex, text[nextIndex] == "\"" {
                        currentField.append("\"")
                        index = text.index(after: nextIndex)
                        continue
                    }

                    insideQuotes = false
                    index = text.index(after: index)
                    continue
                }

                if character == "\n" {
                    currentLineNumber += 1
                }

                currentField.append(character)
                index = text.index(after: index)
                continue
            }

            switch character {
            case "\"":
                insideQuotes = true
            case delimiter:
                currentRow.append(currentField)
                currentField = ""
            case "\n":
                currentRow.append(currentField)
                rows.append((rowStartLine, currentRow))
                currentRow = []
                currentField = ""
                currentLineNumber += 1
                rowStartLine = currentLineNumber
            case "\r":
                currentRow.append(currentField)
                rows.append((rowStartLine, currentRow))
                currentRow = []
                currentField = ""

                let nextIndex = text.index(after: index)
                if nextIndex < text.endIndex, text[nextIndex] == "\n" {
                    index = nextIndex
                }
                currentLineNumber += 1
                rowStartLine = currentLineNumber
            default:
                currentField.append(character)
            }

            index = text.index(after: index)
        }

        guard !insideQuotes else {
            return nil
        }

        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append((rowStartLine, currentRow))
        }

        return rows.filter { row in
            row.cells.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
    }

    private static func lineNumber(atUTF16Offset offset: Int, in text: String) -> Int {
        let utf16 = text.utf16
        var consumed = 0
        var line = 1

        for scalar in utf16 {
            if consumed >= offset {
                break
            }

            if scalar == 10 {
                line += 1
            }
            consumed += 1
        }

        return line
    }

    private static func severityRank(_ severity: PluginDiagnosticSeverity) -> Int {
        switch severity {
        case .error:
            return 3
        case .warning:
            return 2
        case .info:
            return 1
        }
    }
}

private final class XMLParserErrorDelegate: NSObject, XMLParserDelegate {
    var lineNumber: Int = 0
    var message: String?

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        lineNumber = Int(parser.lineNumber)
        message = parseError.localizedDescription
    }
}
