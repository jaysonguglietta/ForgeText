import Foundation

enum AppSettingsStore {
    private static let defaultsKey = "forgeText.settings"
    private static let filename = "settings.json"

    static func load() -> AppSettings {
        guard let settings = SensitiveDataStore.load(
            AppSettings.self,
            from: StoragePathService.dataFileURL(named: filename),
            defaultsKey: defaultsKey
        ) else {
            return AppSettings()
        }

        AIProviderKeychainStore.persistKeys(for: settings.aiProviders)
        return settings
    }

    static func save(_ settings: AppSettings) {
        AIProviderKeychainStore.persistKeys(for: settings.aiProviders)
        SensitiveDataStore.save(
            settings,
            to: StoragePathService.dataFileURL(named: filename),
            defaultsKey: defaultsKey
        )
    }

    static func export(_ settings: AppSettings, to url: URL) throws {
        AIProviderKeychainStore.persistKeys(for: settings.aiProviders)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(WorkspacePlatformService.sanitizedSettingsForTransfer(settings))
        try data.write(to: url, options: .atomic)
    }

    static func `import`(from url: URL) throws -> AppSettings {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AppSettings.self, from: data)
    }
}

struct StoredSession: Codable {
    let openFilePaths: [String]
    let openRemoteSpecs: [String]
    let recentFilePaths: [String]
    let recentRemoteSpecs: [String]
    let selectedFilePath: String?
    let selectedRemoteSpec: String?
    let workspaceRootPath: String?
    let workspaceRootPaths: [String]
    let activeWorkspaceRootPath: String?
    let workspaceFilePath: String?
    let selectedProfileID: UUID?

    init(
        openFilePaths: [String],
        openRemoteSpecs: [String],
        recentFilePaths: [String],
        recentRemoteSpecs: [String],
        selectedFilePath: String?,
        selectedRemoteSpec: String?,
        workspaceRootPath: String?,
        workspaceRootPaths: [String] = [],
        activeWorkspaceRootPath: String? = nil,
        workspaceFilePath: String? = nil,
        selectedProfileID: UUID? = nil
    ) {
        self.openFilePaths = openFilePaths
        self.openRemoteSpecs = openRemoteSpecs
        self.recentFilePaths = recentFilePaths
        self.recentRemoteSpecs = recentRemoteSpecs
        self.selectedFilePath = selectedFilePath
        self.selectedRemoteSpec = selectedRemoteSpec
        self.workspaceRootPath = workspaceRootPath
        self.workspaceRootPaths = workspaceRootPaths
        self.activeWorkspaceRootPath = activeWorkspaceRootPath
        self.workspaceFilePath = workspaceFilePath
        self.selectedProfileID = selectedProfileID
    }

    private enum CodingKeys: String, CodingKey {
        case openFilePaths
        case openRemoteSpecs
        case recentFilePaths
        case recentRemoteSpecs
        case selectedFilePath
        case selectedRemoteSpec
        case workspaceRootPath
        case workspaceRootPaths
        case activeWorkspaceRootPath
        case workspaceFilePath
        case selectedProfileID
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        openFilePaths = try container.decodeIfPresent([String].self, forKey: .openFilePaths) ?? []
        openRemoteSpecs = try container.decodeIfPresent([String].self, forKey: .openRemoteSpecs) ?? []
        recentFilePaths = try container.decodeIfPresent([String].self, forKey: .recentFilePaths) ?? []
        recentRemoteSpecs = try container.decodeIfPresent([String].self, forKey: .recentRemoteSpecs) ?? []
        selectedFilePath = try container.decodeIfPresent(String.self, forKey: .selectedFilePath)
        selectedRemoteSpec = try container.decodeIfPresent(String.self, forKey: .selectedRemoteSpec)
        workspaceRootPath = try container.decodeIfPresent(String.self, forKey: .workspaceRootPath)
        workspaceRootPaths = try container.decodeIfPresent([String].self, forKey: .workspaceRootPaths)
            ?? workspaceRootPath.map { [$0] }
            ?? []
        activeWorkspaceRootPath = try container.decodeIfPresent(String.self, forKey: .activeWorkspaceRootPath) ?? workspaceRootPath
        workspaceFilePath = try container.decodeIfPresent(String.self, forKey: .workspaceFilePath)
        selectedProfileID = try container.decodeIfPresent(UUID.self, forKey: .selectedProfileID)
    }
}

