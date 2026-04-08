import Foundation

enum DocumentPresentationMode: String, Codable {
    case editor
    case readOnlyPreview
    case binaryHex
    case structuredTable
    case structuredJSON
    case logExplorer
    case structuredConfig
    case archiveBrowser
    case httpRequest

    var isStructured: Bool {
        switch self {
        case .structuredTable, .structuredJSON, .logExplorer, .structuredConfig, .archiveBrowser, .httpRequest:
            return true
        case .editor, .readOnlyPreview, .binaryHex:
            return false
        }
    }

    var displayName: String {
        switch self {
        case .editor:
            return "Editor"
        case .readOnlyPreview:
            return "Preview"
        case .binaryHex:
            return "Hex Preview"
        case .structuredTable:
            return "Table View"
        case .structuredJSON:
            return "JSON Tree"
        case .logExplorer:
            return "Log Explorer"
        case .structuredConfig:
            return "Config Inspector"
        case .archiveBrowser:
            return "Archive Browser"
        case .httpRequest:
            return "HTTP Runner"
        }
    }

    var symbolName: String {
        switch self {
        case .editor, .readOnlyPreview:
            return "doc.text"
        case .binaryHex:
            return "square.grid.3x2"
        case .structuredTable:
            return "tablecells"
        case .structuredJSON:
            return "list.bullet.indent"
        case .logExplorer:
            return "list.bullet.rectangle.portrait"
        case .structuredConfig:
            return "slider.horizontal.below.square.filled.and.square"
        case .archiveBrowser:
            return "archivebox"
        case .httpRequest:
            return "network.badge.shield.half.filled"
        }
    }
}

enum WorkspaceSecondaryPaneMode: String, CaseIterable, Codable, Identifiable {
    case off
    case alternatePresentation
    case secondDocument

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .off:
            return "Single Pane"
        case .alternatePresentation:
            return "Raw + Structured"
        case .secondDocument:
            return "Second Document"
        }
    }
}

enum LogSeverityFilterMode: String, CaseIterable, Codable, Identifiable {
    case all
    case warningsAndAbove
    case errorsOnly
    case infoAndDebug

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:
            return "All"
        case .warningsAndAbove:
            return "Warnings+"
        case .errorsOnly:
            return "Errors"
        case .infoAndDebug:
            return "Info/Debug"
        }
    }

    func includes(_ severity: LogSeverity) -> Bool {
        switch self {
        case .all:
            return true
        case .warningsAndAbove:
            return severity.rank >= LogSeverity.warning.rank
        case .errorsOnly:
            return severity.rank >= LogSeverity.error.rank
        case .infoAndDebug:
            return severity == .trace || severity == .debug || severity == .info || severity == .notice
        }
    }
}

enum LogGroupingMode: String, CaseIterable, Codable, Identifiable {
    case none
    case severity
    case source

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none:
            return "Ungrouped"
        case .severity:
            return "By Severity"
        case .source:
            return "By Source"
        }
    }
}

struct SavedLogFilter: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var query: String
    var severity: LogSeverityFilterMode
    var startTimestamp: String
    var endTimestamp: String
    var grouping: LogGroupingMode

    init(
        id: UUID = UUID(),
        name: String,
        query: String,
        severity: LogSeverityFilterMode,
        startTimestamp: String,
        endTimestamp: String,
        grouping: LogGroupingMode
    ) {
        self.id = id
        self.name = name
        self.query = query
        self.severity = severity
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
        self.grouping = grouping
    }
}

struct RemoteFileReference: Identifiable, Codable, Hashable {
    let id: String
    let connection: String
    let path: String

    init(connection: String, path: String) {
        self.connection = connection
        self.path = path
        id = "\(connection):\(path)"
    }

    var spec: String {
        "\(connection):\(path)"
    }

    var displayName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var pathDescription: String {
        "\(connection):\(path)"
    }

