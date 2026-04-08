import Foundation

enum AppSettingsStore {
    private static let defaultsKey = "forgeText.settings"

    static func load() -> AppSettings {
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
}

struct StoredSession: Codable {
    let openFilePaths: [String]
    let openRemoteSpecs: [String]
    let recentFilePaths: [String]
    let recentRemoteSpecs: [String]
    let selectedFilePath: String?
    let selectedRemoteSpec: String?
    let workspaceRootPath: String?
}

enum SessionStore {
    private static let defaultsKey = "forgeText.session"

    static func load() -> StoredSession {
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
                workspaceRootPath: nil
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
        workspaceRoot: URL?
    ) {
        let session = StoredSession(
            openFilePaths: openFiles.map(\.path),
            openRemoteSpecs: openRemoteSpecs,
            recentFilePaths: recentFiles.map(\.path),
            recentRemoteSpecs: recentRemoteSpecs,
            selectedFilePath: selectedFile?.path,
            selectedRemoteSpec: selectedRemoteSpec,
            workspaceRootPath: workspaceRoot?.path
        )

        guard let data = try? JSONEncoder().encode(session) else {
            return
        }

        UserDefaults.standard.set(data, forKey: defaultsKey)
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
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("ForgeText", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    private static func snapshotURL(for id: UUID) -> URL {
        recoveryDirectoryURL().appendingPathComponent("\(id.uuidString).json")
    }
}

enum WorkspaceSessionStore {
    private static let defaultsKey = "forgeText.workspaceSessions"

    static func load() -> [WorkspaceSessionRecord] {
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

        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}

enum AIConversationStore {
    private static let defaultsKey = "forgeText.aiSessions"

    static func load() -> [AIChatSession] {
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

        UserDefaults.standard.set(data, forKey: defaultsKey)
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
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("ForgeText", isDirectory: true)
            .appendingPathComponent("State", isDirectory: true)
            .appendingPathComponent("running.marker")
    }
}