enum SessionStore {
    private static let defaultsKey = "forgeText.session"
    private static let filename = "session.json"

    static func load() -> StoredSession {
        if let session = SensitiveDataStore.load(
            StoredSession.self,
            from: StoragePathService.dataFileURL(named: filename),
            defaultsKey: defaultsKey
        ) {
            return session
        }

        return StoredSession(
            openFilePaths: [],
            openRemoteSpecs: [],
            recentFilePaths: [],
            recentRemoteSpecs: [],
            selectedFilePath: nil,
            selectedRemoteSpec: nil,
            workspaceRootPath: nil,
            workspaceRootPaths: [],
            activeWorkspaceRootPath: nil,
            workspaceFilePath: nil,
            selectedProfileID: nil
        )
    }

    static func save(
        openFiles: [URL],
        openRemoteSpecs: [String],
        recentFiles: [URL],
        recentRemoteSpecs: [String],
        selectedFile: URL?,
        selectedRemoteSpec: String?,
        workspaceRoot: URL?,
        workspaceRoots: [URL] = [],
        activeWorkspaceRoot: URL? = nil,
        workspaceFileURL: URL? = nil,
        selectedProfileID: UUID? = nil
    ) {
        let session = StoredSession(
            openFilePaths: openFiles.map(\.path),
            openRemoteSpecs: openRemoteSpecs,
            recentFilePaths: recentFiles.map(\.path),
            recentRemoteSpecs: recentRemoteSpecs,
            selectedFilePath: selectedFile?.path,
            selectedRemoteSpec: selectedRemoteSpec,
            workspaceRootPath: workspaceRoot?.path,
            workspaceRootPaths: workspaceRoots.map(\.path),
            activeWorkspaceRootPath: activeWorkspaceRoot?.path,
            workspaceFilePath: workspaceFileURL?.path,
            selectedProfileID: selectedProfileID
        )

        SensitiveDataStore.save(
            session,
            to: StoragePathService.dataFileURL(named: filename),
            defaultsKey: defaultsKey
        )
    }
}

struct RecoverySnapshot: Codable {
    let id: UUID
    let untitledName: String
    let filePath: String?
    let remoteSpec: String?
    let text: String
    let encodingRawValue: UInt
    let includesByteOrderMark: Bool
    let lineEnding: LineEnding
    let selectedLocation: Int
    let selectedLength: Int
    let lastSavedText: String
    let language: DocumentLanguage
    let savedAt: Date
    let isReadOnly: Bool
    let isPartialPreview: Bool
    let fileSize: Int64?
    let presentationMode: DocumentPresentationMode
    let followModeEnabled: Bool
    let prefersStructuredPresentation: Bool
}

enum RecoveryService {
    private static let directoryName = "Recovery"

    static func loadRecoveredDocuments() -> [EditorDocument] {
        let directory = recoveryDirectoryURL()

        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }

