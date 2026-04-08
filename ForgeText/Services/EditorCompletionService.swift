import Foundation

struct EditorCompletionSuggestion: Identifiable, Hashable {
    let displayText: String
    let insertText: String
    let detail: String

    var id: String {
        "\(displayText)|\(insertText)|\(detail)"
    }
}

struct EditorCompletionSession {
    let replacementRange: NSRange
    let prefix: String
    let suggestions: [EditorCompletionSuggestion]
}

enum EditorCompletionService {
    static func session(
        in text: String,
        selectedRange: NSRange,
        language: DocumentLanguage,
        sourceURL: URL?,
        maxResults: Int = 5
    ) -> EditorCompletionSession? {
        let nsText = text as NSString
        let clampedSelection = clamp(selectedRange, upperBound: nsText.length)
        guard clampedSelection.length == 0 else {
            return nil
        }

        let context = CompletionContext(
            text: text,
            nsText: nsText,
            selectionLocation: clampedSelection.location,
            language: language,
            sourceURL: sourceURL
        )

        let candidates = seedCandidates(for: context) + documentDerivedCandidates(for: context)
        let suggestions = rankedSuggestions(from: candidates, context: context, maxResults: maxResults)
        guard !suggestions.isEmpty else {
            return nil
        }

        return EditorCompletionSession(
            replacementRange: context.replacementRange,
            prefix: context.prefix,
            suggestions: suggestions
        )
    }

    static func mutation(for suggestion: EditorCompletionSuggestion, in session: EditorCompletionSession) -> EditorMutation {
        let insertedLength = (suggestion.insertText as NSString).length
        return EditorMutation(
            replacementRange: session.replacementRange,
            replacementText: suggestion.insertText,
            selectedRange: NSRange(location: session.replacementRange.location + insertedLength, length: 0)
        )
    }

    private struct CompletionContext {
        let text: String
        let nsText: NSString
        let selectionLocation: Int
        let language: DocumentLanguage
        let sourceURL: URL?
        let profile: CompletionProfile
        let lineBeforeCaret: String
        let lineAfterCaret: String
        let trimmedLineBeforeCaret: String
        let prefix: String
        let replacementRange: NSRange
        let characterBeforePrefix: Character?
        let isAtIndentedLineStart: Bool
        let allowsEmptyPrefixPredictions: Bool

        init(text: String, nsText: NSString, selectionLocation: Int, language: DocumentLanguage, sourceURL: URL?) {
            self.text = text
            self.nsText = nsText
            self.selectionLocation = selectionLocation
            self.language = language
            self.sourceURL = sourceURL
            profile = CompletionProfile.resolve(language: language, sourceURL: sourceURL)

            let lineRange = nsText.lineRange(for: NSRange(location: selectionLocation, length: 0))
            let beforeRange = NSRange(location: lineRange.location, length: selectionLocation - lineRange.location)
            let afterRange = NSRange(location: selectionLocation, length: NSMaxRange(lineRange) - selectionLocation)
            lineBeforeCaret = nsText.substring(with: beforeRange)
            lineAfterCaret = nsText.substring(with: afterRange)
            trimmedLineBeforeCaret = lineBeforeCaret.trimmingCharacters(in: .whitespaces)

            let tokenRange = Self.tokenRange(in: nsText, endingAt: selectionLocation)
            replacementRange = tokenRange
            prefix = nsText.substring(with: tokenRange)
            if tokenRange.location > 0 {
                characterBeforePrefix = Character(UnicodeScalar(nsText.character(at: tokenRange.location - 1))!)
            } else {
                characterBeforePrefix = nil
            }

            let leadingWhitespace = lineBeforeCaret.prefix { $0 == " " || $0 == "\t" }
            isAtIndentedLineStart = lineBeforeCaret == leadingWhitespace + prefix
            allowsEmptyPrefixPredictions = Self.allowsEmptyPrefixPredictions(
                for: profile,
                lineBeforeCaret: lineBeforeCaret,
                trimmedLineBeforeCaret: trimmedLineBeforeCaret,
                characterBeforePrefix: characterBeforePrefix,
                prefix: prefix
            )
        }

        private static func tokenRange(in text: NSString, endingAt location: Int) -> NSRange {
            var start = min(max(location, 0), text.length)
            while start > 0 {
                let scalar = UnicodeScalar(text.character(at: start - 1))!
                guard tokenCharacterSet.contains(scalar) else {
                    break
                }
                start -= 1
            }

            return NSRange(location: start, length: location - start)
        }

