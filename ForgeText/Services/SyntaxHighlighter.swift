import AppKit
import Foundation

@MainActor
enum SyntaxHighlighter {
    private static let regexCache = NSCache<NSString, NSRegularExpression>()
    private static let reducedHighlightingCharacterThreshold = 120_000

    private enum HighlightingMode {
        case plain
        case reduced
        case full

        var label: String {
            switch self {
            case .plain:
                return "plain"
            case .reduced:
                return "reduced"
            case .full:
                return "full"
            }
        }
    }

    static func apply(
        to textView: NSTextView,
        theme: EditorTheme,
        language: DocumentLanguage,
        fontSize: CGFloat,
        findState: FindState,
        largeFileMode: Bool,
        lineDecorations: [EditorLineDecoration] = []
    ) {
        guard let textStorage = textView.textStorage else {
            return
        }

        let palette = StylePalette(theme: theme, fontSize: fontSize)
        let text = textStorage.string
        let textLength = (text as NSString).length
        let preservedSelection = clamped(textView.selectedRange(), upperBound: textLength)
        let highlightingMode = highlightingMode(for: text, largeFileMode: largeFileMode)
        let startedAt = DispatchTime.now().uptimeNanoseconds

        textStorage.beginEditing()
        textStorage.setAttributes(palette.base, range: NSRange(location: 0, length: textLength))

        switch highlightingMode {
        case .plain:
            break
        case .reduced:
            applyReducedLanguageHighlighting(to: textStorage, text: text, language: language, palette: palette)
        case .full:
            applyLanguageHighlighting(to: textStorage, text: text, language: language, palette: palette)

            for range in EditorBehavior.matchedBracketRanges(
                in: text,
                selectedRange: preservedSelection,
                language: language
            ) {
                textStorage.addAttributes(palette.bracketMatch, range: range)
            }
        }

        for range in findState.matchRanges {
            textStorage.addAttributes(palette.searchMatch, range: range)
        }

        if let currentMatchRange = findState.currentMatchRange {
            textStorage.addAttributes(palette.currentSearchMatch, range: currentMatchRange)
        }

        applyLineDecorations(to: textStorage, text: text, palette: palette, decorations: lineDecorations)

        textStorage.endEditing()
        let elapsedMS = Double(DispatchTime.now().uptimeNanoseconds - startedAt) / 1_000_000

        textView.font = palette.base[.font] as? NSFont
        textView.typingAttributes = palette.base
        textView.backgroundColor = theme.backgroundColor
        textView.textColor = theme.textColor
        textView.insertionPointColor = theme.accentColor
        textView.selectedTextAttributes = [
            .backgroundColor: theme.selectionColor,
            .foregroundColor: theme.textColor,
        ]

        if textView.selectedRange() != preservedSelection {
            textView.setSelectedRange(preservedSelection)
        }

        EditorPerformanceMonitor.shared.record(
            .syntaxHighlighting,
            durationMS: elapsedMS,
            detail: "\(language.displayName) · \(highlightingMode.label)",
            payload: "\(textLength) chars"
        )
    }

    private static func clamped(_ range: NSRange, upperBound: Int) -> NSRange {
        let location = min(max(range.location, 0), upperBound)
        let length = min(max(range.length, 0), upperBound - location)
        return NSRange(location: location, length: length)
    }

