import Foundation

enum WorkspaceSearchService {
    static func search(
        root: URL,
        query: String,
        options: SearchOptions,
        includeHiddenFiles: Bool,
        maxResults: Int = 250
    ) -> ProjectSearchSummary {
        let startedAt = Date()
        let manager = FileManager.default
        let resourceKeys: Set<URLResourceKey> = [.isDirectoryKey, .isHiddenKey, .fileSizeKey]
        let directorySkips = Set([".git", ".svn", ".hg", "node_modules", "DerivedData", ".build"])

        guard let enumerator = manager.enumerator(
            at: root,
            includingPropertiesForKeys: Array(resourceKeys),
            options: [.skipsPackageDescendants]
        ) else {
            return ProjectSearchSummary(hits: [], scannedFileCount: 0, skippedFileCount: 0, elapsedTime: 0)
        }

        var hits: [ProjectSearchHit] = []
        var scannedFileCount = 0
        var skippedFileCount = 0

        for case let fileURL as URL in enumerator {
            guard let values = try? fileURL.resourceValues(forKeys: resourceKeys) else {
                skippedFileCount += 1
                continue
            }

            if values.isDirectory == true {
                if directorySkips.contains(fileURL.lastPathComponent) {
                    enumerator.skipDescendants()
                }
                continue
            }

            if !includeHiddenFiles, values.isHidden == true {
                skippedFileCount += 1
                continue
            }

            guard let searchableText = TextFileCodec.searchableText(from: fileURL, maxBytes: 1_500_000) else {
                skippedFileCount += 1
                continue
            }

            scannedFileCount += 1

            let result = TextSearchService.search(in: searchableText, query: query, options: options)
            guard !result.ranges.isEmpty else {
                continue
            }

            let nsText = searchableText as NSString
            for range in result.ranges.prefix(8) {
                let lineRange = nsText.lineRange(for: range)
                let lineText = nsText.substring(with: lineRange).trimmingCharacters(in: .newlines)
                let prefix = nsText.substring(to: min(range.location, nsText.length))
                let lineNumber = prefix.reduce(into: 1) { partialResult, character in
                    if character == "\n" {
                        partialResult += 1
                    }
                }
                let lineStart = prefix.lastIndex(of: "\n").map { prefix.distance(from: prefix.startIndex, to: prefix.index(after: $0)) } ?? 0
                let columnNumber = max(1, range.location - lineStart + 1)

                hits.append(
                    ProjectSearchHit(
                        fileURL: fileURL,
                        lineNumber: lineNumber,
                        columnNumber: columnNumber,
                        lineText: lineText,
                        matchLength: range.length
                    )
                )

                if hits.count >= maxResults {
                    return ProjectSearchSummary(
                        hits: hits,
                        scannedFileCount: scannedFileCount,
                        skippedFileCount: skippedFileCount,
                        elapsedTime: Date().timeIntervalSince(startedAt)
                    )
                }
            }
        }

        return ProjectSearchSummary(
            hits: hits,
            scannedFileCount: scannedFileCount,
            skippedFileCount: skippedFileCount,
            elapsedTime: Date().timeIntervalSince(startedAt)
        )
    }
}
