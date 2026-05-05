import Foundation

enum CommandPaletteMode: String, CaseIterable, Identifiable {
    case all
    case commands
    case files
    case symbols

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .all:
            return "All"
        case .commands:
            return "Commands"
        case .files:
            return "Files"
        case .symbols:
            return "Symbols"
        }
    }

    var prefix: String? {
        switch self {
        case .all:
            return nil
        case .commands:
            return ">"
        case .files:
            return "@"
        case .symbols:
            return "#"
        }
    }

    var hint: String {
        switch self {
        case .all:
            return "Search everything"
        case .commands:
            return "> format, > git, > ai"
        case .files:
            return "@ README, @ app.swift"
        case .symbols:
            return "# AppState, # init"
        }
    }

    var symbolName: String {
        switch self {
        case .all:
            return "command"
        case .commands:
            return "terminal"
        case .files:
            return "doc.text.magnifyingglass"
        case .symbols:
            return "number"
        }
    }

    static func modeAndSearchText(for query: String, fallback: CommandPaletteMode) -> (CommandPaletteMode, String) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let first = trimmed.first else {
            return (fallback, "")
        }

        for mode in CommandPaletteMode.allCases {
            guard let prefix = mode.prefix, String(first) == prefix else {
                continue
            }

            return (mode, String(trimmed.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines))
        }

        return (fallback, trimmed)
    }
}

enum CommandPaletteItemKind: String {
    case command
    case document
    case recentFile
    case workspaceFile
    case symbol
    case task
    case plugin
    case theme
}

enum ActivityStatus: String, Codable, Hashable {
    case info
    case running
    case success
    case warning
    case failure

    var displayName: String {
        switch self {
        case .info:
            return "Info"
        case .running:
            return "Running"
        case .success:
            return "Done"
        case .warning:
            return "Check"
        case .failure:
            return "Failed"
        }
    }

    var symbolName: String {
        switch self {
        case .info:
            return "info.circle"
        case .running:
            return "clock.arrow.circlepath"
        case .success:
            return "checkmark.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .failure:
            return "xmark.octagon"
        }
    }
}

struct ActivityRecord: Identifiable, Hashable {
    let id: UUID
    let title: String
    let detail: String
    let status: ActivityStatus
    let createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        status: ActivityStatus = .info,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.status = status
        self.createdAt = createdAt
    }
}

struct WorkspaceIndexEntry: Identifiable, Hashable {
    let id: String
    let url: URL
    let rootPath: String
    let relativePath: String
    let language: DocumentLanguage
    let lineCount: Int
    let byteCount: Int64
    let symbolCount: Int
    let todoCount: Int
    let warningCount: Int
    let isLikelyConfig: Bool
    let modifiedAt: Date?

    var displayName: String {
        url.lastPathComponent
    }

    var subtitle: String {
        "\(relativePath) - \(language.displayName)"
    }
}

struct WorkspaceSymbolEntry: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String?
    let fileURL: URL
    let relativePath: String
    let language: DocumentLanguage
    let lineNumber: Int
    let level: Int

    var subtitle: String {
        "\(relativePath):\(lineNumber)"
    }
}

struct WorkspaceIndexSummary: Hashable {
    var entries: [WorkspaceIndexEntry] = []
    var symbols: [WorkspaceSymbolEntry] = []
    var rootPaths: [String] = []
    var scannedFileCount = 0
    var skippedFileCount = 0
    var warningCount = 0
    var todoCount = 0
    var elapsedTime: TimeInterval = 0
    var indexedAt: Date?
    var statusMessage: String?
    var isIndexing = false

    static let empty = WorkspaceIndexSummary(statusMessage: "Choose a workspace folder to build a fast file and symbol index.")
}

enum ReadinessTone: String, Hashable {
    case pass
    case warning
    case fail
    case info
}

struct ReleaseReadinessItem: Identifiable, Hashable {
    let id: String
    let title: String
    let detail: String
    let tone: ReadinessTone
    let symbolName: String
}

struct ReleaseReadinessState: Hashable {
    var items: [ReleaseReadinessItem] = []
    var checkedAt: Date?

    var passCount: Int {
        items.filter { $0.tone == .pass }.count
    }

    var warningCount: Int {
        items.filter { $0.tone == .warning }.count
    }

    var failureCount: Int {
        items.filter { $0.tone == .fail }.count
    }

    var isReady: Bool {
        failureCount == 0
    }
}

struct PerformanceSnapshot: Hashable {
    let capturedAt: Date
    let openDocumentCount: Int
    let dirtyDocumentCount: Int
    let indexedFileCount: Int
    let indexedSymbolCount: Int
    let workspaceRootCount: Int
    let enabledPluginCount: Int
    let taskCount: Int
    let recentActivityCount: Int
    let physicalMemoryGB: Double
    let uptime: TimeInterval
    let metrics: [PerformanceMetricSnapshot]
}

enum PerformanceMetricKind: String, CaseIterable, Identifiable, Hashable {
    case syntaxHighlighting
    case structuredViewSwitch
    case gitWorkbenchRefresh
    case gitLineDecorations
    case gitBlamePrefetch

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .syntaxHighlighting:
            return "Syntax Highlighting"
        case .structuredViewSwitch:
            return "Structured View"
        case .gitWorkbenchRefresh:
            return "Git Workbench"
        case .gitLineDecorations:
            return "Git Line Decorations"
        case .gitBlamePrefetch:
            return "Git Blame"
        }
    }
}

struct PerformanceMetricSnapshot: Hashable {
    let kind: PerformanceMetricKind
    let sampleCount: Int
    let lastDurationMS: Double
    let averageDurationMS: Double
    let maxDurationMS: Double
    let lastDetail: String?
    let lastPayload: String?
    let lastRecordedAt: Date?
}

struct DiagnosticBundleSummary: Hashable {
    let url: URL
    let createdAt: Date
    let fileCount: Int
}

struct AIRuleFile: Identifiable, Hashable {
    let id: String
    let url: URL
    let relativePath: String
    let text: String

    var title: String {
        relativePath
    }
}

struct AIPromptFile: Identifiable, Hashable {
    let id: String
    let url: URL
    let relativePath: String
    let title: String
    let text: String
}

struct AIContextState: Hashable {
    var ruleFiles: [AIRuleFile] = []
    var promptFiles: [AIPromptFile] = []
    var refreshedAt: Date?
    var statusMessage: String?
}

struct GitHubWorkflowState: Hashable {
    var repositoryURL: URL?
    var compareURL: URL?
    var branchName: String?
    var changedFileCount = 0
    var statusMessage: String?
    var refreshedAt: Date?
}
