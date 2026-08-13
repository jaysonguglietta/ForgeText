import Foundation

enum EngineeringWorkbenchSection: String, CaseIterable, Codable, Identifiable {
    case overview
    case intelligence
    case review
    case tests
    case remote
    case investigations
    case data
    case aiChanges
    case enterprise
    case profiles

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview: return "Workspace Health"
        case .intelligence: return "Code Intelligence"
        case .review: return "Review Changes"
        case .tests: return "Tests + Coverage"
        case .remote: return "Remote Workspaces"
        case .investigations: return "Investigations"
        case .data: return "Data Tools"
        case .aiChanges: return "AI Change Sets"
        case .enterprise: return "Enterprise"
        case .profiles: return "Profile Packs"
        }
    }

    var symbolName: String {
        switch self {
        case .overview: return "heart.text.square"
        case .intelligence: return "chevron.left.forwardslash.chevron.right"
        case .review: return "arrow.left.arrow.right.square"
        case .tests: return "checkmark.circle"
        case .remote: return "network"
        case .investigations: return "scope"
        case .data: return "tablecells"
        case .aiChanges: return "wand.and.stars.inverse"
        case .enterprise: return "building.2"
        case .profiles: return "person.crop.rectangle.stack"
        }
    }
}

enum WorkbenchHealthTone: String, Codable, Hashable {
    case healthy
    case attention
    case blocked
    case informational
}

struct WorkspaceHealthFinding: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let detail: String
    let tone: WorkbenchHealthTone
    let systemImage: String
    let section: EngineeringWorkbenchSection
}

struct WorkspaceHealthSnapshot: Codable, Hashable {
    var score = 100
    var findings: [WorkspaceHealthFinding] = []
    var checkedAt = Date()

    var attentionCount: Int {
        findings.filter { $0.tone == .attention }.count
    }

    var blockedCount: Int {
        findings.filter { $0.tone == .blocked }.count
    }
}

enum LanguageServerAvailability: String, Codable, Hashable {
    case ready
    case unavailable
    case disabled
}

struct LanguageServerStatus: Identifiable, Codable, Hashable {
    let id: String
    let displayName: String
    let executable: String
    let languages: [DocumentLanguage]
    let availability: LanguageServerAvailability
    let resolvedPath: String?
    let version: String?
    let capabilities: [String]
}

enum ProtocolSessionState: String, Codable, Hashable {
    case stopped
    case starting
    case running
    case failed
}

struct LanguageProtocolSessionStatus: Identifiable, Codable, Hashable {
    var id: String { serverID }
    let serverID: String
    var state: ProtocolSessionState
    var startedAt: Date?
    var negotiatedCapabilities: [String]
    var lastError: String?
}

struct LanguageTextPosition: Codable, Hashable {
    let line: Int
    let character: Int
}

struct LanguageTextRange: Codable, Hashable {
    let start: LanguageTextPosition
    let end: LanguageTextPosition
}

struct LanguageProtocolDiagnostic: Identifiable, Codable, Hashable {
    let id: String
    let serverID: String
    let documentURI: String
    let range: LanguageTextRange
    let severity: Int
    let message: String
    let source: String?
}

struct LanguageProtocolLocation: Identifiable, Codable, Hashable {
    var id: String { "\(documentURI):\(range.start.line):\(range.start.character)" }
    let documentURI: String
    let range: LanguageTextRange
}

struct LanguageProtocolCompletion: Identifiable, Codable, Hashable {
    let id: String
    let label: String
    let detail: String?
    let insertText: String?
    let kind: Int?
}

struct LanguageProtocolCodeAction: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let kind: String?
    let isPreferred: Bool
    let command: String?
    let edits: [LanguageProtocolTextEdit]
}

struct LanguageProtocolTextEdit: Identifiable, Codable, Hashable {
    var id: String { "\(documentURI):\(range.start.line):\(range.start.character):\(newText.hashValue)" }
    let documentURI: String
    let range: LanguageTextRange
    let newText: String
}

struct DebugAdapterStatus: Identifiable, Codable, Hashable {
    let id: String
    let displayName: String
    let languages: [DocumentLanguage]
    let availability: LanguageServerAvailability
    let resolvedPath: String?
}

struct DebugAdapterProbeResult: Identifiable, Codable, Hashable {
    var id: String { adapterID }
    let adapterID: String
    let supportsConfigurationDoneRequest: Bool
    let supportsFunctionBreakpoints: Bool
    let checkedAt: Date
}

enum LanguageNavigationKind: String, Codable, Hashable {
    case definition
    case reference
}

