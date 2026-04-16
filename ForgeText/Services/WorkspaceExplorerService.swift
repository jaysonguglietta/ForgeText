import Foundation

enum WorkspaceExplorerService {
    private static let ignoredDirectoryNames: Set<String> = [
        ".git",
        ".svn",
        ".hg",
        "node_modules",
        ".build",
        "DerivedData",
    ]

    static func loadTree(
        rootURL: URL?,
        includeHiddenFiles: Bool,
        favoritePaths: Set<String>,
        maxDepth: Int = 5
    ) -> [WorkspaceExplorerNode] {
        loadTree(
            roots: rootURL.map { [$0] } ?? [],
            includeHiddenFiles: includeHiddenFiles,
            favoritePaths: favoritePaths,
            maxDepth: maxDepth
        )
    }

    static func loadTree(
        roots: [URL],
        includeHiddenFiles: Bool,
        favoritePaths: Set<String>,
        maxDepth: Int = 5
    ) -> [WorkspaceExplorerNode] {
        roots
            .map(\.standardizedFileURL)
            .compactMap {
                loadNode(
                    at: $0,
                    includeHiddenFiles: includeHiddenFiles,
                    favoritePaths: favoritePaths,
                    depth: 0,
                    maxDepth: maxDepth
                )
            }
            .sorted(by: nodeSort)
    }

    static func filteredNodes(_ nodes: [WorkspaceExplorerNode], matching query: String) -> [WorkspaceExplorerNode] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmedQuery.isEmpty else {
            return nodes
        }

        return nodes.compactMap { filteredNode($0, query: trimmedQuery) }
    }

    private static func loadNode(
        at url: URL,
        includeHiddenFiles: Bool,
        favoritePaths: Set<String>,
        depth: Int,
        maxDepth: Int
    ) -> WorkspaceExplorerNode? {
        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .isHiddenKey, .nameKey]
        let values = try? url.resourceValues(forKeys: resourceKeys)
        let isDirectory = values?.isDirectory ?? false
        let isHidden = values?.isHidden ?? false

        guard includeHiddenFiles || !isHidden else {
            return nil
        }

        var children: [WorkspaceExplorerNode] = []

        if isDirectory, depth < maxDepth, !ignoredDirectoryNames.contains(url.lastPathComponent) {
            let contents = (try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(resourceKeys),
                options: [.skipsPackageDescendants]
            )) ?? []

            children = contents
                .compactMap {
                    loadNode(
                        at: $0.standardizedFileURL,
                        includeHiddenFiles: includeHiddenFiles,
                        favoritePaths: favoritePaths,
                        depth: depth + 1,
                        maxDepth: maxDepth
                    )
                }
                .sorted(by: nodeSort)
        }

        return WorkspaceExplorerNode(
            id: url.path,
            name: values?.name ?? url.lastPathComponent,
            url: url,
            isDirectory: isDirectory,
            isHidden: isHidden,
            isFavorite: favoritePaths.contains(url.path),
            children: children
        )
    }

    private static func filteredNode(_ node: WorkspaceExplorerNode, query: String) -> WorkspaceExplorerNode? {
        let childMatches = node.children.compactMap { filteredNode($0, query: query) }
        if childMatches.isEmpty == false || node.name.lowercased().contains(query) || node.subtitle.lowercased().contains(query) {
            return WorkspaceExplorerNode(
                id: node.id,
                name: node.name,
                url: node.url,
                isDirectory: node.isDirectory,
                isHidden: node.isHidden,
                isFavorite: node.isFavorite,
                children: childMatches
            )
        }

        return nil
    }

    private static func nodeSort(lhs: WorkspaceExplorerNode, rhs: WorkspaceExplorerNode) -> Bool {
        if lhs.isFavorite != rhs.isFavorite {
            return lhs.isFavorite && !rhs.isFavorite
        }

        if lhs.isDirectory != rhs.isDirectory {
            return lhs.isDirectory && !rhs.isDirectory
        }

        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
    }
}