    static func parse(_ spec: String) -> RemoteFileReference? {
        let trimmed = spec.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let separatorIndex = trimmed.firstIndex(of: ":") else {
            return nil
        }

        let connection = String(trimmed[..<separatorIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
        let path = String(trimmed[trimmed.index(after: separatorIndex)...]).trimmingCharacters(in: .whitespacesAndNewlines)

        guard !connection.isEmpty, !path.isEmpty else {
            return nil
        }

        return RemoteFileReference(connection: connection, path: path)
    }
}

struct WorkspaceSessionRecord: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var openFilePaths: [String]
    var openRemoteSpecs: [String]
    var selectedFilePath: String?
    var selectedRemoteSpec: String?
    var workspaceRootPath: String?
    var theme: EditorTheme
    var wrapLines: Bool
    var fontSize: Double
    var savedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        openFilePaths: [String],
        openRemoteSpecs: [String],
        selectedFilePath: String?,
        selectedRemoteSpec: String?,
        workspaceRootPath: String?,
        theme: EditorTheme,
        wrapLines: Bool,
        fontSize: Double,
        savedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.openFilePaths = openFilePaths
        self.openRemoteSpecs = openRemoteSpecs
        self.selectedFilePath = selectedFilePath
        self.selectedRemoteSpec = selectedRemoteSpec
        self.workspaceRootPath = workspaceRootPath
        self.theme = theme
        self.wrapLines = wrapLines
        self.fontSize = fontSize
        self.savedAt = savedAt
    }
}

struct ProjectSearchHit: Identifiable, Hashable {
    let id = UUID()
    let fileURL: URL
    let lineNumber: Int
    let columnNumber: Int
    let lineText: String
    let matchLength: Int
}

struct ProjectSearchSummary {
    let hits: [ProjectSearchHit]
    let scannedFileCount: Int
    let skippedFileCount: Int
    let elapsedTime: TimeInterval
}

struct ProjectSearchState {
    var isPresented = false
    var rootURL: URL?
    var query = ""
    var isCaseSensitive = false
    var usesRegularExpression = false
    var includeHiddenFiles = false
    var isSearching = false
    var hits: [ProjectSearchHit] = []
    var scannedFileCount = 0
    var skippedFileCount = 0
    var elapsedTime: TimeInterval = 0
    var statusMessage: String?

    var summary: String {
        if let statusMessage {
            return statusMessage
        }

        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Search a folder for text matches"
        }

        if isSearching {
            return "Searching..."
        }

        if hits.isEmpty {
            return "No matches"
        }

        return "\(hits.count) matches in \(scannedFileCount) files"
    }
}

enum DiffLineKind: String, Codable {
    case unchanged
    case inserted
    case deleted
}

struct DiffLine: Identifiable, Hashable {
    let id = UUID()
    let kind: DiffLineKind
    let leftLineNumber: Int?
    let rightLineNumber: Int?
    let leftText: String?
    let rightText: String?
}

struct DocumentComparisonState: Identifiable {
    let id = UUID()
    let title: String
    let leftTitle: String
    let rightTitle: String
    let lines: [DiffLine]
    let changedLineCount: Int
}

struct WorkspaceExplorerNode: Identifiable, Hashable {
    let id: String
    let name: String
    let url: URL
    let isDirectory: Bool
    let isHidden: Bool
    let isFavorite: Bool
    let children: [WorkspaceExplorerNode]

    var childrenOrNil: [WorkspaceExplorerNode]? {
        children.isEmpty ? nil : children
    }

    var subtitle: String {
        url.path(percentEncoded: false)
    }
}

struct WorkspaceExplorerState {
    var filterQuery = ""
    var includeHiddenFiles = false
    var nodes: [WorkspaceExplorerNode] = []
    var lastRefreshedAt: Date?
    var statusMessage: String?
}

enum EditorLineDecorationKind: String, Codable, Hashable {
    case gitChanged
    case gitAdded
    case diagnosticInfo
    case diagnosticWarning
    case diagnosticError
}

