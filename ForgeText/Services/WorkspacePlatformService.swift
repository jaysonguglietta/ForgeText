import Foundation

enum WorkspacePlatformService {
    static let workspaceFileExtension = "forgetext-workspace"

    static func normalizedRootURLs(from urls: [URL]) -> [URL] {
        var seenPaths = Set<String>()
        return urls
            .map(\.standardizedFileURL)
            .filter { seenPaths.insert($0.path).inserted }
    }

    static func descriptor(
        name: String,
        roots: [URL],
        activeRoot: URL?,
        workspaceFileURL: URL? = nil,
        selectedProfileID: UUID? = nil
    ) -> WorkspaceDescriptor {
        let normalizedRoots = normalizedRootURLs(from: roots)
        let normalizedActiveRoot = activeRoot?.standardizedFileURL

        return WorkspaceDescriptor(
            name: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? preferredWorkspaceName(for: normalizedRoots) : name,
            rootURLs: normalizedRoots,
            activeRootURL: normalizedActiveRoot ?? normalizedRoots.first,
            workspaceFileURL: workspaceFileURL?.standardizedFileURL,
            selectedProfileID: selectedProfileID
        )
    }

    static func preferredWorkspaceName(for roots: [URL]) -> String {
        guard !roots.isEmpty else {
            return "Workspace"
        }

        if roots.count == 1 {
            return roots[0].lastPathComponent
        }

        return "\(roots[0].lastPathComponent) +\(roots.count - 1)"
    }

    static func loadWorkspace(from url: URL) throws -> WorkspaceDescriptor {
        let data = try Data(contentsOf: url)
        let record = try JSONDecoder().decode(WorkspaceFileRecord.self, from: data)
        let rootURLs = normalizedRootURLs(from: record.rootPaths.map { URL(fileURLWithPath: $0, isDirectory: true) })

        return WorkspaceDescriptor(
            name: record.name,
            rootURLs: rootURLs,
            activeRootURL: record.activeRootPath.map { URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL } ?? rootURLs.first,
            workspaceFileURL: url.standardizedFileURL,
            selectedProfileID: record.selectedProfileID
        )
    }

    static func saveWorkspace(_ descriptor: WorkspaceDescriptor, to url: URL) throws {
        let record = WorkspaceFileRecord(
            name: descriptor.name,
            rootPaths: descriptor.rootURLs.map(\.path),
            activeRootPath: descriptor.activeRootURL?.path,
            selectedProfileID: descriptor.selectedProfileID
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(record)
        try data.write(to: url, options: .atomic)
    }

    static func trustMode(for roots: [URL], settings: AppSettings) -> WorkspaceTrustMode {
        let trustedPaths = Set(settings.trustedWorkspacePaths)
        let normalizedPaths = normalizedRootURLs(from: roots).map(\.path)

        guard !normalizedPaths.isEmpty else {
            return .trusted
        }

        return normalizedPaths.allSatisfy(trustedPaths.contains) ? .trusted : .restricted
    }

    static func markTrusted(roots: [URL], settings: inout AppSettings) {
        var trustedPaths = Set(settings.trustedWorkspacePaths)
        for path in normalizedRootURLs(from: roots).map(\.path) {
            trustedPaths.insert(path)
        }
        settings.trustedWorkspacePaths = Array(trustedPaths).sorted()
    }

    static func markRestricted(roots: [URL], settings: inout AppSettings) {
        var trustedPaths = Set(settings.trustedWorkspacePaths)
        for path in normalizedRootURLs(from: roots).map(\.path) {
            trustedPaths.remove(path)
        }
        settings.trustedWorkspacePaths = Array(trustedPaths).sorted()
    }

    static func exportSyncBundle(
        settings: AppSettings,
        workspaceSessions: [WorkspaceSessionRecord],
        aiSessions: [AIChatSession],
        to url: URL
    ) throws {
        let bundle = SyncBundle(
            appSettings: settings,
            workspaceSessions: workspaceSessions,
            aiSessions: aiSessions
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(bundle)
        try data.write(to: url, options: .atomic)
    }

    static func importSyncBundle(from url: URL) throws -> SyncBundle {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(SyncBundle.self, from: data)
    }
}
