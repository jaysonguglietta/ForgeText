import Foundation

enum WorkspaceTrustMode: String, CaseIterable, Codable, Identifiable {
    case trusted
    case restricted

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .trusted:
            return "Trusted"
        case .restricted:
            return "Restricted"
        }
    }

    var symbolName: String {
        switch self {
        case .trusted:
            return "checkmark.shield"
        case .restricted:
            return "lock.shield"
        }
    }

    var summary: String {
        switch self {
        case .trusted:
            return "ForgeText can run workspace tasks, AI actions, remote commands, and external plugins."
        case .restricted:
            return "ForgeText keeps task execution, remote commands, AI actions, and external plugins in a safer read-mostly mode."
        }
    }
}

struct WorkspaceProfileSnapshot: Codable, Hashable {
    var theme: EditorTheme
    var chromeStyle: AppChromeStyle
    var interfaceDensity: InterfaceDensity
    var focusModeEnabled: Bool
    var wrapLines: Bool
    var autosaveToDisk: Bool
    var fontSize: Double
    var showsOutline: Bool
    var showsInspector: Bool
    var showsBreadcrumbs: Bool
    var showHiddenFilesInExplorer: Bool
    var enabledPluginIDs: [String]
    var aiIncludeSelection: Bool
    var aiIncludeCurrentDocument: Bool
    var aiIncludeWorkspaceRules: Bool

    init(
        theme: EditorTheme,
        chromeStyle: AppChromeStyle = .retroPro,
        interfaceDensity: InterfaceDensity = .compact,
        focusModeEnabled: Bool = false,
        wrapLines: Bool,
        autosaveToDisk: Bool,
        fontSize: Double,
        showsOutline: Bool,
        showsInspector: Bool = true,
        showsBreadcrumbs: Bool,
        showHiddenFilesInExplorer: Bool,
        enabledPluginIDs: [String],
        aiIncludeSelection: Bool,
        aiIncludeCurrentDocument: Bool,
        aiIncludeWorkspaceRules: Bool
    ) {
        self.theme = theme
        self.chromeStyle = chromeStyle
        self.interfaceDensity = interfaceDensity
        self.focusModeEnabled = focusModeEnabled
        self.wrapLines = wrapLines
        self.autosaveToDisk = autosaveToDisk
        self.fontSize = fontSize
        self.showsOutline = showsOutline
        self.showsInspector = showsInspector
        self.showsBreadcrumbs = showsBreadcrumbs
        self.showHiddenFilesInExplorer = showHiddenFilesInExplorer
        self.enabledPluginIDs = enabledPluginIDs
        self.aiIncludeSelection = aiIncludeSelection
        self.aiIncludeCurrentDocument = aiIncludeCurrentDocument
        self.aiIncludeWorkspaceRules = aiIncludeWorkspaceRules
    }

    private enum CodingKeys: String, CodingKey {
        case theme
        case chromeStyle
        case interfaceDensity
        case focusModeEnabled
        case wrapLines
        case autosaveToDisk
        case fontSize
        case showsOutline
        case showsInspector
        case showsBreadcrumbs
        case showHiddenFilesInExplorer
        case enabledPluginIDs
        case aiIncludeSelection
        case aiIncludeCurrentDocument
        case aiIncludeWorkspaceRules
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        theme = try container.decodeIfPresent(EditorTheme.self, forKey: .theme) ?? .forge
        chromeStyle = try container.decodeIfPresent(AppChromeStyle.self, forKey: .chromeStyle) ?? .retroPro
        interfaceDensity = try container.decodeIfPresent(InterfaceDensity.self, forKey: .interfaceDensity) ?? .compact
        focusModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .focusModeEnabled) ?? false
        wrapLines = try container.decodeIfPresent(Bool.self, forKey: .wrapLines) ?? false
        autosaveToDisk = try container.decodeIfPresent(Bool.self, forKey: .autosaveToDisk) ?? true
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? 14
        showsOutline = try container.decodeIfPresent(Bool.self, forKey: .showsOutline) ?? true
        showsInspector = try container.decodeIfPresent(Bool.self, forKey: .showsInspector) ?? true
        showsBreadcrumbs = try container.decodeIfPresent(Bool.self, forKey: .showsBreadcrumbs) ?? true
        showHiddenFilesInExplorer = try container.decodeIfPresent(Bool.self, forKey: .showHiddenFilesInExplorer) ?? false
        enabledPluginIDs = try container.decodeIfPresent([String].self, forKey: .enabledPluginIDs) ?? PluginHostService.defaultEnabledPluginIDs
        aiIncludeSelection = try container.decodeIfPresent(Bool.self, forKey: .aiIncludeSelection) ?? true
        aiIncludeCurrentDocument = try container.decodeIfPresent(Bool.self, forKey: .aiIncludeCurrentDocument) ?? true
        aiIncludeWorkspaceRules = try container.decodeIfPresent(Bool.self, forKey: .aiIncludeWorkspaceRules) ?? true
    }
}