struct EditorLineDecoration: Identifiable, Hashable {
    let id: String
    let lineNumber: Int
    let kind: EditorLineDecorationKind
    let message: String?

    init(lineNumber: Int, kind: EditorLineDecorationKind, message: String? = nil) {
        self.id = "\(kind.rawValue)-\(lineNumber)-\(message ?? "")"
        self.lineNumber = lineNumber
        self.kind = kind
        self.message = message
    }
}

struct TerminalCommandRun: Identifiable, Hashable {
    let id: UUID
    let command: String
    let workingDirectoryPath: String?
    let startedAt: Date
    var endedAt: Date?
    var output: String
    var status: PluginExecutionStatus
    var exitCode: Int32?

    init(
        id: UUID = UUID(),
        command: String,
        workingDirectoryPath: String?,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        output: String = "",
        status: PluginExecutionStatus = .idle,
        exitCode: Int32? = nil
    ) {
        self.id = id
        self.command = command
        self.workingDirectoryPath = workingDirectoryPath
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.output = output
        self.status = status
        self.exitCode = exitCode
    }
}

struct EmbeddedTerminalPanelState {
    var commandText = ""
    var history: [String] = []
    var lastRun: TerminalCommandRun?
}

struct RemoteSearchHit: Identifiable, Hashable {
    let id = UUID()
    let connection: String
    let path: String
    let lineNumber: Int
    let lineText: String
}

struct RemoteWorkspaceState {
    var searchRootPath = ""
    var searchQuery = ""
    var commandText = ""
    var grepResults: [RemoteSearchHit] = []
    var lastCommandOutput: String?
    var lastCommandStatus: PluginExecutionStatus = .idle
    var isRunningCommand = false
    var isSearching = false
    var statusMessage: String?
}

struct CloneRepositoryState {
    var repositorySpecifier = ""
    var destinationParentPath = ""
    var directoryName = ""
    var branchName = ""
    var usesShallowClone = false
    var isCloning = false
    var statusMessage: String?
}

struct GitChangedFile: Identifiable, Hashable {
    let id: String
    let relativePath: String
    let absoluteURL: URL
    let indexStatus: String
    let workTreeStatus: String

    var displayName: String {
        URL(fileURLWithPath: relativePath).lastPathComponent
    }

    var statusSummary: String {
        let components = [indexStatus, workTreeStatus]
            .map { $0 == " " ? "-" : $0 }
        return components.joined(separator: "/")
    }

    var isConflicted: Bool {
        indexStatus == "U" || workTreeStatus == "U"
    }
}

struct GitStashEntry: Identifiable, Hashable {
    let id: String
    let name: String
    let summary: String
}

struct GitPanelState {
    var changedFiles: [GitChangedFile] = []
    var stashes: [GitStashEntry] = []
    var commitMessage = ""
    var newBranchName = ""
    var stashMessage = ""
    var isBusy = false
    var lastOperationMessage: String?
}

struct ProblemRecord: Identifiable, Hashable {
    let id = UUID()
    let source: String
    let severity: PluginDiagnosticSeverity
    let filePath: String?
    let lineNumber: Int?
    let columnNumber: Int?
    let message: String
    let detail: String?
}

struct ProblemsPanelState {
    var records: [ProblemRecord] = []
    var sourceDescription = "Problems"
    var lastUpdatedAt: Date?
}

struct TestExplorerState {
    var selectedTaskID: String?
    var lastRun: PluginTaskRun?
}

struct AIWorkbenchState {
    var sessions: [AIChatSession] = []
    var selectedSessionID: UUID?
    var draftPrompt = ""
    var isSending = false
    var lastResponseText: String?
    var lastAction: AIQuickAction?
    var statusMessage: String?
}

struct GitBlameInfo: Hashable {
    let commitHash: String
    let author: String
    let summary: String
    let authoredAt: Date?

    var shortCommitHash: String {
        String(commitHash.prefix(8))
    }
}
