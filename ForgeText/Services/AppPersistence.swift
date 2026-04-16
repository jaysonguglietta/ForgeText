import Foundation

enum AppSettingsStore {
    private static let defaultsKey = "forgeText.settings"
    private static let filename = "settings.json"

    static func load() -> AppSettings {
        if let data = portableData(named: filename),
           let settings = try? JSONDecoder().decode(AppSettings.self, from: data) {
            return settings
        }

        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let settings = try? JSONDecoder().decode(AppSettings.self, from: data)
        else {
            return AppSettings()
        }

        return settings
    }

    static func save(_ settings: AppSettings) {
        guard let data = try? JSONEncoder().encode(settings) else {
            return
        }

        writePortableData(data, named: filename)
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    static func export(_ settings: AppSettings, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(settings)
        try data.write(to: url, options: .atomic)
    }

    static func `import`(from url: URL) throws -> AppSettings {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(AppSettings.self, from: data)
    }

    private static func portableData(named filename: String) -> Data? {
        try? Data(contentsOf: StoragePathService.dataFileURL(named: filename))
    }

    private static func writePortableData(_ data: Data, named filename: String) {
        try? data.write(to: StoragePathService.dataFileURL(named: filename), options: .atomic)
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
        if let data = portableData(named: filename),
           let session = try? JSONDecoder().decode(StoredSession.self, from: data) {
            return session
        }

        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let session = try? JSONDecoder().decode(StoredSession.self, from: data)
        else {
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

        return session
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

        guard let data = try? JSONEncoder().encode(session) else {
            return
        }

        writePortableData(data, named: filename)
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private static func portableData(named filename: String) -> Data? {
        try? Data(contentsOf: StoragePathService.dataFileURL(named: filename))
    }

    private static func writePortableData(_ data: Data, named filename: String) {
        try? data.write(to: StoragePathService.dataFileURL(named: filename), options: .atomic)
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
        let decoder = JSONDecoder()

        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }

        return files.compactMap { fileURL in
            guard
                let data = try? Data(contentsOf: fileURL),
                let snapshot = try? decoder.decode(RecoverySnapshot.self, from: data)
            else {
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

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        guard let data = try? encoder.encode(snapshot) else {
            return
        }

        let url = snapshotURL(for: document.id)
        try? FileManager.default.createDirectory(at: recoveryDirectoryURL(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
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
        if let data = portableData(named: filename),
           let sessions = try? JSONDecoder().decode([WorkspaceSessionRecord].self, from: data) {
            return sessions.sorted { $0.savedAt > $1.savedAt }
        }

        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let sessions = try? JSONDecoder().decode([WorkspaceSessionRecord].self, from: data)
        else {
            return []
        }

        return sessions.sorted { $0.savedAt > $1.savedAt }
    }

    static func save(_ sessions: [WorkspaceSessionRecord]) {
        guard let data = try? JSONEncoder().encode(sessions) else {
            return
        }

        writePortableData(data, named: filename)
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private static func portableData(named filename: String) -> Data? {
        try? Data(contentsOf: StoragePathService.dataFileURL(named: filename))
    }

    private static func writePortableData(_ data: Data, named filename: String) {
        try? data.write(to: StoragePathService.dataFileURL(named: filename), options: .atomic)
    }
}

enum AIConversationStore {
    private static let defaultsKey = "forgeText.aiSessions"
    private static let filename = "ai-sessions.json"

    static func load() -> [AIChatSession] {
        if let data = portableData(named: filename),
           let sessions = try? JSONDecoder().decode([AIChatSession].self, from: data) {
            return sessions.sorted { $0.updatedAt > $1.updatedAt }
        }

        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let sessions = try? JSONDecoder().decode([AIChatSession].self, from: data)
        else {
            return []
        }

        return sessions.sorted { $0.updatedAt > $1.updatedAt }
    }

    static func save(_ sessions: [AIChatSession]) {
        guard let data = try? JSONEncoder().encode(sessions) else {
            return
        }

        writePortableData(data, named: filename)
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private static func portableData(named filename: String) -> Data? {
        try? Data(contentsOf: StoragePathService.dataFileURL(named: filename))
    }

    private static func writePortableData(_ data: Data, named filename: String) {
        try? data.write(to: StoragePathService.dataFileURL(named: filename), options: .atomic)
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
