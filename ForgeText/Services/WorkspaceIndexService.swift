import Foundation

enum WorkspaceIndexService {
    private static let ignoredDirectoryNames: Set<String> = [
        ".git",
        ".svn",
        ".hg",
        ".build",
        ".cache",
        ".next",
        ".terraform",
        "DerivedData",
        "build",
        "dist",
        "node_modules",
        "Pods",
        "vendor",
    ]

    private static let likelyBinaryExtensions: Set<String> = [
        "a",
        "app",
        "bin",
        "bmp",
        "class",
        "dmg",
        "doc",
        "docx",
        "dylib",
        "exe",
        "gif",
        "heic",
        "icns",
        "ico",
        "jar",
        "jpeg",
        "jpg",
        "mov",
        "mp3",
        "mp4",
        "o",
        "pdf",
        "png",
        "so",
        "sqlite",
        "ttf",
        "woff",
        "woff2",
        "xls",
        "xlsx",
        "zip",
    ]

    static func index(
        roots: [URL],
        includeHiddenFiles: Bool,
        maxFiles: Int = 2_500,
        maxTextBytes: Int = 900_000
    ) -> WorkspaceIndexSummary {
        let startedAt = Date()
        var entries: [WorkspaceIndexEntry] = []
        var symbols: [WorkspaceSymbolEntry] = []
        var scannedFileCount = 0
        var skippedFileCount = 0
        var totalWarnings = 0
        var totalTodos = 0

        let standardizedRoots = roots.map(\.standardizedFileURL)

        for root in standardizedRoots {
            guard entries.count < maxFiles else {
                break
            }

            guard let enumerator = FileManager.default.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isRegularFileKey, .isHiddenKey, .fileSizeKey, .contentModificationDateKey],
                options: [.skipsPackageDescendants],
                errorHandler: { _, _ in true }
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator {
                guard entries.count < maxFiles else {
                    break
                }

                let values = try? fileURL.resourceValues(
                    forKeys: [.isDirectoryKey, .isRegularFileKey, .isHiddenKey, .fileSizeKey, .contentModificationDateKey]
                )

                if values?.isDirectory == true {
                    if shouldSkipDirectory(fileURL, includeHiddenFiles: includeHiddenFiles, isHidden: values?.isHidden == true) {
                        enumerator.skipDescendants()
                    }
                    continue
                }

                guard values?.isRegularFile == true else {
                    continue
                }

                if !includeHiddenFiles, values?.isHidden == true {
                    skippedFileCount += 1
                    continue
                }

                guard !likelyBinaryExtensions.contains(fileURL.pathExtension.lowercased()) else {
                    skippedFileCount += 1
                    continue
                }

                let byteCount = Int64(values?.fileSize ?? 0)
                guard byteCount <= Int64(maxTextBytes) else {
                    skippedFileCount += 1
                    continue
                }

                guard let data = try? Data(contentsOf: fileURL, options: [.mappedIfSafe]), !looksBinary(data) else {
                    skippedFileCount += 1
                    continue
                }

                let text = String(decoding: data, as: UTF8.self)
                let language = DocumentLanguage.detect(from: fileURL, text: text)
                let relativePath = relativePath(for: fileURL, root: root)
                let lineCount = text.isEmpty ? 0 : text.split(whereSeparator: \.isNewline).count
                let todoCount = countMatches(in: text, needles: ["TODO", "FIXME", "HACK"])
                let warningCount = countMatches(in: text, needles: ["password=", "api_key", "secret=", "private_key", "BEGIN RSA PRIVATE KEY"])
                let outlineItems = outlineItems(for: text, language: language, url: fileURL)

                scannedFileCount += 1
                totalTodos += todoCount
                totalWarnings += warningCount

                let entry = WorkspaceIndexEntry(
                    id: fileURL.path,
                    url: fileURL,
                    rootPath: root.path,
                    relativePath: relativePath,
                    language: language,
                    lineCount: lineCount,
                    byteCount: byteCount,
                    symbolCount: outlineItems.count,
                    todoCount: todoCount,
                    warningCount: warningCount,
                    isLikelyConfig: language == .config || fileURL.pathComponents.contains(".github") || fileURL.lastPathComponent.hasPrefix("."),
                    modifiedAt: values?.contentModificationDate
                )
                entries.append(entry)

                symbols.append(contentsOf: outlineItems.map { item in
                    WorkspaceSymbolEntry(
                        id: "\(fileURL.path):\(item.lineNumber):\(item.title)",
                        title: item.title,
                        detail: item.detail,
                        fileURL: fileURL,
                        relativePath: relativePath,
                        language: language,
                        lineNumber: item.lineNumber,
                        level: item.level
                    )
                })
            }
        }

        let elapsed = Date().timeIntervalSince(startedAt)
        let status: String
        if standardizedRoots.isEmpty {
            status = "Choose a workspace folder to build a fast file and symbol index."
        } else if entries.isEmpty {
            status = "No indexable text files were found in the current workspace."
        } else {
            status = "Indexed \(entries.count) files and \(symbols.count) symbols in \(String(format: "%.2f", elapsed))s."
        }

        return WorkspaceIndexSummary(
            entries: entries.sorted { $0.relativePath.localizedCaseInsensitiveCompare($1.relativePath) == .orderedAscending },
            symbols: symbols.sorted {
                if $0.relativePath == $1.relativePath {
                    return $0.lineNumber < $1.lineNumber
                }
                return $0.relativePath.localizedCaseInsensitiveCompare($1.relativePath) == .orderedAscending
            },
            rootPaths: standardizedRoots.map(\.path),
            scannedFileCount: scannedFileCount,
            skippedFileCount: skippedFileCount,
            warningCount: totalWarnings,
            todoCount: totalTodos,
            elapsedTime: elapsed,
            indexedAt: Date(),
            statusMessage: status,
            isIndexing: false
        )
    }

    private static func shouldSkipDirectory(_ url: URL, includeHiddenFiles: Bool, isHidden: Bool) -> Bool {
        if ignoredDirectoryNames.contains(url.lastPathComponent) {
            return true
        }

        return !includeHiddenFiles && isHidden
    }

    private static func relativePath(for fileURL: URL, root: URL) -> String {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        return fileURL.path
            .replacingOccurrences(of: rootPath, with: "", options: [.anchored])
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    }

    private static func looksBinary(_ data: Data) -> Bool {
        data.prefix(512).contains(0)
    }

    private static func countMatches(in text: String, needles: [String]) -> Int {
        let lowercased = text.lowercased()
        return needles.reduce(into: 0) { count, needle in
            var searchRange = lowercased.startIndex..<lowercased.endIndex
            let lowerNeedle = needle.lowercased()
            while let range = lowercased.range(of: lowerNeedle, options: [], range: searchRange) {
                count += 1
                searchRange = range.upperBound..<lowercased.endIndex
            }
        }
    }

    private static func outlineItems(for text: String, language: DocumentLanguage, url: URL) -> [OutlineItem] {
        guard text.utf8.count < 600_000 else {
            return []
        }

        return DocumentOutlineService.outline(text: text, language: language, url: url)
    }
}