struct WorkspaceProfile: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var snapshot: WorkspaceProfileSnapshot
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        snapshot: WorkspaceProfileSnapshot,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.snapshot = snapshot
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

struct WorkspaceFileRecord: Codable, Hashable {
    var version: Int
    var name: String
    var rootPaths: [String]
    var activeRootPath: String?
    var selectedProfileID: UUID?

    init(
        version: Int = 1,
        name: String,
        rootPaths: [String],
        activeRootPath: String? = nil,
        selectedProfileID: UUID? = nil
    ) {
        self.version = version
        self.name = name
        self.rootPaths = rootPaths
        self.activeRootPath = activeRootPath
        self.selectedProfileID = selectedProfileID
    }
}

struct WorkspaceDescriptor: Hashable {
    var name: String
    var rootURLs: [URL]
    var activeRootURL: URL?
    var workspaceFileURL: URL?
    var selectedProfileID: UUID?
}

struct TrustedWorkspaceRecord: Codable, Hashable {
    var displayPath: String
    var resolvedPath: String
    var bookmarkData: Data?

    init(displayPath: String, resolvedPath: String, bookmarkData: Data? = nil) {
        self.displayPath = displayPath
        self.resolvedPath = resolvedPath
        self.bookmarkData = bookmarkData
    }
}

struct PluginRegistryConfiguration: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var source: String
    var isEnabled: Bool

    init(id: UUID = UUID(), name: String, source: String, isEnabled: Bool = true) {
        self.id = id
        self.name = name
        self.source = source
        self.isEnabled = isEnabled
    }
}

struct PluginRegistrySnippetRecord: Codable, Hashable {
    var id: String
    var title: String
    var detail: String
    var symbolName: String
    var languages: [DocumentLanguage]
    var body: String
}

struct PluginRegistryTaskRecord: Codable, Hashable {
    var id: String
    var title: String
    var subtitle: String
    var symbolName: String
    var executable: String
    var arguments: [String]
    var workingDirectory: PluginTaskWorkingDirectory
    var role: PluginTaskRole
}

struct PluginRegistryEntry: Identifiable, Codable, Hashable {
    let id: String
    var name: String
    var version: String
    var author: String
    var summary: String
    var category: PluginCategory
    var capabilities: [PluginCapability]
    var defaultEnabled: Bool
    var sourceDescription: String?
    var snippets: [PluginRegistrySnippetRecord]
    var tasks: [PluginRegistryTaskRecord]
    var installFileName: String

    var manifest: EditorPluginManifest {
        EditorPluginManifest(
            id: id,
            name: name,
            version: version,
            author: author,
            summary: summary,
            category: category,
            capabilities: capabilities,
            isBuiltIn: false,
            sourceDescription: sourceDescription,
            defaultEnabled: defaultEnabled
        )
    }
}

struct SyncBundle: Codable {
    var exportedAt: Date
    var appSettings: AppSettings
    var workspaceSessions: [WorkspaceSessionRecord]
    var aiSessions: [AIChatSession]

    init(
        exportedAt: Date = Date(),
        appSettings: AppSettings,
        workspaceSessions: [WorkspaceSessionRecord],
        aiSessions: [AIChatSession]
    ) {
        self.exportedAt = exportedAt
        self.appSettings = appSettings
        self.workspaceSessions = workspaceSessions
        self.aiSessions = aiSessions
    }
}

struct TestCoverageSummary: Hashable {
    var toolName: String
    var percentage: Double
    var detail: String

    var formattedPercentage: String {
        String(format: "%.1f%%", percentage)
    }
}