        return files.compactMap { fileURL in
            guard let snapshot = SensitiveDataStore.load(RecoverySnapshot.self, from: fileURL) else {
                return nil
            }

            return EditorDocument(
                id: snapshot.id,
                untitledName: snapshot.untitledName,
                text: snapshot.text,
                fileURL: snapshot.filePath.map(URL.init(fileURLWithPath:)),
                remoteReference: snapshot.remoteSpec.flatMap(RemoteFileReference.parse),
                encoding: String.Encoding(rawValue: snapshot.encodingRawValue),
                includesByteOrderMark: snapshot.includesByteOrderMark,
                lineEnding: snapshot.lineEnding,
                selectedRange: NSRange(location: snapshot.selectedLocation, length: snapshot.selectedLength),
                isDirty: true,
                lastSavedText: snapshot.lastSavedText,
                language: snapshot.language,
                findState: .init(),
                hasExternalChanges: false,
                fileMissingOnDisk: false,
                hasRecoveredDraft: true,
                lastKnownDiskFingerprint: snapshot.filePath.map { DiskFingerprint.capture(for: URL(fileURLWithPath: $0)) } ?? nil,
                lastSavedAt: snapshot.savedAt,
                statusMessage: "Recovered from autosave",
                isReadOnly: snapshot.isReadOnly,
                isPartialPreview: snapshot.isPartialPreview,
                fileSize: snapshot.fileSize,
                presentationMode: snapshot.presentationMode,
                followModeEnabled: snapshot.followModeEnabled,
                prefersStructuredPresentation: snapshot.prefersStructuredPresentation
            )
        }
    }

    static func saveSnapshot(for document: EditorDocument) {
        let snapshot = RecoverySnapshot(
            id: document.id,
            untitledName: document.untitledName,
            filePath: document.fileURL?.path,
            remoteSpec: document.remoteReference?.spec,
            text: document.text,
            encodingRawValue: document.encoding.rawValue,
            includesByteOrderMark: document.includesByteOrderMark,
            lineEnding: document.lineEnding,
            selectedLocation: document.selectedRange.location,
            selectedLength: document.selectedRange.length,
            lastSavedText: document.lastSavedText,
            language: document.language,
            savedAt: Date(),
            isReadOnly: document.isReadOnly,
            isPartialPreview: document.isPartialPreview,
            fileSize: document.fileSize,
            presentationMode: document.presentationMode,
            followModeEnabled: document.followModeEnabled,
            prefersStructuredPresentation: document.prefersStructuredPresentation
        )

        try? FileManager.default.createDirectory(at: recoveryDirectoryURL(), withIntermediateDirectories: true)
        SensitiveDataStore.save(snapshot, to: snapshotURL(for: document.id))
    }

    static func deleteSnapshot(for id: UUID) {
        try? FileManager.default.removeItem(at: snapshotURL(for: id))
    }

    static func clearAllSnapshots() {
        let directory = recoveryDirectoryURL()
        try? FileManager.default.removeItem(at: directory)
    }

    private static func recoveryDirectoryURL() -> URL {
        return StoragePathService.appDataDirectoryURL()
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    private static func snapshotURL(for id: UUID) -> URL {
        recoveryDirectoryURL().appendingPathComponent("\(id.uuidString).json")
    }
}

enum WorkspaceSessionStore {
    private static let defaultsKey = "forgeText.workspaceSessions"
    private static let filename = "workspace-sessions.json"

    static func load() -> [WorkspaceSessionRecord] {
        guard let sessions = SensitiveDataStore.load(
            [WorkspaceSessionRecord].self,
            from: StoragePathService.dataFileURL(named: filename),
            defaultsKey: defaultsKey
        ) else {
            return []
        }

        return sessions.sorted { $0.savedAt > $1.savedAt }
    }

    static func save(_ sessions: [WorkspaceSessionRecord]) {
        SensitiveDataStore.save(
            sessions,
            to: StoragePathService.dataFileURL(named: filename),
            defaultsKey: defaultsKey
        )
    }
}

enum AIConversationStore {
    private static let defaultsKey = "forgeText.aiSessions"
    private static let filename = "ai-sessions.json"

    static func load() -> [AIChatSession] {
        guard let sessions = SensitiveDataStore.load(
            [AIChatSession].self,
            from: StoragePathService.dataFileURL(named: filename),
            defaultsKey: defaultsKey
        ) else {
            return []
        }

        return sessions.sorted { $0.updatedAt > $1.updatedAt }
    }

    static func save(_ sessions: [AIChatSession]) {
        SensitiveDataStore.save(
            sessions,
            to: StoragePathService.dataFileURL(named: filename),
            defaultsKey: defaultsKey
        )
    }
}

enum CrashRecoveryMonitor {
    static func markLaunch() -> Bool {
        let url = markerURL()
        let hadUncleanShutdown = FileManager.default.fileExists(atPath: url.path)
        let marker = "launchedAt=\(Date())\n".data(using: .utf8)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        if let marker {
            try? marker.write(to: url, options: .atomic)
        }
        return hadUncleanShutdown
    }

    static func markCleanExit() {
        try? FileManager.default.removeItem(at: markerURL())
    }

    private static func markerURL() -> URL {
        return StoragePathService.appDataDirectoryURL()
            .appendingPathComponent("State", isDirectory: true)
            .appendingPathComponent("running.marker")
    }
}