        private static func allowsEmptyPrefixPredictions(
            for profile: CompletionProfile,
            lineBeforeCaret: String,
            trimmedLineBeforeCaret: String,
            characterBeforePrefix: Character?,
            prefix: String
        ) -> Bool {
            guard prefix.isEmpty else {
                return false
            }

            switch profile {
            case .markdown, .yaml, .toml, .dotenv, .ini, .systemd:
                return trimmedLineBeforeCaret.isEmpty
            case .json:
                return characterBeforePrefix == "\"" || trimmedLineBeforeCaret.hasSuffix("{") || trimmedLineBeforeCaret.hasSuffix(",")
            case .http:
                return trimmedLineBeforeCaret.isEmpty || trimmedLineBeforeCaret.hasPrefix("Authorization")
            case .xml:
                return trimmedLineBeforeCaret.isEmpty || trimmedLineBeforeCaret == "<"
            case .swift, .shell, .javascript, .python, .css, .sql, .genericConfig, .plain:
                return false
            }
        }
    }

    private enum CompletionProfile {
        case plain
        case markdown
        case json
        case http
        case xml
        case swift
        case shell
        case javascript
        case python
        case css
        case sql
        case yaml
        case toml
        case dotenv
        case ini
        case systemd
        case genericConfig

        static func resolve(language: DocumentLanguage, sourceURL: URL?) -> CompletionProfile {
            switch language {
            case .markdown:
                return .markdown
            case .json:
                return .json
            case .http:
                return .http
            case .xml:
                return .xml
            case .swift:
                return .swift
            case .shell:
                return .shell
            case .javascript:
                return .javascript
            case .python:
                return .python
            case .css:
                return .css
            case .sql:
                return .sql
            case .config:
                guard let sourceURL else {
                    return .genericConfig
                }

                let filename = sourceURL.lastPathComponent.lowercased()
                let pathExtension = sourceURL.pathExtension.lowercased()
                if filename == ".env" || filename.hasPrefix(".env.") || pathExtension == "env" {
                    return .dotenv
                }
                if pathExtension == "yaml" || pathExtension == "yml" {
                    return .yaml
                }
                if pathExtension == "toml" {
                    return .toml
                }
                if ["ini", "cfg", "conf", "properties"].contains(pathExtension) {
                    return .ini
                }
                if ["service", "socket", "mount", "timer", "target", "path", "unit"].contains(pathExtension) {
                    return .systemd
                }
                return .genericConfig
            case .plainText, .csv, .log:
                return .plain
            }
        }
    }

    private struct Candidate {
        let matchText: String
        let suggestion: EditorCompletionSuggestion
        let priority: Int
        let allowWhenPrefixIsEmpty: Bool
    }

