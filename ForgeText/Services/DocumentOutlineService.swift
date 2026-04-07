import Foundation

struct OutlineItem: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String?
    let lineNumber: Int
    let level: Int
    let path: [String]
}

enum DocumentOutlineService {
    static func outline(for document: EditorDocument) -> [OutlineItem] {
        outline(
            text: document.text,
            language: document.language,
            url: document.fileURL ?? document.remoteReference.map { URL(fileURLWithPath: $0.path) }
        )
    }

    static func outline(text: String, language: DocumentLanguage, url: URL? = nil) -> [OutlineItem] {
        switch language {
        case .markdown:
            return markdownOutline(text)
        case .json:
            return regexOutline(text, pattern: #"(?m)^(\s*)"([^"]+)"\s*:"#)
        case .config:
            return configOutline(text, url: url)
        case .swift:
            return regexOutline(text, pattern: #"(?m)^(\s*)(?:struct|class|enum|protocol|extension|func)\s+([A-Za-z_][A-Za-z0-9_]*)"#)
        case .javascript:
            return regexOutline(text, pattern: #"(?m)^(\s*)(?:function|class|const|let|var)\s+([A-Za-z_][A-Za-z0-9_]*)"#)
        case .python:
            return regexOutline(text, pattern: #"(?m)^(\s*)(?:class|def)\s+([A-Za-z_][A-Za-z0-9_]*)"#)
        case .xml:
            return regexOutline(text, pattern: #"(?m)^(\s*)<([A-Za-z][A-Za-z0-9:_-]*)\b"#)
        case .csv, .plainText, .shell, .css, .sql, .log:
            return []
        }
    }

    static func breadcrumbTrail(for document: EditorDocument, cursorLine: Int) -> [String] {
        var trail: [String] = []

        if let url = document.fileURL {
            let components = url.pathComponents.suffix(3).filter { $0 != "/" }
            trail.append(contentsOf: components)
        } else if let remoteReference = document.remoteReference {
            trail.append(remoteReference.connection)
            trail.append(contentsOf: remoteReference.path.split(separator: "/").suffix(2).map(String.init))
        } else {
            trail.append(document.displayName)
        }

        let outlineItems = outline(for: document)
        if let nearest = outlineItems.last(where: { $0.lineNumber <= cursorLine }) {
            trail.append(contentsOf: nearest.path)
        }

        return trail
    }

    private static func markdownOutline(_ text: String) -> [OutlineItem] {
        guard let regex = try? NSRegularExpression(pattern: #"(?m)^(#{1,6})\s+(.+)$"#) else {
            return []
        }

        return buildHierarchicalOutline(
            text: text,
            regex: regex,
            titleRangeIndex: 2
        ) { text, match in
            let marker = (text as NSString).substring(with: match.range(at: 1))
            return max(0, marker.count - 1)
        }
    }

    private static func configOutline(_ text: String, url: URL?) -> [OutlineItem] {
        guard let document = StructuredConfigService.parse(text, url: url) else {
            return []
        }

        return flattenConfigNodes(document.nodes, path: [])
    }

    private static func flattenConfigNodes(_ nodes: [StructuredConfigNode], path: [String]) -> [OutlineItem] {
        nodes.flatMap { node in
            let nextPath = path + [node.key]
            let item = OutlineItem(
                id: node.id,
                title: node.key,
                detail: node.value,
                lineNumber: node.lineNumber,
                level: node.level,
                path: nextPath
            )
            return [item] + flattenConfigNodes(node.children, path: nextPath)
        }
    }

    private static func regexOutline(_ text: String, pattern: String) -> [OutlineItem] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        return buildHierarchicalOutline(
            text: text,
            regex: regex,
            titleRangeIndex: 2
        ) { text, match in
            let whitespace = (text as NSString).substring(with: match.range(at: 1))
            return max(0, whitespace.count / 2)
        }
    }

    private static func buildHierarchicalOutline(
        text: String,
        regex: NSRegularExpression,
        titleRangeIndex: Int,
        levelProvider: (String, NSTextCheckingResult) -> Int
    ) -> [OutlineItem] {
        let nsText = text as NSString
        let fullRange = NSRange(location: 0, length: nsText.length)
        var outline: [OutlineItem] = []
        var pathStack: [String] = []

        for match in regex.matches(in: text, range: fullRange) {
            let title = nsText.substring(with: match.range(at: titleRangeIndex))
            let level = levelProvider(text, match)
            let prefix = nsText.substring(to: match.range.location)
            let lineNumber = prefix.reduce(into: 1) { partialResult, character in
                if character == "\n" {
                    partialResult += 1
                }
            }

            if pathStack.count > level {
                pathStack = Array(pathStack.prefix(level))
            }

            if pathStack.count == level {
                pathStack.append(title)
            } else {
                while pathStack.count < level {
                    pathStack.append("Section")
                }
                pathStack.append(title)
            }

            outline.append(
                OutlineItem(
                    id: "\(lineNumber)-\(title)",
                    title: title,
                    detail: nil,
                    lineNumber: lineNumber,
                    level: level,
                    path: pathStack
                )
            )
        }

        return outline
    }
}
