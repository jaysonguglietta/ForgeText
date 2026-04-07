import Foundation

enum JSONValueKind: String, Codable {
    case object
    case array
    case string
    case number
    case boolean
    case null

    var displayName: String {
        switch self {
        case .object:
            return "Object"
        case .array:
            return "Array"
        case .string:
            return "String"
        case .number:
            return "Number"
        case .boolean:
            return "Boolean"
        case .null:
            return "Null"
        }
    }

    var symbolName: String {
        switch self {
        case .object:
            return "curlybraces"
        case .array:
            return "list.number"
        case .string:
            return "quote.bubble"
        case .number:
            return "number"
        case .boolean:
            return "checkmark.circle"
        case .null:
            return "circle.slash"
        }
    }
}

struct JSONTreeNode: Identifiable, Hashable {
    let id: String
    let key: String?
    let kind: JSONValueKind
    let summary: String
    let rawValue: String?
    let children: [JSONTreeNode]

    var childrenOrNil: [JSONTreeNode]? {
        children.isEmpty ? nil : children
    }

    var primaryLabel: String {
        key ?? "Root"
    }
}

struct JSONTreeDocument {
    let rootNode: JSONTreeNode
    let nodeCount: Int
    let maxDepth: Int

    var topLevelType: JSONValueKind {
        rootNode.kind
    }

    var displayNodes: [JSONTreeNode] {
        if rootNode.kind == .object || rootNode.kind == .array {
            return rootNode.children
        }

        return [rootNode]
    }

    var topLevelCount: Int {
        rootNode.children.count
    }
}

enum JSONTreeService {
    static func parse(_ text: String) -> JSONTreeDocument? {
        guard let data = text.data(using: .utf8) else {
            return nil
        }

        guard let jsonObject = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed]) else {
            return nil
        }

        let rootNode = makeNode(from: jsonObject, key: nil, path: "$")
        return JSONTreeDocument(
            rootNode: rootNode,
            nodeCount: nodeCount(in: rootNode),
            maxDepth: maxDepth(in: rootNode)
        )
    }

    static func filteredNodes(in document: JSONTreeDocument, matching query: String) -> [JSONTreeNode] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return document.displayNodes
        }

        let loweredQuery = trimmedQuery.lowercased()
        return document.displayNodes.compactMap { filteredNode($0, matching: loweredQuery) }
    }

    private static func filteredNode(_ node: JSONTreeNode, matching query: String) -> JSONTreeNode? {
        let matchesSelf = [node.key, node.summary, node.rawValue, node.kind.displayName]
            .compactMap { $0?.lowercased() }
            .contains { $0.contains(query) }
        let filteredChildren = node.children.compactMap { filteredNode($0, matching: query) }

        guard matchesSelf || !filteredChildren.isEmpty else {
            return nil
        }

        return JSONTreeNode(
            id: node.id,
            key: node.key,
            kind: node.kind,
            summary: node.summary,
            rawValue: node.rawValue,
            children: matchesSelf ? node.children : filteredChildren
        )
    }

    private static func makeNode(from value: Any, key: String?, path: String) -> JSONTreeNode {
        if let dictionary = value as? [String: Any] {
            let sortedKeys = dictionary.keys.sorted { lhs, rhs in
                lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }
            let children = sortedKeys.map { childKey in
                makeNode(from: dictionary[childKey] as Any, key: childKey, path: "\(path).\(childKey)")
            }

            return JSONTreeNode(
                id: path,
                key: key,
                kind: .object,
                summary: "\(children.count) fields",
                rawValue: nil,
                children: children
            )
        }

        if let array = value as? [Any] {
            let children = array.enumerated().map { index, childValue in
                makeNode(from: childValue, key: "[\(index)]", path: "\(path)[\(index)]")
            }

            return JSONTreeNode(
                id: path,
                key: key,
                kind: .array,
                summary: "\(children.count) items",
                rawValue: nil,
                children: children
            )
        }

        if let string = value as? String {
            return JSONTreeNode(
                id: path,
                key: key,
                kind: .string,
                summary: truncated(string),
                rawValue: string,
                children: []
            )
        }

        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                let booleanValue = number.boolValue ? "true" : "false"
                return JSONTreeNode(
                    id: path,
                    key: key,
                    kind: .boolean,
                    summary: booleanValue,
                    rawValue: booleanValue,
                    children: []
                )
            }

            let numericValue = number.stringValue
            return JSONTreeNode(
                id: path,
                key: key,
                kind: .number,
                summary: numericValue,
                rawValue: numericValue,
                children: []
            )
        }

        return JSONTreeNode(
            id: path,
            key: key,
            kind: .null,
            summary: "null",
            rawValue: "null",
            children: []
        )
    }

    private static func truncated(_ value: String) -> String {
        let singleLine = value
            .replacingOccurrences(of: "\r\n", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
        let limit = 90
        if singleLine.count <= limit {
            return singleLine
        }

        return String(singleLine.prefix(limit - 3)) + "..."
    }

    private static func nodeCount(in node: JSONTreeNode) -> Int {
        1 + node.children.reduce(0) { partialResult, child in
            partialResult + nodeCount(in: child)
        }
    }

    private static func maxDepth(in node: JSONTreeNode) -> Int {
        let childDepth = node.children.map(maxDepth).max() ?? 0
        return 1 + childDepth
    }
}
