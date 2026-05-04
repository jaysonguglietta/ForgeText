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
        let normalizedRoots = normalizedRootURLs(from: roots)
        guard !normalizedRoots.isEmpty else {
            return .trusted
        }

        return normalizedRoots.allSatisfy { isTrusted(root: $0, settings: settings) } ? .trusted : .restricted
    }

    static func markTrusted(roots: [URL], settings: inout AppSettings) {
        var trustedRecords = settings.trustedWorkspaces
        for root in normalizedRootURLs(from: roots) {
            trustedRecords.removeAll { matchesTrustedRecord($0, root: root) }
            trustedRecords.append(trustedRecord(for: root))
        }

        trustedRecords.sort { $0.displayPath.localizedCaseInsensitiveCompare($1.displayPath) == .orderedAscending }
        settings.trustedWorkspaces = trustedRecords
        settings.trustedWorkspacePaths = trustedRecords.map(\.resolvedPath)
    }

    static func markRestricted(roots: [URL], settings: inout AppSettings) {
        let rootsToRemove = normalizedRootURLs(from: roots)
        settings.trustedWorkspaces.removeAll { record in
            rootsToRemove.contains { matchesTrustedRecord(record, root: $0) }
        }
        let legacyTrustedPaths = Set(settings.trustedWorkspacePaths)
        let remainingLegacyPaths = legacyTrustedPaths.filter { path in
            let url = URL(fileURLWithPath: path, isDirectory: true)
            return !rootsToRemove.contains { canonicalTrustRootURL(for: $0).path == canonicalTrustRootURL(for: url).path }
        }
        settings.trustedWorkspacePaths = Array(remainingLegacyPaths).sorted()
    }

    static func exportSyncBundle(
        settings: AppSettings,
        workspaceSessions: [WorkspaceSessionRecord],
        aiSessions: [AIChatSession],
        to url: URL
    ) throws {
        let bundle = SyncBundle(
            appSettings: sanitizedSettingsForTransfer(settings),
            workspaceSessions: sanitizedWorkspaceSessionsForTransfer(workspaceSessions),
            aiSessions: sanitizedAISessionsForTransfer(aiSessions)
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

    static func sanitizedSettingsForTransfer(_ settings: AppSettings) -> AppSettings {
        var sanitized = settings
        sanitized.workspaceFavoritePaths = []
        sanitized.trustedWorkspacePaths = []
        sanitized.trustedWorkspaces = []
        sanitized.pluginRegistries = []
        sanitized.enabledPluginIDs = PluginHostService.defaultEnabledPluginIDs
        sanitized.profiles = settings.profiles.map(sanitizedProfileForTransfer)
        return sanitized
    }

    static func mergedImportedSettings(_ imported: AppSettings, preservingSecuritySensitiveValuesFrom current: AppSettings) -> AppSettings {
        var merged = sanitizedSettingsForTransfer(imported)
        merged.enabledPluginIDs = current.enabledPluginIDs
        merged.pluginRegistries = current.pluginRegistries
        merged.trustedWorkspacePaths = current.trustedWorkspacePaths
        merged.trustedWorkspaces = current.trustedWorkspaces
        merged.workspaceFavoritePaths = current.workspaceFavoritePaths
        return merged
    }

    static func sanitizedWorkspaceSessionsForTransfer(_ sessions: [WorkspaceSessionRecord]) -> [WorkspaceSessionRecord] {
        []
    }

    static func sanitizedAISessionsForTransfer(_ sessions: [AIChatSession]) -> [AIChatSession] {
        []
    }

    private static func sanitizedProfileForTransfer(_ profile: WorkspaceProfile) -> WorkspaceProfile {
        var sanitized = profile
        sanitized.snapshot.enabledPluginIDs = PluginHostService.defaultEnabledPluginIDs
        return sanitized
    }

    private static func isTrusted(root: URL, settings: AppSettings) -> Bool {
        if settings.trustedWorkspaces.contains(where: { matchesTrustedRecord($0, root: root) }) {
            return true
        }

        guard settings.trustedWorkspaces.isEmpty else {
            return false
        }

        let legacyTrustedPaths = settings.trustedWorkspacePaths.map {
            canonicalTrustRootURL(for: URL(fileURLWithPath: $0, isDirectory: true)).path
        }
        let canonicalRootPath = canonicalTrustRootURL(for: root).path
        return legacyTrustedPaths.contains(canonicalRootPath)
    }

    private static func trustedRecord(for root: URL) -> TrustedWorkspaceRecord {
        let displayURL = root.standardizedFileURL
        let canonicalURL = canonicalTrustRootURL(for: root)
        let bookmarkData = try? canonicalURL.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        return TrustedWorkspaceRecord(
            displayPath: displayURL.path,
            resolvedPath: canonicalURL.path,
            bookmarkData: bookmarkData
        )
    }

    private static func matchesTrustedRecord(_ record: TrustedWorkspaceRecord, root: URL) -> Bool {
        trustedRecordURL(for: record)?.path == canonicalTrustRootURL(for: root).path
    }

    private static func trustedRecordURL(for record: TrustedWorkspaceRecord) -> URL? {
        if let bookmarkData = record.bookmarkData {
            var isStale = false
            if let resolvedURL = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: [.withoutUI, .withoutMounting],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                return canonicalTrustRootURL(for: resolvedURL)
            }
        }

        if !record.resolvedPath.isEmpty {
            return canonicalTrustRootURL(for: URL(fileURLWithPath: record.resolvedPath, isDirectory: true))
        }

        guard !record.displayPath.isEmpty else {
            return nil
        }

        return canonicalTrustRootURL(for: URL(fileURLWithPath: record.displayPath, isDirectory: true))
    }

    private static func canonicalTrustRootURL(for url: URL) -> URL {
        url.resolvingSymlinksInPath().standardizedFileURL
    }
}
