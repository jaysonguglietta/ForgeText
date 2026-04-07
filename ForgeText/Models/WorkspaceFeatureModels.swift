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

    var isStructured: Bool {
        switch self {
        case .structuredTable, .structuredJSON, .logExplorer, .structuredConfig, .archiveBrowser:
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