struct LanguageNavigationHit: Identifiable, Hashable {
    let id: String
    let kind: LanguageNavigationKind
    let symbol: String
    let fileURL: URL
    let relativePath: String
    let lineNumber: Int
    let preview: String
}

enum DiscoveredTestFramework: String, Codable, Hashable {
    case xctest
    case pytest
    case javascript

    var displayName: String {
        switch self {
        case .xctest: return "XCTest"
        case .pytest: return "Pytest"
        case .javascript: return "JavaScript"
        }
    }
}

struct DiscoveredTestCase: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let framework: DiscoveredTestFramework
    let filePath: String
    let relativePath: String
    let lineNumber: Int
}

enum DiscoveredTestStatus: String, Codable, Hashable {
    case notRun
    case running
    case passed
    case failed
}

struct DiscoveredTestResult: Identifiable, Codable, Hashable {
    let id: String
    let testID: String
    let status: DiscoveredTestStatus
    let duration: TimeInterval
    let output: String
    let runAt: Date
}

struct CoverageFileSummary: Identifiable, Codable, Hashable {
    let id: String
    let relativePath: String
    let coveredLines: Int
    let executableLines: Int

    var percentage: Double {
        guard executableLines > 0 else { return 0 }
        return (Double(coveredLines) / Double(executableLines)) * 100
    }
}

enum RemoteSessionConnectionState: String, Codable, Hashable {
    case disconnected
    case connecting
    case connected
    case interrupted
}

struct RemoteWorkspaceSession: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var connection: String
    var rootPath: String
    var executionMode: RemoteExecutionMode
    var isReadOnly: Bool
    var state: RemoteSessionConnectionState
    var lastConnectedAt: Date?
    var lastError: String?

    init(
        id: UUID = UUID(),
        name: String,
        connection: String,
        rootPath: String,
        executionMode: RemoteExecutionMode = .remoteAgent,
        isReadOnly: Bool = true,
        state: RemoteSessionConnectionState = .disconnected,
        lastConnectedAt: Date? = nil,
        lastError: String? = nil
    ) {
        self.id = id
        self.name = name
        self.connection = connection
        self.rootPath = rootPath
        self.executionMode = executionMode
        self.isReadOnly = isReadOnly
        self.state = state
        self.lastConnectedAt = lastConnectedAt
        self.lastError = lastError
    }
}

struct InvestigationSession: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var workspaceRootPaths: [String]
    var openFilePaths: [String]
    var openRemoteSpecs: [String]
    var selectedFilePath: String?
    var projectSearchQuery: String
    var logFilterQuery: String
    var notes: String
    var gitBranch: String?
    var capturedAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        workspaceRootPaths: [String],
        openFilePaths: [String],
        openRemoteSpecs: [String],
        selectedFilePath: String?,
        projectSearchQuery: String,
        logFilterQuery: String,
        notes: String = "",
        gitBranch: String?,
        capturedAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.workspaceRootPaths = workspaceRootPaths
        self.openFilePaths = openFilePaths
        self.openRemoteSpecs = openRemoteSpecs
        self.selectedFilePath = selectedFilePath
        self.projectSearchQuery = projectSearchQuery
        self.logFilterQuery = logFilterQuery
        self.notes = notes
        self.gitBranch = gitBranch
        self.capturedAt = capturedAt
        self.updatedAt = updatedAt
    }
}

enum AIChangeSetStatus: String, Codable, Hashable {
    case proposed
    case approved
    case applied
    case reverted
    case rejected
}

struct AIChangeHunk: Identifiable, Codable, Hashable {
    let id: UUID
    let header: String
    let body: String
    var isApproved: Bool

    init(id: UUID = UUID(), header: String, body: String, isApproved: Bool = false) {
        self.id = id
        self.header = header
        self.body = body
        self.isApproved = isApproved
    }
}

struct AIFileChange: Identifiable, Codable, Hashable {
    let id: UUID
    let oldPath: String
    let newPath: String
    var hunks: [AIChangeHunk]

    init(id: UUID = UUID(), oldPath: String, newPath: String, hunks: [AIChangeHunk]) {
        self.id = id
        self.oldPath = oldPath
        self.newPath = newPath
        self.hunks = hunks
    }
}

struct AIChangeSet: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    let originalPatch: String
    var files: [AIFileChange]
    var status: AIChangeSetStatus
    var createdAt: Date
    var appliedAt: Date?

    init(
        id: UUID = UUID(),
        title: String,
        originalPatch: String,
        files: [AIFileChange],
        status: AIChangeSetStatus = .proposed,
        createdAt: Date = Date(),
        appliedAt: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.originalPatch = originalPatch
        self.files = files
        self.status = status
        self.createdAt = createdAt
        self.appliedAt = appliedAt
    }

    var approvedHunkCount: Int {
        files.flatMap(\.hunks).filter(\.isApproved).count
    }

    var hunkCount: Int {
        files.reduce(0) { $0 + $1.hunks.count }
    }
}

