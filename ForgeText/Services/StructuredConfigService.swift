import Foundation

enum ConfigFormatKind: String, Codable {
    case yaml
    case toml
    case ini
    case env
    case generic

    var displayName: String {
        switch self {
        case .yaml:
            return "YAML"
        case .toml:
            return "TOML"
        case .ini:
            return "INI"
        case .env:
            return "Environment"
        case .generic:
            return "Config"
        }
    }
}

enum StructuredConfigNodeKind: String, Codable {
    case section
    case keyValue
    case arrayItem
}

struct StructuredConfigNode: Identifiable, Hashable {
    let id: String
    let key: String
    let value: String?
    let lineNumber: Int
    let level: Int
    let kind: StructuredConfigNodeKind
    let children: [StructuredConfigNode]

    var childrenOrNil: [StructuredConfigNode]? {
        children.isEmpty ? nil : children
    }

    var summary: String {
        if let value, !value.isEmpty {
            return value
        }

        switch kind {
        case .section:
            return children.isEmpty ? "Section" : "\(children.count) items"
        case .keyValue:
            return children.isEmpty ? "Value" : "\(children.count) nested items"
        case .arrayItem:
            return children.isEmpty ? "Item" : "\(children.count) nested items"
        }
    }
}

struct StructuredConfigDocument {
    let format: ConfigFormatKind
    let nodes: [StructuredConfigNode]
    let itemCount: Int
    let schema: InfrastructureConfigSchema?
    let diagnostics: [ConfigSchemaDiagnostic]

    var topLevelCount: Int {
        nodes.count
    }
}

enum InfrastructureConfigSchema: String, Codable, Hashable, Identifiable {
    case kubernetes
    case githubActions
    case dockerCompose
    case devContainer

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .kubernetes: return "Kubernetes"
        case .githubActions: return "GitHub Actions"
        case .dockerCompose: return "Docker Compose"
        case .devContainer: return "Dev Container"
        }
    }
}

struct ConfigSchemaDiagnostic: Identifiable, Hashable {
    enum Severity: String, Hashable {
        case warning
        case error
    }

    let id: String
    let severity: Severity
    let message: String
    let lineNumber: Int?
}

enum StructuredConfigService {
    static func parse(_ text: String, url: URL? = nil) -> StructuredConfigDocument? {
        let format = detectFormat(text, url: url)
        let flatNodes: [FlatNode]

        switch format {
        case .env:
            flatNodes = parseEnv(text)
        case .ini:
            flatNodes = parseINI(text)
        case .toml:
            flatNodes = parseTOML(text)
        case .yaml:
            flatNodes = parseYAML(text)
        case .generic:
            flatNodes = parseGeneric(text)
        }

        guard !flatNodes.isEmpty else {
            return nil
        }

        let nodes = buildTree(from: flatNodes)
        let schema = detectSchema(text: text, url: url, nodes: nodes)
        return StructuredConfigDocument(
            format: format,
            nodes: nodes,
            itemCount: flatNodes.count,
            schema: schema,
            diagnostics: validate(schema: schema, nodes: nodes)
        )
    }

    static func filteredNodes(in document: StructuredConfigDocument, matching query: String) -> [StructuredConfigNode] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedQuery.isEmpty else {
            return document.nodes
        }