    private static func applyLanguageHighlighting(
        to textStorage: NSTextStorage,
        text: String,
        language: DocumentLanguage,
        palette: StylePalette
    ) {
        applyPattern(#"https?://[^\s<>()]+"#, attributes: palette.link, to: textStorage, text: text)

        switch language {
        case .plainText:
            applyPattern(#"\b(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?)\b"#, attributes: palette.number, to: textStorage, text: text)
        case .csv:
            applyPattern(#""(?:[^"\\]|\\.)*""#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"\b(?:-?(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?(?:[eE][+-]?\d+)?))\b"#, attributes: palette.number, to: textStorage, text: text)
        case .markdown:
            applyPattern(#"(?m)^#{1,6}\s+.*$"#, attributes: palette.heading, to: textStorage, text: text)
            applyPattern(#"(?ms)^```.*?^```[ \t]*$"#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"`[^`\n]+`"#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"\[[^\]]+\]\([^)]+\)"#, attributes: palette.link, to: textStorage, text: text)
            applyPattern(#"(?m)^>\s+.*$"#, attributes: palette.comment, to: textStorage, text: text)
        case .json:
            applyPattern(#""(?:[^"\\]|\\.)*""#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#""(?:[^"\\]|\\.)*"\s*:"# , attributes: palette.property, to: textStorage, text: text)
            applyKeywords(["true", "false", "null"], attributes: palette.keyword, to: textStorage, text: text)
            applyPattern(#"\b(?:-?(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?(?:[eE][+-]?\d+)?))\b"#, attributes: palette.number, to: textStorage, text: text)
        case .http:
            applyPattern(#"(?m)^(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\b"#, attributes: palette.keyword, to: textStorage, text: text)
            applyPattern(#"https?://[^\s<>()]+"#, attributes: palette.link, to: textStorage, text: text)
            applyPattern(#"(?m)^[A-Za-z-]+(?=:)"#, attributes: palette.property, to: textStorage, text: text)
            applyPattern(#"(?m)^###.*$"#, attributes: palette.heading, to: textStorage, text: text)
        case .xml:
            applyPattern(#"<!--[\s\S]*?-->"#, attributes: palette.comment, to: textStorage, text: text)
            applyPattern(#"</?[A-Za-z][A-Za-z0-9:_-]*"#, attributes: palette.keyword, to: textStorage, text: text)
            applyPattern(#"\b[A-Za-z_:][-A-Za-z0-9_:.]*(?=\=)"#, attributes: palette.property, to: textStorage, text: text)
            applyPattern(#""(?:[^"\\]|\\.)*""#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"</?>"#, attributes: palette.keyword, to: textStorage, text: text)
        case .swift:
            applyKeywords(swiftKeywords, attributes: palette.keyword, to: textStorage, text: text)
            applyPattern(#"@\w+"#, attributes: palette.decorator, to: textStorage, text: text)
            applyPattern(#"//.*"#, attributes: palette.comment, to: textStorage, text: text)
            applyPattern(#"/\*[\s\S]*?\*/"#, attributes: palette.comment, to: textStorage, text: text)
            applyPattern(#""(?:[^"\\]|\\.)*""#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"\b(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?)\b"#, attributes: palette.number, to: textStorage, text: text)
        case .shell:
            applyKeywords(shellKeywords, attributes: palette.keyword, to: textStorage, text: text)
            applyPattern(#"#.*"#, attributes: palette.comment, to: textStorage, text: text)
            applyPattern(#"\$[A-Za-z_][A-Za-z0-9_]*|\$\{[^}]+\}"#, attributes: palette.decorator, to: textStorage, text: text)
            applyPattern(#""(?:[^"\\]|\\.)*""#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"'[^'\n]*'"#, attributes: palette.string, to: textStorage, text: text)
        case .javascript:
            applyKeywords(javaScriptKeywords, attributes: palette.keyword, to: textStorage, text: text, options: [.caseInsensitive])
            applyPattern(#"//.*"#, attributes: palette.comment, to: textStorage, text: text)
            applyPattern(#"/\*[\s\S]*?\*/"#, attributes: palette.comment, to: textStorage, text: text)
            applyPattern(#""(?:[^"\\]|\\.)*""#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"'(?:[^'\\]|\\.)*'"#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"`(?:[^`\\]|\\.)*`"#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"\b(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?)\b"#, attributes: palette.number, to: textStorage, text: text)
        case .python:
            applyKeywords(pythonKeywords, attributes: palette.keyword, to: textStorage, text: text)
            applyPattern(#"#.*"#, attributes: palette.comment, to: textStorage, text: text)
            applyPattern(#"@\w+"#, attributes: palette.decorator, to: textStorage, text: text)
            applyPattern(#""(?:[^"\\]|\\.)*""#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"'(?:[^'\\]|\\.)*'"#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"\b(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?)\b"#, attributes: palette.number, to: textStorage, text: text)
        case .css:
            applyPattern(#"/\*[\s\S]*?\*/"#, attributes: palette.comment, to: textStorage, text: text)
            applyPattern(#"(?m)^[^{\n]+(?=\s*\{)"#, attributes: palette.keyword, to: textStorage, text: text)
            applyPattern(#"(?m)\b[-A-Za-z]+\b(?=\s*:)"#, attributes: palette.property, to: textStorage, text: text)
            applyPattern(#"#[0-9A-Fa-f]{3,8}\b"#, attributes: palette.number, to: textStorage, text: text)
            applyPattern(#""(?:[^"\\]|\\.)*""#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"'(?:[^'\\]|\\.)*'"#, attributes: palette.string, to: textStorage, text: text)
        case .sql:
            applyKeywords(sqlKeywords, attributes: palette.keyword, to: textStorage, text: text, options: [.caseInsensitive])
            applyPattern(#"--.*"#, attributes: palette.comment, to: textStorage, text: text)
            applyPattern(#"/\*[\s\S]*?\*/"#, attributes: palette.comment, to: textStorage, text: text)
            applyPattern(#"'(?:[^'\\]|\\.)*'"#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"\b(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?)\b"#, attributes: palette.number, to: textStorage, text: text)
        case .config:
            applyPattern(#"(?m)^\s*[#;].*$"#, attributes: palette.comment, to: textStorage, text: text)
            applyPattern(#"(?m)^\s*\[[^\]]+\]\s*$"#, attributes: palette.keyword, to: textStorage, text: text)
            applyPattern(#"(?m)^\s*[-A-Za-z0-9_.]+\s*(?==|:)"#, attributes: palette.property, to: textStorage, text: text)
            applyPattern(#""(?:[^"\\]|\\.)*""#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"'(?:[^'\\]|\\.)*'"#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"\b(?:true|false|yes|no|on|off|null)\b"#, options: [.caseInsensitive], attributes: palette.keyword, to: textStorage, text: text)
        case .log:
            applyPattern(#"(?m)^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:[.,]\d+)?(?:Z|[+-]\d{2}:?\d{2})?"#, attributes: palette.link, to: textStorage, text: text)
            applyPattern(#"\b(?:TRACE|DEBUG|INFO|NOTICE|WARN|WARNING|ERROR|FATAL|CRITICAL)\b"#, attributes: palette.warning, to: textStorage, text: text)
            applyPattern(#"\b(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?)\b"#, attributes: palette.number, to: textStorage, text: text)
        }
    }

    private static func applyReducedLanguageHighlighting(
        to textStorage: NSTextStorage,
        text: String,
        language: DocumentLanguage,
        palette: StylePalette
    ) {
        applyPattern(#"https?://[^\s<>()]+"#, attributes: palette.link, to: textStorage, text: text)

        switch language {
        case .plainText:
            applyPattern(#"\b(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?)\b"#, attributes: palette.number, to: textStorage, text: text)
        case .csv:
            applyPattern(#""(?:[^"\\]|\\.)*""#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"\b(?:-?(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?(?:[eE][+-]?\d+)?))\b"#, attributes: palette.number, to: textStorage, text: text)
        case .markdown:
            applyPattern(#"(?m)^#{1,6}\s+.*$"#, attributes: palette.heading, to: textStorage, text: text)
            applyPattern(#"`[^`\n]+`"#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"\[[^\]]+\]\([^)]+\)"#, attributes: palette.link, to: textStorage, text: text)
            applyPattern(#"(?m)^>\s+.*$"#, attributes: palette.comment, to: textStorage, text: text)
        case .json:
            applyPattern(#""(?:[^"\\]|\\.)*""#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#""(?:[^"\\]|\\.)*"\s*:"# , attributes: palette.property, to: textStorage, text: text)
            applyKeywords(["true", "false", "null"], attributes: palette.keyword, to: textStorage, text: text)
            applyPattern(#"\b(?:-?(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?(?:[eE][+-]?\d+)?))\b"#, attributes: palette.number, to: textStorage, text: text)
        case .http:
            applyPattern(#"(?m)^(GET|POST|PUT|PATCH|DELETE|HEAD|OPTIONS)\b"#, attributes: palette.keyword, to: textStorage, text: text)
            applyPattern(#"(?m)^[A-Za-z-]+(?=:)"#, attributes: palette.property, to: textStorage, text: text)
            applyPattern(#"(?m)^###.*$"#, attributes: palette.heading, to: textStorage, text: text)
        case .xml:
            applyPattern(#"</?[A-Za-z][A-Za-z0-9:_-]*"#, attributes: palette.keyword, to: textStorage, text: text)
            applyPattern(#"\b[A-Za-z_:][-A-Za-z0-9_:.]*(?=\=)"#, attributes: palette.property, to: textStorage, text: text)
            applyPattern(#""(?:[^"\\]|\\.)*""#, attributes: palette.string, to: textStorage, text: text)
        case .swift:
            applyKeywords(swiftKeywords, attributes: palette.keyword, to: textStorage, text: text)
            applyPattern(#"@\w+"#, attributes: palette.decorator, to: textStorage, text: text)
            applyPattern(#"//.*"#, attributes: palette.comment, to: textStorage, text: text)
            applyPattern(#""(?:[^"\\]|\\.)*""#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"\b(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?)\b"#, attributes: palette.number, to: textStorage, text: text)
        case .shell:
            applyKeywords(shellKeywords, attributes: palette.keyword, to: textStorage, text: text)
            applyPattern(#"#.*"#, attributes: palette.comment, to: textStorage, text: text)
            applyPattern(#"\$[A-Za-z_][A-Za-z0-9_]*|\$\{[^}]+\}"#, attributes: palette.decorator, to: textStorage, text: text)
            applyPattern(#""(?:[^"\\]|\\.)*""#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"'[^'\n]*'"#, attributes: palette.string, to: textStorage, text: text)
        case .javascript:
            applyKeywords(javaScriptKeywords, attributes: palette.keyword, to: textStorage, text: text, options: [.caseInsensitive])
            applyPattern(#"//.*"#, attributes: palette.comment, to: textStorage, text: text)
            applyPattern(#""(?:[^"\\]|\\.)*""#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"'(?:[^'\\]|\\.)*'"#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"`(?:[^`\\]|\\.)*`"#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"\b(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?)\b"#, attributes: palette.number, to: textStorage, text: text)
        case .python:
            applyKeywords(pythonKeywords, attributes: palette.keyword, to: textStorage, text: text)
            applyPattern(#"#.*"#, attributes: palette.comment, to: textStorage, text: text)
            applyPattern(#"@\w+"#, attributes: palette.decorator, to: textStorage, text: text)
            applyPattern(#""(?:[^"\\]|\\.)*""#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"'(?:[^'\\]|\\.)*'"#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"\b(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?)\b"#, attributes: palette.number, to: textStorage, text: text)
        case .css:
            applyPattern(#"(?m)^[^{\n]+(?=\s*\{)"#, attributes: palette.keyword, to: textStorage, text: text)
            applyPattern(#"(?m)\b[-A-Za-z]+\b(?=\s*:)"#, attributes: palette.property, to: textStorage, text: text)
            applyPattern(#"#[0-9A-Fa-f]{3,8}\b"#, attributes: palette.number, to: textStorage, text: text)
            applyPattern(#""(?:[^"\\]|\\.)*""#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"'(?:[^'\\]|\\.)*'"#, attributes: palette.string, to: textStorage, text: text)
        case .sql:
            applyKeywords(sqlKeywords, attributes: palette.keyword, to: textStorage, text: text, options: [.caseInsensitive])
            applyPattern(#"--.*"#, attributes: palette.comment, to: textStorage, text: text)
            applyPattern(#"'(?:[^'\\]|\\.)*'"#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"\b(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?)\b"#, attributes: palette.number, to: textStorage, text: text)
        case .config:
            applyPattern(#"(?m)^\s*[#;].*$"#, attributes: palette.comment, to: textStorage, text: text)
            applyPattern(#"(?m)^\s*\[[^\]]+\]\s*$"#, attributes: palette.keyword, to: textStorage, text: text)
            applyPattern(#"(?m)^\s*[-A-Za-z0-9_.]+\s*(?==|:)"#, attributes: palette.property, to: textStorage, text: text)
            applyPattern(#""(?:[^"\\]|\\.)*""#, attributes: palette.string, to: textStorage, text: text)
            applyPattern(#"'(?:[^'\\]|\\.)*'"#, attributes: palette.string, to: textStorage, text: text)
        case .log:
            applyPattern(#"(?m)^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:[.,]\d+)?(?:Z|[+-]\d{2}:?\d{2})?"#, attributes: palette.link, to: textStorage, text: text)
            applyPattern(#"\b(?:TRACE|DEBUG|INFO|NOTICE|WARN|WARNING|ERROR|FATAL|CRITICAL)\b"#, attributes: palette.warning, to: textStorage, text: text)
            applyPattern(#"\b(?:0x[0-9A-Fa-f]+|\d+(?:\.\d+)?)\b"#, attributes: palette.number, to: textStorage, text: text)
        }
    }

    private static func highlightingMode(for text: String, largeFileMode: Bool) -> HighlightingMode {
        if largeFileMode {
            return .plain
        }

        if text.utf16.count > reducedHighlightingCharacterThreshold {
            return .reduced
        }

        return .full
    }

    private static func applyKeywords(
        _ keywords: [String],
        attributes: [NSAttributedString.Key: Any],
        to textStorage: NSTextStorage,
        text: String,
        options: NSRegularExpression.Options = []
    ) {
        let escapedKeywords = keywords.map(NSRegularExpression.escapedPattern(for:))
        let pattern = #"\b(?:\#(escapedKeywords.joined(separator: "|")))\b"#
        applyPattern(pattern, options: options, attributes: attributes, to: textStorage, text: text)
    }

    private static func applyPattern(
        _ pattern: String,
        options: NSRegularExpression.Options = [],
        attributes: [NSAttributedString.Key: Any],
        to textStorage: NSTextStorage,
        text: String
    ) {
        let cacheKey = "\(options.rawValue)::\(pattern)" as NSString
        let regex: NSRegularExpression
        if let cachedRegex = regexCache.object(forKey: cacheKey) {
            regex = cachedRegex
        } else if let compiledRegex = try? NSRegularExpression(pattern: pattern, options: options) {
            regex = compiledRegex
            regexCache.setObject(compiledRegex, forKey: cacheKey)
        } else {
            return
        }

        let range = NSRange(location: 0, length: (text as NSString).length)
        for match in regex.matches(in: text, range: range) {
            textStorage.addAttributes(attributes, range: match.range)
        }
    }

    private static func applyLineDecorations(
        to textStorage: NSTextStorage,
        text: String,
        palette: StylePalette,
        decorations: [EditorLineDecoration]
    ) {
        guard !decorations.isEmpty else {
            return
        }

        let nsText = text as NSString
        for decoration in decorations {
            let lineRange = lineRange(for: decoration.lineNumber, in: nsText)
            guard lineRange.location != NSNotFound else {
                continue
            }

            textStorage.addAttributes(palette.lineDecorationAttributes(for: decoration.kind), range: lineRange)
        }
    }

    private static func lineRange(for lineNumber: Int, in text: NSString) -> NSRange {
        guard lineNumber > 0 else {
            return NSRange(location: NSNotFound, length: 0)
        }

        var currentLine = 1
        var index = 0

        while index < text.length {
            let range = text.lineRange(for: NSRange(location: index, length: 0))
            if currentLine == lineNumber {
                return range
            }

            currentLine += 1
            index = NSMaxRange(range)
        }

        return currentLine == lineNumber ? NSRange(location: text.length, length: 0) : NSRange(location: NSNotFound, length: 0)
    }

    private struct StylePalette {
        let base: [NSAttributedString.Key: Any]
        let heading: [NSAttributedString.Key: Any]
        let keyword: [NSAttributedString.Key: Any]
        let string: [NSAttributedString.Key: Any]
        let comment: [NSAttributedString.Key: Any]
        let number: [NSAttributedString.Key: Any]
        let property: [NSAttributedString.Key: Any]
        let link: [NSAttributedString.Key: Any]
        let warning: [NSAttributedString.Key: Any]
        let decorator: [NSAttributedString.Key: Any]
        let bracketMatch: [NSAttributedString.Key: Any]
        let searchMatch: [NSAttributedString.Key: Any]
        let currentSearchMatch: [NSAttributedString.Key: Any]
        let gitAddedBackground: NSColor
        let gitChangedBackground: NSColor
        let diagnosticInfoBackground: NSColor
        let diagnosticWarningBackground: NSColor
        let diagnosticErrorBackground: NSColor

        init(theme: EditorTheme, fontSize: CGFloat) {
            let baseFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular)
            let headingFont = NSFont.monospacedSystemFont(ofSize: fontSize, weight: .semibold)

            base = [
                .font: baseFont,
                .foregroundColor: theme.textColor,
            ]
            heading = [
                .font: headingFont,
                .foregroundColor: theme.keywordColor,
            ]
            keyword = [.foregroundColor: theme.keywordColor]
            string = [.foregroundColor: theme.stringColor]
            comment = [.foregroundColor: theme.commentColor]
            number = [.foregroundColor: theme.numberColor]
            property = [.foregroundColor: theme.linkColor]
            link = [
                .foregroundColor: theme.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue,
            ]
            warning = [.foregroundColor: theme.warningColor]
            decorator = [.foregroundColor: theme.accentColor]
            bracketMatch = [
                .backgroundColor: theme.accentColor.withAlphaComponent(0.16),
                .underlineStyle: NSUnderlineStyle.single.rawValue,
                .underlineColor: theme.accentColor,
            ]
            searchMatch = [
                .backgroundColor: theme.searchHighlightColor,
            ]
            currentSearchMatch = [
                .backgroundColor: theme.currentSearchHighlightColor,
            ]
            gitAddedBackground = NSColor.systemGreen.withAlphaComponent(theme == .vellum ? 0.12 : 0.14)
            gitChangedBackground = theme.accentColor.withAlphaComponent(theme == .vellum ? 0.1 : 0.12)
            diagnosticInfoBackground = theme.linkColor.withAlphaComponent(theme == .vellum ? 0.10 : 0.12)
            diagnosticWarningBackground = theme.warningColor.withAlphaComponent(theme == .vellum ? 0.12 : 0.15)
            diagnosticErrorBackground = NSColor.systemRed.withAlphaComponent(theme == .vellum ? 0.10 : 0.14)
        }

        func lineDecorationAttributes(for kind: EditorLineDecorationKind) -> [NSAttributedString.Key: Any] {
            let backgroundColor: NSColor
            switch kind {
            case .gitChanged:
                backgroundColor = gitChangedBackground
            case .gitAdded:
                backgroundColor = gitAddedBackground
            case .diagnosticInfo:
                backgroundColor = diagnosticInfoBackground
            case .diagnosticWarning:
                backgroundColor = diagnosticWarningBackground
            case .diagnosticError:
                backgroundColor = diagnosticErrorBackground
            }

            return [.backgroundColor: backgroundColor]
        }
    }

    private static let swiftKeywords = [
        "actor", "associatedtype", "async", "await", "break", "case", "catch", "class", "continue", "default",
        "defer", "do", "else", "enum", "extension", "fallthrough", "false", "for", "func", "guard", "if", "import",
        "in", "init", "let", "nil", "private", "protocol", "public", "return", "self", "static", "struct", "switch",
        "throw", "throws", "true", "try", "typealias", "var", "where", "while",
    ]

    private static let shellKeywords = [
        "case", "do", "done", "elif", "else", "esac", "export", "fi", "for", "function", "if", "in", "local",
        "select", "then", "until", "while",
    ]

    private static let javaScriptKeywords = [
        "async", "await", "break", "case", "catch", "class", "const", "continue", "default", "delete", "else",
        "export", "extends", "false", "finally", "for", "function", "if", "import", "in", "instanceof", "let",
        "new", "null", "return", "super", "switch", "this", "throw", "true", "try", "typeof", "undefined", "var",
        "while",
    ]

    private static let pythonKeywords = [
        "and", "as", "break", "class", "continue", "def", "elif", "else", "except", "False", "finally", "for",
        "from", "if", "import", "in", "is", "lambda", "None", "not", "or", "pass", "raise", "return", "True",
        "try", "while", "with", "yield",
    ]

    private static let sqlKeywords = [
        "alter", "and", "as", "by", "case", "create", "delete", "drop", "else", "from", "group", "having", "in",
        "insert", "into", "join", "left", "limit", "not", "null", "on", "or", "order", "right", "select", "set",
        "table", "then", "union", "update", "values", "when", "where", "with",
    ]
}
