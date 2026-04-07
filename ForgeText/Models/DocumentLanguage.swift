import Foundation

enum DocumentLanguage: String, CaseIterable, Identifiable, Codable {
    case plainText
    case csv
    case markdown
    case json
    case xml
    case swift
    case shell
    case javascript
    case python
    case css
    case sql
    case config
    case log

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .plainText:
            return "Plain Text"
        case .csv:
            return "CSV / Delimited"
        case .markdown:
            return "Markdown"
        case .json:
            return "JSON"
        case .xml:
            return "XML / HTML"
        case .swift:
            return "Swift"
        case .shell:
            return "Shell"
        case .javascript:
            return "JavaScript / TypeScript"
        case .python:
            return "Python"
        case .css:
            return "CSS"
        case .sql:
            return "SQL"
        case .config:
            return "Config"
        case .log:
            return "Log"
        }
    }

    var symbolName: String {
        switch self {
        case .plainText:
            return "doc.text"
        case .csv:
            return "tablecells"
        case .markdown:
            return "textformat"
        case .json:
            return "curlybraces"
        case .xml:
            return "chevron.left.forwardslash.chevron.right"
        case .swift:
            return "swift"
        case .shell:
            return "terminal"
        case .javascript:
            return "curlybraces.square"
        case .python:
            return "chevron.left.forwardslash.chevron.right"
        case .css:
            return "paintbrush.pointed"
        case .sql:
            return "cylinder.split.1x2"
        case .config:
            return "slider.horizontal.3"
        case .log:
            return "doc.plaintext"
        }
    }

    var lineCommentPrefix: String? {
        switch self {
        case .swift, .javascript, .css:
            return "//"
        case .shell, .python, .config, .log:
            return "#"
        case .sql:
            return "--"
        case .plainText, .csv, .markdown, .json, .xml:
            return nil
        }
    }

    var indentUnit: String {
        switch self {
        case .markdown, .css, .json, .xml, .config:
            return "  "
        case .plainText, .csv, .swift, .shell, .javascript, .python, .sql, .log:
            return "    "
        }
    }

    var bracketPairs: [Character: Character] {
        switch self {
        case .markdown, .log, .plainText, .csv, .shell, .python, .config, .swift, .javascript, .json, .css, .sql, .xml:
            return ["(": ")", "[": "]", "{": "}"]
        }
    }

    var structuredPresentationMode: DocumentPresentationMode? {
        switch self {
        case .csv:
            return .structuredTable
        case .json:
            return .structuredJSON
        case .log:
            return .logExplorer
        case .config:
            return .structuredConfig
        case .plainText, .markdown, .xml, .swift, .shell, .javascript, .python, .css, .sql:
            return nil
        }
    }

    func openingBracket(for closingBracket: Character) -> Character? {
        bracketPairs.first { $0.value == closingBracket }?.key
    }

    func shouldIncreaseIndent(after textBeforeCaret: String) -> Bool {
        let trimmed = textBeforeCaret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        switch self {
        case .swift, .javascript, .json, .css, .sql, .xml:
            return trimmed.hasSuffix("{") || trimmed.hasSuffix("[") || trimmed.hasSuffix("(")
        case .python:
            return trimmed.hasSuffix(":")
        case .shell:
            return trimmed.hasSuffix("do") || trimmed.hasSuffix("then") || trimmed.hasSuffix("{")
        case .config:
            return trimmed.hasSuffix("{") || trimmed.hasSuffix("[")
        case .markdown, .log, .plainText, .csv:
            return false
        }
    }

    func shouldDecreaseIndent(before textAfterCaret: String) -> Bool {
        let trimmed = textAfterCaret.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        switch self {
        case .swift, .javascript, .json, .css, .sql, .config:
            return trimmed.hasPrefix("}") || trimmed.hasPrefix("]") || trimmed.hasPrefix(")")
        case .xml:
            return trimmed.hasPrefix("</")
        case .plainText, .csv, .markdown, .shell, .python, .log:
            return false
        }
    }

    static func detect(from url: URL?, text: String? = nil) -> DocumentLanguage {
        if let url {
            if let language = detectFromFilename(url.lastPathComponent) {
                return language
            }

            if let language = detectFromPathExtension(url.pathExtension) {
                return language
            }
        }

        if let text, let language = detectFromContent(text) {
            return language
        }

        return .plainText
    }

    private static func detectFromFilename(_ filename: String) -> DocumentLanguage? {
        let lowercased = filename.lowercased()

        switch lowercased {
        case "dockerfile", "makefile", ".gitignore", ".editorconfig", ".env", "procfile", "justfile", "nginx.conf", "kubeconfig":
            return .config
        case ".bashrc", ".bash_profile", ".profile", ".zshrc", ".zprofile", ".zshenv", ".zlogin", ".zlogout", ".envrc":
            return .shell
        case "readme", "readme.txt", "readme.md":
            return .markdown
        default:
            return nil
        }
    }

    private static func detectFromPathExtension(_ pathExtension: String) -> DocumentLanguage? {
        switch pathExtension.lowercased() {
        case "csv", "tsv", "tab":
            return .csv
        case "md", "markdown", "mkd", "mdown", "rmd":
            return .markdown
        case "json", "jsonc":
            return .json
        case "xml", "html", "htm", "svg", "xhtml", "plist":
            return .xml
        case "swift":
            return .swift
        case "sh", "bash", "zsh", "fish", "command":
            return .shell
        case "js", "jsx", "mjs", "cjs", "ts", "tsx":
            return .javascript
        case "py", "pyw":
            return .python
        case "css", "scss", "sass", "less":
            return .css
        case "sql", "psql":
            return .sql
        case "ini", "toml", "yaml", "yml", "conf", "cfg", "env", "properties", "tf", "tfvars", "service", "socket", "mount", "timer", "target", "path", "rules":
            return .config
        case "log", "out", "err", "trace":
            return .log
        default:
            return nil
        }
    }

    private static func detectFromContent(_ text: String) -> DocumentLanguage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if let language = detectFromShebang(text) {
            return language
        }

        if isJSON(trimmed) {
            return .json
        }

        if looksLikeDelimitedTable(text) {
            return .csv
        }

        if isXMLLike(trimmed) {
            return .xml
        }

        if looksLikeMarkdown(text) {
            return .markdown
        }

        if looksLikeSwift(text) {
            return .swift
        }

        if looksLikeJavaScript(text) {
            return .javascript
        }

        if looksLikePython(text) {
            return .python
        }

        if looksLikeCSS(text) {
            return .css
        }

        if looksLikeSQL(trimmed) {
            return .sql
        }

        if looksLikeLog(text) {
            return .log
        }

        if looksLikeInfrastructureConfig(text) {
            return .config
        }

        if looksLikeConfig(text) {
            return .config
        }

        return nil
    }

    private static func detectFromShebang(_ text: String) -> DocumentLanguage? {
        guard let firstLine = text.split(whereSeparator: \.isNewline).first?.lowercased(), firstLine.hasPrefix("#!") else {
            return nil
        }

        if firstLine.contains("python") {
            return .python
        }

        if firstLine.contains("node") || firstLine.contains("deno") || firstLine.contains("bun") {
            return .javascript
        }

        if firstLine.contains("bash") || firstLine.contains("zsh") || firstLine.contains("sh") || firstLine.contains("fish") {
            return .shell
        }

        return nil
    }

    private static func isJSON(_ trimmed: String) -> Bool {
        guard
            let data = trimmed.data(using: .utf8),
            let jsonObject = try? JSONSerialization.jsonObject(with: data)
        else {
            return false
        }

        return jsonObject is [String: Any] || jsonObject is [Any]
    }

    private static func isXMLLike(_ trimmed: String) -> Bool {
        let candidates = ["<?xml", "<!doctype html", "<html", "<svg", "<body", "<div", "<!--"]
        return candidates.contains { trimmed.lowercased().hasPrefix($0) }
            || trimmed.first == "<" && trimmed.dropFirst().first?.isLetter == true
    }

    private static func looksLikeMarkdown(_ text: String) -> Bool {
        let patterns = [
            #"(?m)^#{1,6}\s+\S"#,
            #"(?m)^[-*+]\s+\S"#,
            #"(?m)^\d+\.\s+\S"#,
            #"(?m)^>\s+\S"#,
            #"(?ms)^```.*?^```"#,
            #"\[[^\]]+\]\([^)]+\)"#,
        ]

        return matchesAnyPattern(patterns, in: text)
    }

    private static func looksLikeSwift(_ text: String) -> Bool {
        let patterns = [
            #"(?m)^\s*import\s+(SwiftUI|Foundation|AppKit)\b"#,
            #"(?m)^\s*(struct|class|enum|protocol|extension|func)\s+\w+"#,
            #"(?m)^\s*(let|var)\s+\w+"#,
        ]

        return matchesAnyPattern(patterns, in: text)
    }

    private static func looksLikeJavaScript(_ text: String) -> Bool {
        let patterns = [
            #"(?m)^\s*(const|let|var)\s+\w+"#,
            #"(?m)^\s*export\s+(default|const|function|class|let|var)\b"#,
            #"(?m)^\s*import\s+[\w\{\}\*\s,]+\s+from\s+['"]"#,
            #"=>\s*\{"#,
            #"(?m)^\s*function\s+\w+\s*\("#,
        ]

        return matchesAnyPattern(patterns, in: text)
    }

    private static func looksLikePython(_ text: String) -> Bool {
        let patterns = [
            #"(?m)^\s*def\s+\w+\s*\("#,
            #"(?m)^\s*class\s+\w+\s*[:(]"#,
            #"(?m)^\s*from\s+\w+\s+import\s+\w+"#,
            #"(?m)^\s*import\s+\w+\s+as\s+\w+"#,
            #"(?m)^\s*(if|elif|else|for|while|try|except|with)\b.*:"#,
        ]

        return matchesAnyPattern(patterns, in: text)
    }

    private static func looksLikeCSS(_ text: String) -> Bool {
        let patterns = [
            #"(?m)^[^{\n]+(?=\s*\{)"#,
            #"(?m)^\s*[-a-zA-Z]+\s*:\s*[^;]+;"#,
        ]

        return matchesAnyPattern(patterns, in: text)
    }

    private static func looksLikeSQL(_ trimmed: String) -> Bool {
        let uppercased = trimmed.uppercased()
        let keywords = ["SELECT ", "INSERT ", "UPDATE ", "DELETE ", "CREATE ", "ALTER ", "WITH ", "DROP "]
        return keywords.contains(where: uppercased.hasPrefix)
    }

    private static func looksLikeConfig(_ text: String) -> Bool {
        let patterns = [
            #"(?m)^\s*\[[^\]]+\]\s*$"#,
            #"(?m)^\s*[\w.-]+\s*=\s*.+$"#,
            #"(?m)^\s*[\w.-]+\s*:\s*.+$"#,
            #"(?m)^\s*#\s*[\w\s-]+$"#,
        ]

        return matchesAnyPattern(patterns, in: text)
    }

    private static func looksLikeInfrastructureConfig(_ text: String) -> Bool {
        let patterns = [
            #"(?m)^\s*resource\s+"#,
            #"(?m)^\s*provider\s+"#,
            #"(?m)^\s*server\s*\{"#,
            #"(?m)^\s*location\s+/"#,
            #"(?m)^\s*\[Unit\]\s*$"#,
            #"(?m)^\s*apiVersion:\s"#,
            #"(?m)^\s*kind:\s"#,
        ]

        return matchesAnyPattern(patterns, in: text)
    }

    private static func looksLikeDelimitedTable(_ text: String) -> Bool {
        DelimitedTextTableService.parse(text) != nil
    }

    private static func looksLikeLog(_ text: String) -> Bool {
        let patterns = [
            #"(?m)^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}"#,
            #"(?m)^[A-Z][a-z]{2}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}"#,
            #"(?m)^\[[A-Z]+\]"#,
            #"(?m)\b(INFO|DEBUG|WARN|WARNING|ERROR|FATAL|TRACE)\b"#,
        ]

        return matchesAnyPattern(patterns, in: text)
    }

    private static func matchesAnyPattern(_ patterns: [String], in text: String) -> Bool {
        let range = NSRange(location: 0, length: (text as NSString).length)
        return patterns.contains { pattern in
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                return false
            }

            return regex.firstMatch(in: text, range: range) != nil
        }
    }
}