    private static let tokenCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))

    private static func seedCandidates(for context: CompletionContext) -> [Candidate] {
        switch context.profile {
        case .plain:
            return []
        case .markdown:
            return lineSnippetCandidates([
                ("# ", "# ", "Heading"),
                ("## ", "## ", "Section heading"),
                ("- ", "- ", "Bullet list"),
                ("- [ ] ", "- [ ] ", "Task list"),
                ("> ", "> ", "Block quote"),
                ("```", "```", "Code fence"),
            ])
        case .json:
            return jsonCandidates(for: context)
        case .http:
            return lineSnippetCandidates([
                ("GET", "GET https://", "HTTP request"),
                ("POST", "POST https://", "HTTP request"),
                ("Authorization", "Authorization: Bearer ", "HTTP header"),
                ("Content-Type", "Content-Type: application/json", "HTTP header"),
                ("Accept", "Accept: application/json", "HTTP header"),
            ])
        case .xml:
            return tagCandidates([
                "div", "span", "section", "header", "main", "footer", "script", "style", "item", "entry"
            ], detail: "XML / HTML tag")
        case .swift:
            return keywordCandidates([
                "func", "struct", "class", "enum", "protocol", "extension", "guard", "if", "else", "switch",
                "case", "return", "let", "var", "import", "Task", "async", "await"
            ], detail: "Swift keyword")
        case .shell:
            return keywordCandidates([
                "if", "then", "else", "fi", "for", "in", "do", "done", "case", "esac", "function", "export",
                "local", "source", "echo", "grep", "find", "sed", "awk", "xargs"
            ], detail: "Shell token")
        case .javascript:
            return keywordCandidates([
                "function", "const", "let", "import", "export", "async", "await", "return", "if", "else",
                "switch", "case", "class", "interface", "type", "console"
            ], detail: "JavaScript / TypeScript token")
        case .python:
            return keywordCandidates([
                "def", "class", "import", "from", "if", "elif", "else", "for", "while", "with", "try",
                "except", "finally", "return", "yield", "True", "False", "None"
            ], detail: "Python token")
        case .css:
            return keywordCandidates([
                "display", "position", "color", "background", "background-color", "justify-content",
                "align-items", "grid-template-columns", "padding", "margin", "font-size", "border-radius", "gap"
            ], detail: "CSS property")
        case .sql:
            return keywordCandidates([
                "SELECT", "FROM", "WHERE", "ORDER BY", "GROUP BY", "INSERT INTO", "UPDATE", "DELETE",
                "JOIN", "LEFT JOIN", "CREATE TABLE", "ALTER TABLE", "LIMIT"
            ], detail: "SQL keyword")
        case .yaml:
            return lineSnippetCandidates([
                ("name", "name: ", "YAML key"),
                ("version", "version: ", "YAML key"),
                ("services", "services:", "YAML section"),
                ("image", "image: ", "YAML key"),
                ("environment", "environment:", "YAML section"),
                ("ports", "ports:", "YAML section"),
                ("volumes", "volumes:", "YAML section"),
                ("enabled", "enabled: true", "YAML boolean"),
                ("path", "path: ", "YAML path"),
            ])
        case .toml:
            return lineSnippetCandidates([
                ("section", "[section]", "TOML section"),
                ("name", "name = \"\"", "TOML string"),
                ("version", "version = \"\"", "TOML string"),
                ("enabled", "enabled = true", "TOML boolean"),
                ("path", "path = \"\"", "TOML path"),
            ])
        case .dotenv:
            return lineSnippetCandidates([
                ("PORT", "PORT=", "Environment variable"),
                ("HOST", "HOST=", "Environment variable"),
                ("DATABASE_URL", "DATABASE_URL=", "Environment variable"),
                ("API_KEY", "API_KEY=", "Environment variable"),
                ("LOG_LEVEL", "LOG_LEVEL=", "Environment variable"),
                ("NODE_ENV", "NODE_ENV=", "Environment variable"),
            ])
        case .ini:
            return lineSnippetCandidates([
                ("section", "[section]", "INI section"),
                ("enabled", "enabled=true", "INI boolean"),
                ("path", "path=", "INI path"),
                ("host", "host=", "INI key"),
                ("port", "port=", "INI key"),
            ])
        case .systemd:
            return lineSnippetCandidates([
                ("Unit", "[Unit]", "systemd section"),
                ("Service", "[Service]", "systemd section"),
                ("Install", "[Install]", "systemd section"),
                ("Description", "Description=", "systemd key"),
                ("ExecStart", "ExecStart=", "systemd key"),
                ("WantedBy", "WantedBy=multi-user.target", "systemd key"),
            ])
        case .genericConfig:
            return lineSnippetCandidates([
                ("name", "name=", "Config key"),
                ("enabled", "enabled=true", "Config key"),
                ("path", "path=", "Config key"),
                ("host", "host=", "Config key"),
                ("port", "port=", "Config key"),
            ])
        }
    }

    private static func jsonCandidates(for context: CompletionContext) -> [Candidate] {
        let isQuotedKeyPosition = context.characterBeforePrefix == "\""
        let commonKeys = [
            "name", "version", "description", "type", "id", "enabled", "path", "host", "port", "items",
            "config", "metadata", "status", "message", "timeout"
        ]
        let keyCandidates = commonKeys.map { key -> Candidate in
            let insertText = isQuotedKeyPosition ? "\(key)\": " : key
            let display = isQuotedKeyPosition ? "\"\(key)\": " : key
            return Candidate(
                matchText: key,
                suggestion: EditorCompletionSuggestion(displayText: display, insertText: insertText, detail: "JSON key"),
                priority: 240,
                allowWhenPrefixIsEmpty: context.allowsEmptyPrefixPredictions
            )
        }

        let literalCandidates = [
            Candidate(
                matchText: "true",
                suggestion: EditorCompletionSuggestion(displayText: "true", insertText: "true", detail: "JSON literal"),
                priority: 200,
                allowWhenPrefixIsEmpty: false
            ),
            Candidate(
                matchText: "false",
                suggestion: EditorCompletionSuggestion(displayText: "false", insertText: "false", detail: "JSON literal"),
                priority: 200,
                allowWhenPrefixIsEmpty: false
            ),
            Candidate(
                matchText: "null",
                suggestion: EditorCompletionSuggestion(displayText: "null", insertText: "null", detail: "JSON literal"),
                priority: 200,
                allowWhenPrefixIsEmpty: false
            ),
        ]

        return keyCandidates + literalCandidates
    }

    private static func keywordCandidates(_ values: [String], detail: String) -> [Candidate] {
        values.map { value in
            Candidate(
                matchText: value.replacingOccurrences(of: " ", with: ""),
                suggestion: EditorCompletionSuggestion(displayText: value, insertText: value, detail: detail),
                priority: 180,
                allowWhenPrefixIsEmpty: false
            )
        }
    }

    private static func tagCandidates(_ tags: [String], detail: String) -> [Candidate] {
        tags.map { tag in
            Candidate(
                matchText: tag,
                suggestion: EditorCompletionSuggestion(displayText: "<\(tag)>", insertText: tag, detail: detail),
                priority: 180,
                allowWhenPrefixIsEmpty: false
            )
        }
    }

    private static func lineSnippetCandidates(_ values: [(String, String, String)]) -> [Candidate] {
        values.map { matchText, insertText, detail in
            Candidate(
                matchText: matchText,
                suggestion: EditorCompletionSuggestion(displayText: insertText, insertText: insertText, detail: detail),
                priority: 220,
                allowWhenPrefixIsEmpty: true
            )
        }
    }

    private static func documentDerivedCandidates(for context: CompletionContext) -> [Candidate] {
        guard context.prefix.count >= 2, context.text.utf16.count < 250_000 else {
            return []
        }

        let pattern = #"[A-Za-z_][A-Za-z0-9_-]{2,}"#
        guard let expression = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let fullRange = NSRange(location: 0, length: context.nsText.length)
        let matches = expression.matches(in: context.text, options: [], range: fullRange)
        guard !matches.isEmpty else {
            return []
        }

        var frequencies: [String: Int] = [:]
        for match in matches {
            let value = context.nsText.substring(with: match.range)
            frequencies[value, default: 0] += 1
        }

        let normalizedPrefix = context.prefix.lowercased()
        return frequencies
            .filter { key, _ in key.lowercased().hasPrefix(normalizedPrefix) && key.caseInsensitiveCompare(context.prefix) != .orderedSame }
            .sorted { lhs, rhs in
                if lhs.value != rhs.value {
                    return lhs.value > rhs.value
                }

                return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
            }
            .prefix(12)
            .map { key, _ in
                let insertText: String
                let detail: String
                if context.profile == .json, context.characterBeforePrefix == "\"" {
                    insertText = "\(key)\": "
                    detail = "Existing JSON key"
                } else {
                    insertText = key
                    detail = "From current file"
                }

                return Candidate(
                    matchText: key,
                    suggestion: EditorCompletionSuggestion(displayText: insertText, insertText: insertText, detail: detail),
                    priority: 260,
                    allowWhenPrefixIsEmpty: false
                )
            }
    }

    private static func rankedSuggestions(from candidates: [Candidate], context: CompletionContext, maxResults: Int) -> [EditorCompletionSuggestion] {
        let normalizedPrefix = context.prefix.lowercased()
        var seen = Set<String>()

        let ranked = candidates.compactMap { candidate -> (score: Int, suggestion: EditorCompletionSuggestion)? in
            let normalizedMatchText = candidate.matchText.lowercased()
            let score: Int

            if normalizedPrefix.isEmpty {
                guard context.allowsEmptyPrefixPredictions, candidate.allowWhenPrefixIsEmpty else {
                    return nil
                }
                score = candidate.priority
            } else if normalizedMatchText.hasPrefix(normalizedPrefix) {
                score = candidate.priority + 400 - min(normalizedMatchText.count, 60)
            } else if normalizedMatchText.contains(normalizedPrefix) {
                score = candidate.priority + 150 - min(normalizedMatchText.count, 60)
            } else {
                return nil
            }

            let dedupeKey = "\(candidate.suggestion.displayText)|\(candidate.suggestion.insertText)"
            guard seen.insert(dedupeKey).inserted else {
                return nil
            }

            return (score, candidate.suggestion)
        }

        return ranked
            .sorted {
                if $0.score != $1.score {
                    return $0.score > $1.score
                }

                return $0.suggestion.displayText.localizedCaseInsensitiveCompare($1.suggestion.displayText) == .orderedAscending
            }
            .prefix(maxResults)
            .map(\.suggestion)
    }

    private static func clamp(_ range: NSRange, upperBound: Int) -> NSRange {
        let location = min(max(range.location, 0), upperBound)
        let length = min(max(range.length, 0), upperBound - location)
        return NSRange(location: location, length: length)
    }
}