struct GitGraphEntry: Identifiable, Hashable {
    let id: String
    let graphPrefix: String
    let commitHash: String
    let author: String
    let relativeDate: String
    let references: String
    let summary: String

    var shortCommitHash: String {
        String(commitHash.prefix(8))
    }
}

enum GitConflictResolutionStrategy: String, CaseIterable, Identifiable {
    case current
    case incoming
    case both

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .current:
            return "Current"
        case .incoming:
            return "Incoming"
        case .both:
            return "Both"
        }
    }
}

struct GitConflictSection: Identifiable, Hashable {
    let id: UUID
    let heading: String
    let currentLabel: String
    let currentText: String
    let baseText: String?
    let incomingLabel: String
    let incomingText: String

    init(
        id: UUID = UUID(),
        heading: String,
        currentLabel: String,
        currentText: String,
        baseText: String?,
        incomingLabel: String,
        incomingText: String
    ) {
        self.id = id
        self.heading = heading
        self.currentLabel = currentLabel
        self.currentText = currentText
        self.baseText = baseText
        self.incomingLabel = incomingLabel
        self.incomingText = incomingText
    }
}

enum RemoteExecutionMode: String, CaseIterable, Codable, Identifiable {
    case directShell
    case remoteAgent

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .directShell:
            return "Direct Shell"
        case .remoteAgent:
            return "Remote Agent"
        }
    }
}

struct RemoteAgentStatus: Hashable {
    var connection: String
    var isInstalled: Bool
    var version: String?
    var installPath: String
    var checkedAt: Date
    var lastError: String?

    static func unavailable(connection: String, installPath: String, error: String? = nil) -> RemoteAgentStatus {
        RemoteAgentStatus(
            connection: connection,
            isInstalled: false,
            version: nil,
            installPath: installPath,
            checkedAt: Date(),
            lastError: error
        )
    }
}

struct WorkspacePlatformState {
    var workspaceName = "Workspace"
    var rootPaths: [String] = []
    var activeRootPath: String?
    var workspaceFilePath: String?
    var selectedProfileID: UUID?
    var profileDraftName = ""
    var registryDraftName = ""
    var registryDraftSource = ""
    var lastStatusMessage: String?
    var registryEntries: [PluginRegistryEntry] = []
    var lastRegistryRefreshAt: Date?
    var isRefreshingRegistry = false
}

extension AppSettings {
    var profileSnapshot: WorkspaceProfileSnapshot {
        WorkspaceProfileSnapshot(
            theme: theme,
            chromeStyle: chromeStyle,
            interfaceDensity: interfaceDensity,
            focusModeEnabled: focusModeEnabled,
            wrapLines: wrapLines,
            autosaveToDisk: autosaveToDisk,
            fontSize: fontSize,
            showsOutline: showsOutline,
            showsInspector: showsInspector,
            showsBreadcrumbs: showsBreadcrumbs,
            showHiddenFilesInExplorer: showHiddenFilesInExplorer,
            enabledPluginIDs: enabledPluginIDs,
            aiIncludeSelection: aiIncludeSelection,
            aiIncludeCurrentDocument: aiIncludeCurrentDocument,
            aiIncludeWorkspaceRules: aiIncludeWorkspaceRules
        )
    }

    mutating func apply(profileSnapshot: WorkspaceProfileSnapshot) {
        theme = profileSnapshot.theme
        chromeStyle = profileSnapshot.chromeStyle
        interfaceDensity = profileSnapshot.interfaceDensity
        focusModeEnabled = profileSnapshot.focusModeEnabled
        wrapLines = profileSnapshot.wrapLines
        autosaveToDisk = profileSnapshot.autosaveToDisk
        fontSize = profileSnapshot.fontSize
        showsOutline = profileSnapshot.showsOutline
        showsInspector = profileSnapshot.showsInspector
        showsBreadcrumbs = profileSnapshot.showsBreadcrumbs
        showHiddenFilesInExplorer = profileSnapshot.showHiddenFilesInExplorer
        enabledPluginIDs = profileSnapshot.enabledPluginIDs
        aiIncludeSelection = profileSnapshot.aiIncludeSelection
        aiIncludeCurrentDocument = profileSnapshot.aiIncludeCurrentDocument
        aiIncludeWorkspaceRules = profileSnapshot.aiIncludeWorkspaceRules
    }
}