struct EnterpriseFleetCheck: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let detail: String
    let tone: WorkbenchHealthTone
}

struct DevContainerConfiguration: Identifiable, Codable, Hashable {
    var id: String { configurationPath }
    let configurationPath: String
    let workspaceRootPath: String
    let name: String
    let remoteUser: String?
    let featureIdentifiers: [String]
    let declaresLifecycleCommands: Bool
    let cliPath: String?
}

enum DevContainerRunPhase: String, Codable, Hashable {
    case notConfigured
    case ready
    case starting
    case running
    case failed
}

struct DevContainerRunState: Codable, Hashable {
    var phase: DevContainerRunPhase = .notConfigured
    var message = "No development container configuration detected."
    var startedAt: Date?
}

struct PluginGovernanceFinding: Identifiable, Codable, Hashable {
    let id: String
    let pluginName: String
    let detail: String
    let tone: WorkbenchHealthTone
}

struct EffectivePolicyDecision: Identifiable, Codable, Hashable {
    let id: String
    let capability: String
    let isAllowed: Bool
    let source: String
    let reason: String
}

enum EnterpriseOperationalMode: String, CaseIterable, Codable, Identifiable {
    case editing
    case review
    case incident
    case data

    var id: String { rawValue }

    var title: String {
        switch self {
        case .editing: return "Editing"
        case .review: return "Code Review"
        case .incident: return "Incident"
        case .data: return "Data Inspection"
        }
    }

    var systemImage: String {
        switch self {
        case .editing: return "doc.text"
        case .review: return "arrow.left.arrow.right"
        case .incident: return "waveform.path.ecg"
        case .data: return "tablecells"
        }
    }
}

struct GitWorktreeRecord: Identifiable, Hashable {
    let id: String
    let path: String
    let head: String
    let branch: String?
    let isBare: Bool
    let isDetached: Bool
    let isLocked: Bool

    var displayName: String {
        URL(fileURLWithPath: path).lastPathComponent
    }

    var branchLabel: String {
        branch ?? (isDetached ? "Detached HEAD" : "No branch")
    }
}

struct WorkspaceProfilePack: Codable, Hashable {
    var version = 1
    var name: String
    var profile: WorkspaceProfile
    var exportedAt = Date()
}

struct EngineeringWorkbenchStoredState: Codable {
    var remoteSessions: [RemoteWorkspaceSession] = []
    var investigations: [InvestigationSession] = []
    var aiChangeSets: [AIChangeSet] = []
    var testResults: [DiscoveredTestResult] = []
}

struct EngineeringWorkbenchState {
    var selectedSection: EngineeringWorkbenchSection = .overview
    var health = WorkspaceHealthSnapshot()
    var languageServers: [LanguageServerStatus] = []
    var languageSessions: [LanguageProtocolSessionStatus] = []
    var languageDiagnostics: [LanguageProtocolDiagnostic] = []
    var languageCompletions: [LanguageProtocolCompletion] = []
    var languageLocations: [LanguageProtocolLocation] = []
    var languageCodeActions: [LanguageProtocolCodeAction] = []
    var languageRenameDraft = ""
    var languageRenameEdits: [LanguageProtocolTextEdit] = []
    var debugAdapters: [DebugAdapterStatus] = []
    var debugAdapterProbes: [DebugAdapterProbeResult] = []
    var navigationSymbol = ""
    var navigationHits: [LanguageNavigationHit] = []
    var selectedReviewFileID: String?
    var gitReviewChangeSet: AIChangeSet?
    var gitFileHistory: [GitGraphEntry] = []
    var gitWorktrees: [GitWorktreeRecord] = []
    var discoveredTests: [DiscoveredTestCase] = []
    var testResults: [DiscoveredTestResult] = []
    var coverageFiles: [CoverageFileSummary] = []
    var remoteSessions: [RemoteWorkspaceSession] = []
    var investigations: [InvestigationSession] = []
    var investigationDraftName = ""
    var aiChangeSets: [AIChangeSet] = []
    var enterpriseChecks: [EnterpriseFleetCheck] = []
    var effectivePolicyDecisions: [EffectivePolicyDecision] = []
    var pluginGovernanceFindings: [PluginGovernanceFinding] = []
    var devContainerConfiguration: DevContainerConfiguration?
    var devContainerRunState = DevContainerRunState()
    var operationalMode: EnterpriseOperationalMode = .editing
    var profilePackDraftName = ""
    var isRefreshing = false
    var statusMessage: String?
}