        return document.nodes.compactMap { filteredNode($0, matching: trimmedQuery) }
    }

    private struct FlatNode {
        let key: String
        let value: String?
        let lineNumber: Int
        let level: Int
        let kind: StructuredConfigNodeKind
    }

    private static func detectFormat(_ text: String, url: URL?) -> ConfigFormatKind {
        let filename = url?.lastPathComponent.lowercased()
        let extensionName = url?.pathExtension.lowercased()

        if filename == ".env" || extensionName == "env" {
            return .env
        }

        if extensionName == "ini" || extensionName == "cfg" || extensionName == "conf" {
            return .ini
        }

        if extensionName == "toml" {
            return .toml
        }

        if extensionName == "yaml" || extensionName == "yml" {
            return .yaml
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.contains("[") && trimmed.contains("]") && trimmed.contains("=") {
            return .toml
        }

        if trimmed.contains(":") && !trimmed.contains("{") {
            return .yaml
        }

        if trimmed.contains("=") {
            return .generic
        }

        return .generic
    }

    private static func detectSchema(
        text: String,
        url: URL?,
        nodes: [StructuredConfigNode]
    ) -> InfrastructureConfigSchema? {
        let path = url?.path.lowercased() ?? ""
        let filename = url?.lastPathComponent.lowercased() ?? ""
        let keys = Set(nodes.map { normalizedSchemaKey($0.key) })
        if path.contains("/.github/workflows/") && ["yml", "yaml"].contains(url?.pathExtension.lowercased() ?? "") {
            return .githubActions
        }
        if filename == "docker-compose.yml" || filename == "docker-compose.yaml" || filename == "compose.yml" || filename == "compose.yaml" {
            return .dockerCompose
        }
        if filename == "devcontainer.json" {
            return .devContainer
        }
        if keys.contains("apiversion") && keys.contains("kind") {
            return .kubernetes
        }
        if keys.contains("jobs") && keys.contains("on") {
            return .githubActions
        }
        if keys.contains("services") && text.localizedCaseInsensitiveContains("image:") {
            return .dockerCompose
        }
        return nil
    }

    private static func validate(
        schema: InfrastructureConfigSchema?,
        nodes: [StructuredConfigNode]
    ) -> [ConfigSchemaDiagnostic] {
        guard let schema else { return [] }
        let byKey = Dictionary(grouping: nodes, by: { normalizedSchemaKey($0.key) })
        let requirements: [(String, String)]
        switch schema {
        case .kubernetes:
            requirements = [
                ("apiversion", "Kubernetes resources require apiVersion."),
                ("kind", "Kubernetes resources require kind."),
                ("metadata", "Kubernetes resources should declare metadata."),
            ]
        case .githubActions:
            requirements = [
                ("on", "GitHub Actions workflows require an on trigger."),
                ("jobs", "GitHub Actions workflows require at least one jobs entry."),
            ]
        case .dockerCompose:
            requirements = [("services", "Docker Compose files require a services mapping.")]
        case .devContainer:
            let hasRuntime = byKey["image"] != nil || byKey["build"] != nil || byKey["dockercomposefile"] != nil
            return hasRuntime ? [] : [
                ConfigSchemaDiagnostic(
                    id: "devcontainer-runtime",
                    severity: .error,
                    message: "Dev Container configuration requires image, build, or dockerComposeFile.",
                    lineNumber: nil
                ),
            ]
        }
        return requirements.compactMap { key, message in
            guard byKey[key] == nil else { return nil }
            return ConfigSchemaDiagnostic(
                id: "\(schema.rawValue)-\(key)",
                severity: key == "metadata" ? .warning : .error,
                message: message,
                lineNumber: nil
            )
        }
    }

    private static func normalizedSchemaKey(_ value: String) -> String {
        value.trimmingCharacters(in: CharacterSet(charactersIn: " \t\"'{}[]," )).lowercased()
    }

    private static func parseEnv(_ text: String) -> [FlatNode] {
        enumeratedLines(in: text).compactMap { lineNumber, line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), let separator = trimmed.firstIndex(of: "=") else {
                return nil
            }

            let key = trimmed[..<separator].trimmingCharacters(in: .whitespaces)
            let value = trimmed[trimmed.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            guard !key.isEmpty else {
                return nil
            }

            return FlatNode(key: key, value: value, lineNumber: lineNumber, level: 0, kind: .keyValue)
        }
    }

    private static func parseINI(_ text: String) -> [FlatNode] {
        var nodes: [FlatNode] = []
        var currentLevel = 0

        for (lineNumber, line) in enumeratedLines(in: text) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), !trimmed.hasPrefix(";") else {
                continue
            }

            if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
                let name = String(trimmed.dropFirst().dropLast())
                nodes.append(FlatNode(key: name, value: nil, lineNumber: lineNumber, level: 0, kind: .section))
                currentLevel = 1
                continue
            }

            guard let separator = trimmed.firstIndex(where: { $0 == "=" || $0 == ":" }) else {
                continue
            }

            let key = trimmed[..<separator].trimmingCharacters(in: .whitespaces)
            let value = trimmed[trimmed.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            nodes.append(FlatNode(key: key, value: value, lineNumber: lineNumber, level: currentLevel, kind: .keyValue))
        }

        return nodes
    }

    private static func parseTOML(_ text: String) -> [FlatNode] {
        var nodes: [FlatNode] = []
        var currentLevel = 0

        for (lineNumber, line) in enumeratedLines(in: text) {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else {
                continue
            }

            if trimmed.hasPrefix("[["), trimmed.hasSuffix("]]") {
                let name = String(trimmed.dropFirst(2).dropLast(2))
                nodes.append(FlatNode(key: name, value: nil, lineNumber: lineNumber, level: 0, kind: .section))
                currentLevel = 1
                continue
            }

            if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
                let name = String(trimmed.dropFirst().dropLast())
                nodes.append(FlatNode(key: name, value: nil, lineNumber: lineNumber, level: 0, kind: .section))
                currentLevel = 1
                continue
            }

            guard let separator = trimmed.firstIndex(of: "=") else {
                continue
            }

            let key = trimmed[..<separator].trimmingCharacters(in: .whitespaces)
            let value = trimmed[trimmed.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            nodes.append(FlatNode(key: key, value: value, lineNumber: lineNumber, level: currentLevel, kind: .keyValue))
        }

        return nodes
    }

    private static func parseYAML(_ text: String) -> [FlatNode] {
        enumeratedLines(in: text).compactMap { lineNumber, line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#") else {
                return nil
            }

            let leadingSpaces = line.prefix { $0 == " " }.count
            let level = max(0, leadingSpaces / 2)

            if trimmed.hasPrefix("- ") {
                let value = String(trimmed.dropFirst(2))
                return FlatNode(key: "Item", value: value, lineNumber: lineNumber, level: level, kind: .arrayItem)
            }

            if let separator = trimmed.firstIndex(of: ":") {
                let key = trimmed[..<separator].trimmingCharacters(in: .whitespaces)
                let value = trimmed[trimmed.index(after: separator)...].trimmingCharacters(in: .whitespaces)
                let kind: StructuredConfigNodeKind = value.isEmpty ? .section : .keyValue
                return FlatNode(key: key, value: value.isEmpty ? nil : value, lineNumber: lineNumber, level: level, kind: kind)
            }

            return FlatNode(key: trimmed, value: nil, lineNumber: lineNumber, level: level, kind: .section)
        }
    }

    private static func parseGeneric(_ text: String) -> [FlatNode] {
        enumeratedLines(in: text).compactMap { lineNumber, line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, !trimmed.hasPrefix("#"), !trimmed.hasPrefix(";") else {
                return nil
            }

            if trimmed.hasPrefix("["), trimmed.hasSuffix("]") {
                return FlatNode(key: String(trimmed.dropFirst().dropLast()), value: nil, lineNumber: lineNumber, level: 0, kind: .section)
            }

            guard let separator = trimmed.firstIndex(where: { $0 == "=" || $0 == ":" }) else {
                return nil
            }

            let key = trimmed[..<separator].trimmingCharacters(in: .whitespaces)
            let value = trimmed[trimmed.index(after: separator)...].trimmingCharacters(in: .whitespaces)
            return FlatNode(key: key, value: value, lineNumber: lineNumber, level: 0, kind: .keyValue)
        }
    }

    private static func buildTree(from flatNodes: [FlatNode]) -> [StructuredConfigNode] {
        var index = 0
        return buildNodes(from: flatNodes, index: &index, level: 0)
    }

    private static func buildNodes(from flatNodes: [FlatNode], index: inout Int, level: Int) -> [StructuredConfigNode] {
        var nodes: [StructuredConfigNode] = []

        while index < flatNodes.count {
            let node = flatNodes[index]

            if node.level < level {
                break
            }

            if node.level > level {
                if var lastNode = nodes.popLast() {
                    let children = buildNodes(from: flatNodes, index: &index, level: node.level)
                    lastNode = StructuredConfigNode(
                        id: lastNode.id,
                        key: lastNode.key,
                        value: lastNode.value,
                        lineNumber: lastNode.lineNumber,
                        level: lastNode.level,
                        kind: lastNode.kind,
                        children: children
                    )
                    nodes.append(lastNode)
                } else {
                    index += 1
                }
                continue
            }

            index += 1
            nodes.append(
                StructuredConfigNode(
                    id: "\(node.lineNumber)-\(node.key)",
                    key: node.key,
                    value: node.value,
                    lineNumber: node.lineNumber,
                    level: node.level,
                    kind: node.kind,
                    children: []
                )
            )
        }

        return nodes
    }

    private static func filteredNode(_ node: StructuredConfigNode, matching query: String) -> StructuredConfigNode? {
        let matchesSelf = [node.key, node.value, node.summary]
            .compactMap { $0?.lowercased() }
            .contains { $0.contains(query) }
        let filteredChildren = node.children.compactMap { filteredNode($0, matching: query) }

        guard matchesSelf || !filteredChildren.isEmpty else {
            return nil
        }

        return StructuredConfigNode(
            id: node.id,
            key: node.key,
            value: node.value,
            lineNumber: node.lineNumber,
            level: node.level,
            kind: node.kind,
            children: matchesSelf ? node.children : filteredChildren
        )
    }

    private static func enumeratedLines(in text: String) -> [(Int, String)] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
            .enumerated()
            .map { ($0.offset + 1, $0.element) }
    }
}
