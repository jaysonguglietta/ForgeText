import Foundation

struct ArchiveEntry: Identifiable, Hashable {
    let id: String
    let path: String

    var displayName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }
}

struct ArchiveDocument {
    let kindLabel: String
    let entries: [ArchiveEntry]
}

enum ArchiveBrowserService {
    static func canBrowse(_ url: URL) -> Bool {
        let lowercasedPath = url.lastPathComponent.lowercased()
        let extensionName = url.pathExtension.lowercased()
        return extensionName == "zip"
            || extensionName == "tar"
            || lowercasedPath.hasSuffix(".tgz")
            || lowercasedPath.hasSuffix(".tar.gz")
    }

    static func loadArchive(at url: URL) throws -> ArchiveDocument {
        let lowercasedPath = url.lastPathComponent.lowercased()
        let entriesText: String
        let kindLabel: String

        if url.pathExtension.lowercased() == "zip" {
            entriesText = try CommandExecutionService.runString("/usr/bin/unzip", arguments: ["-Z1", url.path])
            kindLabel = "ZIP Archive"
        } else if lowercasedPath.hasSuffix(".tgz") || lowercasedPath.hasSuffix(".tar.gz") {
            entriesText = try CommandExecutionService.runString("/usr/bin/tar", arguments: ["-tzf", url.path])
            kindLabel = "Compressed Tar Archive"
        } else {
            entriesText = try CommandExecutionService.runString("/usr/bin/tar", arguments: ["-tf", url.path])
            kindLabel = "Tar Archive"
        }

        let entries = entriesText
            .split(whereSeparator: \.isNewline)
            .map(String.init)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .map { ArchiveEntry(id: $0, path: $0) }

        return ArchiveDocument(kindLabel: kindLabel, entries: entries)
    }
}
