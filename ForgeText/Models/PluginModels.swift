import Foundation

enum PluginCategory: String, CaseIterable, Codable, Identifiable {
    case languageTools
    case snippets
    case workspaceAutomation
    case sourceControl

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .languageTools:
            return "Language Tools"
        case .snippets:
            return "Snippets"
        case .workspaceAutomation:
            return "Workspace Automation"
        case .sourceControl:
            return "Source Control"
        }
    }
}

enum PluginCapability: String, CaseIterable, Codable, Identifiable {
    case commands
    case snippets
    case tasks
    case diagnostics
    case formatting
    case statusItems
    case languagePacks

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .commands:
            return "Commands"
        case .snippets:
            return "Snippets"
        case .tasks:
            return "Tasks"
        case .diagnostics:
            return "Diagnostics"
        case .formatting:
            return "Formatting"
        case .statusItems:
            return "Status Items"
        case .languagePacks:
            return "Language Packs"
        }
    }
}

struct EditorPluginManifest: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let version: String
    let author: String
    let summary: String
    let category: PluginCategory
    let capabilities: [PluginCapability]
    let isBuiltIn: Bool
    let sourceDescription: String?
    let defaultEnabled: Bool
}

enum EditorPluginCommandAction: Hashable {
    case showTaskRunner
    case showSnippetLibrary
    case runDiagnostics
    case formatDocument
    case runPrimaryTask(PluginTaskRole)
    case refreshGitStatus
    case compareWithGitHead
}

struct EditorPluginCommand: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let symbolName: String
    let action: EditorPluginCommandAction
}

struct EditorPluginSnippet: Identifiable, Hashable {
    let id: String
    let pluginID: String
    let title: String
    let detail: String
    let symbolName: String
    let languages: [DocumentLanguage]
    let body: String

    var previewText: String {
        body
            .replacingOccurrences(of: "$SELECTION", with: "…")
            .replacingOccurrences(of: "$0", with: "")
    }
}

enum PluginTaskRole: String, CaseIterable, Codable, Identifiable, Hashable {
    case build
    case test
    case lint
    case run
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .build:
            return "Build"
        case .test:
            return "Test"
        case .lint:
            return "Lint"
        case .run:
            return "Run"
        case .custom:
            return "Task"
        }
    }
}

enum PluginTaskWorkingDirectory: String, Codable, Hashable {
    case workspaceRoot
    case documentDirectory
}

struct EditorPluginTask: Identifiable, Hashable {
    let id: String
    let pluginID: String
    let pluginName: String
    let title: String
    let subtitle: String
    let symbolName: String
    let executable: String
    let arguments: [String]
    let workingDirectory: PluginTaskWorkingDirectory
    let role: PluginTaskRole
    let rootPath: String?
    let supportsCoverage: Bool

    var commandDescription: String {
        ([executable] + arguments).joined(separator: " ")
    }
}

enum PluginExecutionStatus: String, Codable, Hashable {
    case idle
    case running
    case succeeded
    case failed

    var displayName: String {
        switch self {
        case .idle:
            return "Idle"
        case .running:
            return "Running"
        case .succeeded:
            return "Succeeded"
        case .failed:
            return "Failed"
        }
    }
}

struct PluginTaskRun: Identifiable, Hashable {
    let id: UUID
    let taskID: String
    let taskTitle: String
    let commandDescription: String
    let startedAt: Date
    var endedAt: Date?
    var output: String
    var status: PluginExecutionStatus
    var exitCode: Int32?

    init(
        id: UUID = UUID(),
        taskID: String,
        taskTitle: String,
        commandDescription: String,
        startedAt: Date = Date(),
        endedAt: Date? = nil,
        output: String = "",
        status: PluginExecutionStatus = .idle,
        exitCode: Int32? = nil
    ) {
        self.id = id
        self.taskID = taskID
        self.taskTitle = taskTitle
        self.commandDescription = commandDescription
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.output = output
        self.status = status
        self.exitCode = exitCode
    }
}

struct PluginTaskPanelState {
    var tasks: [EditorPluginTask] = []
    var selectedTaskID: String?
    var lastRun: PluginTaskRun?
    var lastCoverageSummary: TestCoverageSummary?
}

enum PluginDiagnosticSeverity: String, Codable, CaseIterable, Identifiable, Hashable {
    case info
    case warning
    case error

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }

    var symbolName: String {
        switch self {
        case .info:
            return "info.circle"
        case .warning:
            return "exclamationmark.triangle"
        case .error:
            return "xmark.octagon"
        }
    }
}

struct PluginDiagnostic: Identifiable, Hashable {
    let id: UUID
    let source: String
    let severity: PluginDiagnosticSeverity
    let message: String
    let lineNumber: Int?
    let detail: String?

    init(
        id: UUID = UUID(),
        source: String,
        severity: PluginDiagnosticSeverity,
        message: String,
        lineNumber: Int? = nil,
        detail: String? = nil
    ) {
        self.id = id
        self.source = source
        self.severity = severity
        self.message = message
        self.lineNumber = lineNumber
        self.detail = detail
    }
}

struct PluginDiagnosticsPanelState {
    var documentID: UUID?
    var diagnostics: [PluginDiagnostic] = []
    var lastRunAt: Date?
    var statusMessage: String?
}

enum PluginStatusTone: String, Codable, Hashable {
    case neutral
    case accent
    case success
    case warning
    case danger
}

struct PluginStatusItem: Identifiable, Hashable {
    let id: String
    let text: String
    let symbolName: String?
    let tone: PluginStatusTone
}

struct GitRepositorySummary: Hashable {
    let rootURL: URL
    let branchName: String
    let stagedCount: Int
    let modifiedCount: Int
    let untrackedCount: Int
    let conflictedCount: Int
}

struct GitRemote: Identifiable, Hashable {
    let id: String
    let name: String
    let fetchURL: String?
    let pushURL: String?
}

struct EditorPlugin: Identifiable, Hashable {
    let manifest: EditorPluginManifest
    let commands: [EditorPluginCommand]
    let snippets: [EditorPluginSnippet]
    let tasks: [EditorPluginTask]

    var id: String { manifest.id }
}
