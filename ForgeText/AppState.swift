import AppKit
import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    enum PendingAction {
        case close(UUID)
        case revert(UUID)
    }

    struct AlertContext: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    enum PaletteAction {
        case newDocument
        case openDocuments
        case openWorkspaceFile
        case saveWorkspaceFile
        case showWorkspacePlatform
        case cloneRepository
        case openRemote
        case openRemoteSpec(String)
        case showGitWorkbench
        case showProblemsPanel
        case showTestExplorer
        case showAIWorkbench
        case runAIQuickAction(AIQuickAction)
        case showPluginManager
        case showSnippetLibrary
        case showTaskRunner
        case showTerminalConsole
        case searchInFolder
        case saveDocument
        case savePrivileged
        case closeDocument
        case showFind
        case goToLine
        case nextMatch
        case previousMatch
        case toggleComment
        case showStructuredView
        case showRawText
        case compareWithSaved
        case compareWithFile
        case toggleFollowMode
        case openInTerminal
        case prettyPrintJSON
        case minifyJSON
        case formatDocument
        case runPluginDiagnostics
        case compareWithGitHead
        case refreshGitStatus
        case stageCurrentFileInGit
        case switchGitBranch(String)
        case refreshWorkspaceExplorer
        case runPrimaryWorkspaceTask(PluginTaskRole)
        case runWorkspaceTask(String)
        case runCoverageTask
        case insertSnippet(String)
        case exportSettings
        case importSettings
        case exportSyncBundle
        case importSyncBundle
        case trustWorkspace
        case restrictWorkspace
        case toggleWrapLines
        case toggleOutline
        case toggleInspector
        case toggleBreadcrumbs
        case toggleFocusMode
        case showAppearancePreferences
        case setChromeStyle(AppChromeStyle)
        case setInterfaceDensity(InterfaceDensity)
        case setSplitMode(WorkspaceSecondaryPaneMode)
        case saveWorkspaceSession
        case showWorkspaceSessions
        case increaseFontSize
        case decreaseFontSize
        case setEncoding(String.Encoding)
        case setLineEnding(LineEnding)
        case toggleByteOrderMark
        case setTheme(EditorTheme)
        case setLanguage(DocumentLanguage)
        case switchDocument(UUID)
        case openRecent(URL)
    }

    struct PaletteItem: Identifiable {
        let id: String
        let title: String
        let subtitle: String
        let symbolName: String
        let action: PaletteAction
    }

    @Published var documents: [EditorDocument] = []
    @Published var selectedDocumentID: UUID?
    @Published var recentFiles: [URL] = []
    @Published var recentRemoteLocations: [RemoteFileReference] = []
    @Published var workspaceSessions: [WorkspaceSessionRecord] = []
    @Published var settings: AppSettings
    @Published var alertContext: AlertContext?
    @Published var showingDiscardChanges = false
    @Published var showingCommandPalette = false
    @Published var showingGoToLine = false
    @Published var showingCloneRepository = false
    @Published var showingRemoteOpen = false
    @Published var showingGitWorkbench = false
    @Published var showingProblemsPanel = false
    @Published var showingTestExplorer = false
    @Published var showingAIWorkbench = false
    @Published var showingWorkspacePlatform = false
    @Published var showingWorkspaceSessions = false
    @Published var showingAppearancePreferences = false
    @Published var showingKeyboardShortcuts = false
    @Published var showingPluginManager = false
    @Published var showingSnippetLibrary = false
    @Published var showingTaskRunner = false
    @Published var showingPluginDiagnostics = false
    @Published var showingTerminalConsole = false
    @Published var editorFocusToken = UUID()
    @Published var projectSearchState = ProjectSearchState()
    @Published var comparisonState: DocumentComparisonState?
    @Published var remoteLocationDraft = ""
    @Published var cloneRepositoryState = CloneRepositoryState(destinationParentPath: GitCloneService.defaultDestinationParentURL().path)
    @Published var secondaryPaneMode: WorkspaceSecondaryPaneMode = .off
    @Published var secondaryDocumentID: UUID?
    @Published var pluginTaskState = PluginTaskPanelState()
    @Published var pluginDiagnosticsState = PluginDiagnosticsPanelState()
    @Published var gitPanelState = GitPanelState()
    @Published var problemsPanelState = ProblemsPanelState()
    @Published var testExplorerState = TestExplorerState()
    @Published var aiWorkbenchState = AIWorkbenchState()
    @Published var gitRepositorySummary: GitRepositorySummary?
    @Published var availableGitBranches: [String] = []
    @Published var workspaceExplorerState = WorkspaceExplorerState()
    @Published var terminalPanelState = EmbeddedTerminalPanelState()
    @Published var remoteWorkspaceState = RemoteWorkspaceState()
    @Published var workspacePlatformState = WorkspacePlatformState()
    @Published private var pluginCatalog: [EditorPlugin] = PluginHostService.builtInPlugins
    @Published private var documentDiagnosticsByID: [UUID: [PluginDiagnostic]] = [:]
    @Published private var gitLineDecorationsByDocumentID: [UUID: [EditorLineDecoration]] = [:]
    @Published private var gitBlameCache: [String: GitBlameInfo] = [:]

    private var pendingAction: PendingAction?
    private var autosaveTask: Task<Void, Never>?
    private var sessionSaveTask: Task<Void, Never>?
    private var projectSearchTask: Task<Void, Never>?
    private var gitRefreshTask: Task<Void, Never>?
    private var gitLineDecorationTasks: [UUID: Task<Void, Never>] = [:]
    private var gitBlameTasks: [String: Task<Void, Never>] = [:]
    private var pluginRegistryRefreshTask: Task<Void, Never>?
    private var fileMonitorTimer: Timer?
    private var untitledCounter = 1
    private let hadUncleanShutdown: Bool
    private var gitRefreshGeneration = 0
    private var processedLaunchArguments = false

    init() {
        var loadedSettings = AppSettingsStore.load()
        if loadedSettings.enabledPluginIDs.isEmpty {
            loadedSettings.enabledPluginIDs = PluginHostService.defaultEnabledPluginIDs
        }
        if loadedSettings.preferredAIProviderID == nil {
            loadedSettings.preferredAIProviderID = loadedSettings.aiProviders.first(where: \.isEnabled)?.id
        }

        let loadedAISessions = AIConversationStore.load()
        hadUncleanShutdown = CrashRecoveryMonitor.markLaunch()
        settings = loadedSettings
        workspaceSessions = WorkspaceSessionStore.load()
        aiWorkbenchState = AIWorkbenchState(
            sessions: loadedAISessions,
            selectedSessionID: loadedAISessions.first?.id
        )
        restoreWorkspace()
        startFileMonitoring()
        refreshPluginWorkspaceState()
        refreshWorkspacePlatformState()
        refreshPluginRegistry()

        if hadUncleanShutdown, documents.contains(where: \.hasRecoveredDraft) {
            alertContext = AlertContext(
                title: "Recovered After Unexpected Shutdown",
                message: "ForgeText restored recovery snapshots after it detected the previous run did not exit cleanly."
            )
        }
    }

    var selectedDocument: EditorDocument? {
        guard let selectedDocumentIndex else {
            return nil
        }

        return documents[selectedDocumentIndex]
    }

    var selectedDocumentIndex: Int? {
        guard let selectedDocumentID else {
            return nil
        }

        return documents.firstIndex { $0.id == selectedDocumentID }
    }

    var selectedMetrics: EditorMetrics? {
        guard let selectedDocument else {
            return nil
        }

        return EditorMetrics(text: selectedDocument.text, selectedRange: selectedDocument.selectedRange)
    }

    var canSave: Bool {
        guard let selectedDocument else {
            return false
        }

        return !selectedDocument.isReadOnly
    }

    var canCloseSelectedDocument: Bool {
        selectedDocument != nil
    }

    var canCompareSelectedDocument: Bool {
        guard let selectedDocument else {
            return false
        }

        return selectedDocument.fileURL != nil || !selectedDocument.lastSavedText.isEmpty
    }

    var canFollowSelectedDocument: Bool {
        selectedDocument?.fileURL != nil
    }

    var canShowStructuredPresentation: Bool {
        selectedDocument?.availableStructuredPresentationMode != nil
    }

    var canPrivilegedSaveSelectedDocument: Bool {
        guard let selectedDocument, let fileURL = selectedDocument.fileURL else {
            return false
        }

        return !selectedDocument.isReadOnly && !selectedDocument.isRemote && PrivilegedFileService.likelyNeedsPrivilege(for: fileURL)
    }

    var selectedSecondaryDocument: EditorDocument? {
        guard let secondaryDocumentID else {
            return nil
        }

        return documents.first { $0.id == secondaryDocumentID }
    }

    var installedPlugins: [EditorPlugin] {
        pluginCatalog
    }

    var enabledPlugins: [EditorPlugin] {
        PluginHostService.enabledPlugins(
            using: settings,
            workspaceRoots: workspaceRootURLs,
            trustMode: workspaceTrustMode
        )
    }

    var selectedPluginTask: EditorPluginTask? {
        guard let selectedTaskID = pluginTaskState.selectedTaskID else {
            return pluginTaskState.tasks.first
        }

        return pluginTaskState.tasks.first(where: { $0.id == selectedTaskID }) ?? pluginTaskState.tasks.first
    }

    var availableTestTasks: [EditorPluginTask] {
        pluginTaskState.tasks.filter { $0.role == .test }
    }

    var selectedAIProvider: AIProviderConfiguration? {
        if let preferredID = settings.preferredAIProviderID,
           let provider = settings.aiProviders.first(where: { $0.id == preferredID && $0.isEnabled }) {
            return provider
        }

        return settings.aiProviders.first(where: \.isEnabled)
    }

    var selectedAISession: AIChatSession? {
        guard let selectedSessionID = aiWorkbenchState.selectedSessionID else {
            return aiWorkbenchState.sessions.first
        }

        return aiWorkbenchState.sessions.first(where: { $0.id == selectedSessionID }) ?? aiWorkbenchState.sessions.first
    }

    var workspaceRootURLs: [URL] {
        let explicitRoots = workspacePlatformState.rootPaths.map { URL(fileURLWithPath: $0, isDirectory: true) }
        if !explicitRoots.isEmpty {
            return WorkspacePlatformService.normalizedRootURLs(from: explicitRoots)
        }

        if let rootURL = projectSearchState.rootURL?.standardizedFileURL {
            return [rootURL]
        }

        if let documentRoot = selectedDocument?.fileURL?.deletingLastPathComponent() {
            return [documentRoot]
        }

        return []
    }

    var activeWorkspaceURL: URL? {
        if let activeRootPath = workspacePlatformState.activeRootPath {
            return URL(fileURLWithPath: activeRootPath, isDirectory: true).standardizedFileURL
        }

        return workspaceRootURLs.first
    }

    var workspaceTrustMode: WorkspaceTrustMode {
        WorkspacePlatformService.trustMode(for: workspaceRootURLs, settings: settings)
    }

    var availableWorkspaceProfiles: [WorkspaceProfile] {
        settings.profiles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var availableRegistryPlugins: [PluginRegistryEntry] {
        workspacePlatformState.registryEntries
    }

    var isPortableModeEnabled: Bool {
        StoragePathService.isPortableModeEnabled
    }

    func inlineDiagnostics(for document: EditorDocument) -> [PluginDiagnostic] {
        documentDiagnosticsByID[document.id] ?? []
    }

    func inlineDiagnostics(for document: EditorDocument, lineNumber: Int) -> [PluginDiagnostic] {
        inlineDiagnostics(for: document).filter { $0.lineNumber == lineNumber }
    }

    func lineDecorations(for document: EditorDocument) -> [EditorLineDecoration] {
        var decorations = document.isDirty ? [] : (gitLineDecorationsByDocumentID[document.id] ?? [])

        let diagnosticDecorations = inlineDiagnostics(for: document).compactMap { diagnostic -> EditorLineDecoration? in
            guard let lineNumber = diagnostic.lineNumber else {
                return nil
            }

            let kind: EditorLineDecorationKind
            switch diagnostic.severity {
            case .info:
                kind = .diagnosticInfo
            case .warning:
                kind = .diagnosticWarning
            case .error:
                kind = .diagnosticError
            }

            return EditorLineDecoration(lineNumber: lineNumber, kind: kind, message: diagnostic.message)
        }

        decorations.append(contentsOf: diagnosticDecorations)
        return decorations.sorted { lhs, rhs in
            if lhs.lineNumber == rhs.lineNumber {
                return lhs.kind.rawValue < rhs.kind.rawValue
            }

            return lhs.lineNumber < rhs.lineNumber
        }
    }

    func gitBlame(for document: EditorDocument, lineNumber: Int) -> GitBlameInfo? {
        guard !document.isDirty, document.fileURL != nil else {
            return nil
        }

        let cacheKey = gitBlameCacheKey(for: document.id, lineNumber: lineNumber)
        return gitBlameCache[cacheKey]
    }

    func prefetchLineDecorations(for document: EditorDocument) {
        guard !document.isDirty, let fileURL = document.fileURL else {
            cancelGitLineDecorationRefresh(for: document.id, clearCache: document.fileURL == nil)
            return
        }

        guard gitLineDecorationTasks[document.id] == nil else {
            return
        }

        let documentID = document.id
        let workspaceURL = activeWorkspaceURL
        gitLineDecorationTasks[documentID] = Task.detached(priority: .utility) { [fileURL, weak self] in
            let decorations = GitService.lineDecorations(for: fileURL, workspaceRoot: workspaceURL)
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard let self else { return }
                self.gitLineDecorationTasks[documentID] = nil
                self.gitLineDecorationsByDocumentID[documentID] = decorations
            }
        }
    }

    func prefetchGitBlame(for document: EditorDocument, lineNumber: Int) {
        guard lineNumber > 0, !document.isDirty, let fileURL = document.fileURL else {
            return
        }

        let cacheKey = gitBlameCacheKey(for: document.id, lineNumber: lineNumber)
        guard gitBlameCache[cacheKey] == nil, gitBlameTasks[cacheKey] == nil else {
            return
        }

        let workspaceURL = activeWorkspaceURL
        gitBlameTasks[cacheKey] = Task.detached(priority: .utility) { [fileURL, weak self] in
            let blame = GitService.blame(for: fileURL, lineNumber: lineNumber, workspaceRoot: workspaceURL)
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard let self else { return }
                self.gitBlameTasks[cacheKey] = nil
                if let blame {
                    self.gitBlameCache[cacheKey] = blame
                }
            }
        }
    }

    func newDocument() {
        let document = EditorDocument.untitled(named: nextUntitledName())
        documents.append(document)
        selectedDocumentID = document.id
        requestEditorFocus()
        scheduleSessionSave()
        refreshPluginWorkspaceState()
        refreshDocumentDiagnostics(for: document.id)
    }

    func openDocument() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        panel.begin { [weak self] response in
            guard response == .OK else {
                return
            }

            self?.openDocuments(at: panel.urls)
        }
    }

    func showCloneRepositoryPanel() {
        let suggestedParent = projectSearchState.rootURL?.deletingLastPathComponent()
            ?? activeWorkspaceURL
            ?? GitCloneService.defaultDestinationParentURL()
        if cloneRepositoryState.destinationParentPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cloneRepositoryState.destinationParentPath = suggestedParent.path
        }

        if cloneRepositoryState.directoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            cloneRepositoryState.directoryName = GitCloneService.suggestedDirectoryName(for: cloneRepositoryState.repositorySpecifier) ?? ""
        }

        cloneRepositoryState.statusMessage = nil
        showingCloneRepository = true
    }

    func chooseCloneDestinationParent() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        let currentPath = cloneRepositoryState.destinationParentPath.trimmingCharacters(in: .whitespacesAndNewlines)
        if !currentPath.isEmpty {
            panel.directoryURL = URL(fileURLWithPath: currentPath, isDirectory: true)
        }

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url?.standardizedFileURL else {
                return
            }

            Task { @MainActor in
                self?.cloneRepositoryState.destinationParentPath = url.path
            }
        }
    }

    func cloneRepository() {
        let repositorySpecifier = cloneRepositoryState.repositorySpecifier.trimmingCharacters(in: .whitespacesAndNewlines)
        let destinationParentPath = cloneRepositoryState.destinationParentPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let directoryName = cloneRepositoryState.directoryName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !repositorySpecifier.isEmpty else {
            alertContext = AlertContext(title: "Repository URL Needed", message: "Paste a GitHub HTTPS or SSH repository URL before cloning.")
            return
        }

        guard !destinationParentPath.isEmpty else {
            alertContext = AlertContext(title: "Destination Folder Needed", message: "Choose a local parent folder for the cloned repository.")
            return
        }

        guard !directoryName.isEmpty else {
            alertContext = AlertContext(title: "Repository Name Needed", message: "Enter the local folder name ForgeText should use for the clone.")
            return
        }

        cloneRepositoryState.isCloning = true
        cloneRepositoryState.statusMessage = "Cloning \(repositorySpecifier)..."

        let parentURL = URL(fileURLWithPath: destinationParentPath, isDirectory: true)
        let branchName = cloneRepositoryState.branchName
        let usesShallowClone = cloneRepositoryState.usesShallowClone

        Task.detached(priority: .userInitiated) {
            do {
                let clonedRepositoryURL = try GitCloneService.cloneRepository(
                    repositorySpecifier: repositorySpecifier,
                    destinationParentURL: parentURL,
                    directoryName: directoryName,
                    branchName: branchName,
                    usesShallowClone: usesShallowClone
                )

                await MainActor.run {
                    self.cloneRepositoryState.isCloning = false
                    self.cloneRepositoryState.statusMessage = "Cloned \(clonedRepositoryURL.lastPathComponent)"
                    self.showingCloneRepository = false
                    self.activateWorkspace(
                        at: clonedRepositoryURL,
                        statusMessage: "Loaded repository \(clonedRepositoryURL.lastPathComponent)",
                        openPreferredFile: true
                    )
                }
            } catch {
                await MainActor.run {
                    self.cloneRepositoryState.isCloning = false
                    self.cloneRepositoryState.statusMessage = error.localizedDescription
                    self.present(error: error, title: "Couldn’t Clone Repository")
                }
            }
        }
    }

    func openRemotePanel() {
        remoteLocationDraft = selectedDocument?.remoteReference?.spec ?? recentRemoteLocations.first?.spec ?? ""
        if remoteWorkspaceState.searchRootPath.isEmpty {
            let selectedRemoteDirectory = selectedDocument?.remoteReference.flatMap { reference in
                URL(fileURLWithPath: reference.path).deletingLastPathComponent().path
            }
            let draftedRemoteDirectory = RemoteFileReference.parse(remoteLocationDraft).map { reference in
                URL(fileURLWithPath: reference.path).deletingLastPathComponent().path
            }
            remoteWorkspaceState.searchRootPath = selectedRemoteDirectory ?? draftedRemoteDirectory ?? "/"
        }
        checkRemoteAgent()
        showingRemoteOpen = true
    }

    func openRemoteDocument() {
        openRemoteDocument(spec: remoteLocationDraft)
    }

    func openRemoteDocument(spec: String) {
        let spec = spec.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !spec.isEmpty else {
            alertContext = AlertContext(title: "Remote Location Needed", message: "Enter a remote path like user@host:/absolute/path/to/file.")
            return
        }

        showingRemoteOpen = false
        let executionMode = remoteWorkspaceState.executionMode

        Task.detached(priority: .userInitiated) {
            do {
                let document = try RemoteFileService.open(spec: spec, mode: executionMode)
                await MainActor.run {
                    self.documents.append(document)
                    self.selectedDocumentID = document.id
                    self.recordRecentRemote(document.remoteReference)
                    self.requestEditorFocus()
                    self.scheduleSessionSave()
                    self.refreshPluginWorkspaceState()
                    self.refreshDocumentDiagnostics(for: document.id)
                }
            } catch {
                await MainActor.run {
                    self.present(error: error, title: "Couldn’t Open Remote File")
                }
            }
        }
    }

    func openDocuments(at urls: [URL]) {
        var selectedID: UUID?

        for url in urls {
            let standardizedURL = url.standardizedFileURL

            if standardizedURL.pathExtension == WorkspacePlatformService.workspaceFileExtension {
                loadWorkspaceFile(at: standardizedURL)
                continue
            }

            if let existing = documents.first(where: { $0.fileURL?.standardizedFileURL == standardizedURL }) {
                selectedID = existing.id
                recordRecentFile(standardizedURL)
                continue
            }

            do {
                let file = try TextFileCodec.open(from: standardizedURL)
                let document = EditorDocument.loaded(file: file, url: standardizedURL)
                documents.append(document)
                recordRecentFile(standardizedURL)
                selectedID = document.id
                refreshDocumentDiagnostics(for: document.id)
            } catch {
                present(error: error, title: "Couldn’t Open File")
            }
        }

        if let selectedID {
            self.selectedDocumentID = selectedID
            requestEditorFocus()
        } else if documents.isEmpty {
            newDocument()
        }

        scheduleSessionSave()
        refreshPluginWorkspaceState()
    }

    func selectDocument(_ id: UUID) {
        selectedDocumentID = id
        requestEditorFocus()
        scheduleSessionSave()
        refreshPluginWorkspaceState()
    }

    func selectNextDocument() {
        guard !documents.isEmpty, let selectedDocumentIndex else {
            return
        }

        let nextIndex = (selectedDocumentIndex + 1) % documents.count
        selectedDocumentID = documents[nextIndex].id
        requestEditorFocus()
        scheduleSessionSave()
        refreshPluginWorkspaceState()
    }

    func selectPreviousDocument() {
        guard !documents.isEmpty, let selectedDocumentIndex else {
            return
        }

        let previousIndex = (selectedDocumentIndex - 1 + documents.count) % documents.count
        selectedDocumentID = documents[previousIndex].id
        requestEditorFocus()
        scheduleSessionSave()
        refreshPluginWorkspaceState()
    }

    func closeSelectedDocument() {
        guard let selectedDocumentID else {
            return
        }

        closeDocument(id: selectedDocumentID)
    }

    func closeDocument(id: UUID) {
        guard let document = document(withID: id) else {
            return
        }

        if document.isDirty {
            pendingAction = .close(id)
            showingDiscardChanges = true
            return
        }

        finalizeClose(id: id)
    }

    func saveDocument() {
        guard let selectedDocument else {
            return
        }

        guard !selectedDocument.isReadOnly else {
            alertContext = AlertContext(title: "Read-Only Preview", message: "This preview can’t be saved back to disk. Open the original file normally or use Save As on a new editable document.")
            return
        }

        if selectedDocument.isRemote {
            saveRemoteDocument(id: selectedDocument.id)
        } else if let fileURL = selectedDocument.fileURL {
            saveDocument(id: selectedDocument.id, to: fileURL, initiatedByAutosave: false)
        } else {
            saveDocumentAs()
        }
    }

    func saveDocumentPrivileged() {
        guard let selectedDocument, let fileURL = selectedDocument.fileURL else {
            return
        }

        guard !selectedDocument.isReadOnly else {
            alertContext = AlertContext(title: "Read-Only Preview", message: "This preview can’t be saved back to disk.")
            return
        }

        do {
            var data = try TextFileCodec.encodedData(for: selectedDocument)
            if fileURL.pathExtension.lowercased() == "gz" {
                data = try CompressedFileService.compressGzip(data)
            }

            try PrivilegedFileService.write(data: data, to: fileURL)

            updateDocument(id: selectedDocument.id) { updatedDocument in
                updatedDocument.lastSavedText = updatedDocument.text
                updatedDocument.isDirty = false
                updatedDocument.hasExternalChanges = false
                updatedDocument.fileMissingOnDisk = false
                updatedDocument.hasRecoveredDraft = false
                updatedDocument.lastKnownDiskFingerprint = DiskFingerprint.capture(for: fileURL)
                updatedDocument.lastSavedAt = Date()
                updatedDocument.statusMessage = "Saved with administrator privileges"
            }

            RecoveryService.deleteSnapshot(for: selectedDocument.id)
            recordRecentFile(fileURL)
        } catch {
            present(error: error, title: "Couldn’t Complete Privileged Save")
        }
    }

    func saveDocumentAs() {
        guard let selectedDocument else {
            return
        }

        guard !selectedDocument.isReadOnly else {
            alertContext = AlertContext(title: "Read-Only Preview", message: "This preview can’t be saved as an editable overwrite target.")
            return
        }

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.canSelectHiddenExtension = true
        panel.isExtensionHidden = false
        panel.nameFieldStringValue = selectedDocument.fileURL?.lastPathComponent ?? selectedDocument.remoteReference?.displayName ?? "\(selectedDocument.displayName).txt"

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else {
                return
            }

            self?.saveDocument(id: selectedDocument.id, to: url.standardizedFileURL, initiatedByAutosave: false)
        }
    }

    func setSecondaryPaneMode(_ mode: WorkspaceSecondaryPaneMode) {
        secondaryPaneMode = mode
        if mode == .off {
            secondaryDocumentID = nil
        } else if mode == .secondDocument, secondaryDocumentID == nil {
            secondaryDocumentID = documents.first(where: { $0.id != selectedDocumentID })?.id
        }
    }

    func setSecondaryDocument(_ id: UUID?) {
        secondaryDocumentID = id
        if id != nil {
            secondaryPaneMode = .secondDocument
        }
    }

    func toggleOutlinePanel() {
        settings.showsOutline.toggle()
        AppSettingsStore.save(settings)
    }

    func toggleInspectorPanel() {
        settings.showsInspector.toggle()
        AppSettingsStore.save(settings)
    }

    func toggleBreadcrumbs() {
        settings.showsBreadcrumbs.toggle()
        AppSettingsStore.save(settings)
    }

    func toggleFocusMode() {
        settings.focusModeEnabled.toggle()
        if settings.focusModeEnabled {
            settings.showsInspector = false
        }
        AppSettingsStore.save(settings)
    }

    func setChromeStyle(_ style: AppChromeStyle) {
        settings.chromeStyle = style
        AppSettingsStore.save(settings)
    }

    func setInterfaceDensity(_ density: InterfaceDensity) {
        settings.interfaceDensity = density
        AppSettingsStore.save(settings)
    }

    func showAppearancePreferences() {
        showingAppearancePreferences = true
    }

    func showWorkspacePlatformPanel() {
        refreshWorkspacePlatformState()
        refreshPluginRegistry()
        showingWorkspacePlatform = true
    }

    func addWorkspaceRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url?.standardizedFileURL else {
                return
            }

            Task { @MainActor in
                guard let self else { return }
                var roots = self.workspaceRootURLs
                roots.append(url)
                self.setWorkspaceRoots(
                    roots,
                    activeRoot: self.activeWorkspaceURL ?? url,
                    workspaceFileURL: self.workspacePlatformState.workspaceFilePath.map { URL(fileURLWithPath: $0) },
                    workspaceName: self.workspacePlatformState.workspaceName,
                    selectedProfileID: self.workspacePlatformState.selectedProfileID
                )
                self.workspacePlatformState.lastStatusMessage = "Added workspace root \(url.lastPathComponent)"
                self.refreshPluginWorkspaceState()
            }
        }
    }

    func removeWorkspaceRoot(path: String) {
        let remainingRoots = workspaceRootURLs.filter { $0.path != path }
        let nextActiveRoot = remainingRoots.first
        setWorkspaceRoots(
            remainingRoots,
            activeRoot: nextActiveRoot,
            workspaceFileURL: workspacePlatformState.workspaceFilePath.map { URL(fileURLWithPath: $0) },
            workspaceName: workspacePlatformState.workspaceName,
            selectedProfileID: workspacePlatformState.selectedProfileID
        )
        workspacePlatformState.lastStatusMessage = remainingRoots.isEmpty ? "Workspace roots cleared" : "Removed workspace root"
        refreshPluginWorkspaceState()
    }

    func setActiveWorkspaceRoot(path: String) {
        guard let root = workspaceRootURLs.first(where: { $0.path == path }) else {
            return
        }

        setWorkspaceRoots(
            workspaceRootURLs,
            activeRoot: root,
            workspaceFileURL: workspacePlatformState.workspaceFilePath.map { URL(fileURLWithPath: $0) },
            workspaceName: workspacePlatformState.workspaceName,
            selectedProfileID: workspacePlatformState.selectedProfileID
        )
        workspacePlatformState.lastStatusMessage = "Active root set to \(root.lastPathComponent)"
        refreshPluginWorkspaceState()
    }

    func saveWorkspaceFile() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(workspacePlatformState.workspaceName).\(WorkspacePlatformService.workspaceFileExtension)"

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url?.standardizedFileURL else {
                return
            }

            Task { @MainActor in
                self?.saveWorkspaceFile(to: url)
            }
        }
    }

    func openWorkspaceFilePanel() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url?.standardizedFileURL else {
                return
            }

            Task { @MainActor in
                self?.loadWorkspaceFile(at: url)
            }
        }
    }

    func trustCurrentWorkspace() {
        WorkspacePlatformService.markTrusted(roots: workspaceRootURLs, settings: &settings)
        AppSettingsStore.save(settings)
        workspacePlatformState.lastStatusMessage = "Workspace marked trusted"
        refreshPluginWorkspaceState()
    }

    func restrictCurrentWorkspace() {
        WorkspacePlatformService.markRestricted(roots: workspaceRootURLs, settings: &settings)
        AppSettingsStore.save(settings)
        workspacePlatformState.lastStatusMessage = "Workspace moved to restricted mode"
        refreshPluginWorkspaceState()
    }

    func saveCurrentWorkspaceProfile(named name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            alertContext = AlertContext(title: "Profile Name Needed", message: "Give the profile a short name before saving it.")
            return
        }

        var profiles = settings.profiles
        if let index = profiles.firstIndex(where: { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }) {
            profiles[index].snapshot = settings.profileSnapshot
            profiles[index].updatedAt = Date()
            workspacePlatformState.selectedProfileID = profiles[index].id
        } else {
            let profile = WorkspaceProfile(name: trimmedName, snapshot: settings.profileSnapshot)
            profiles.append(profile)
            workspacePlatformState.selectedProfileID = profile.id
        }

        settings.profiles = profiles.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        AppSettingsStore.save(settings)
        workspacePlatformState.profileDraftName = ""
        workspacePlatformState.lastStatusMessage = "Saved profile \(trimmedName)"
    }

    func applyWorkspaceProfile(_ profile: WorkspaceProfile) {
        settings.apply(profileSnapshot: profile.snapshot)
        workspacePlatformState.selectedProfileID = profile.id
        AppSettingsStore.save(settings)
        refreshPluginWorkspaceState()
        workspacePlatformState.lastStatusMessage = "Applied profile \(profile.name)"
    }

    func deleteWorkspaceProfile(_ profile: WorkspaceProfile) {
        settings.profiles.removeAll { $0.id == profile.id }
        if workspacePlatformState.selectedProfileID == profile.id {
            workspacePlatformState.selectedProfileID = nil
        }
        AppSettingsStore.save(settings)
        workspacePlatformState.lastStatusMessage = "Deleted profile \(profile.name)"
    }

    func refreshPluginRegistry() {
        workspacePlatformState.isRefreshingRegistry = true
        pluginRegistryRefreshTask?.cancel()
        let settingsSnapshot = settings

        pluginRegistryRefreshTask = Task.detached(priority: .utility) { [weak self] in
            let entries = await PluginRegistryService.catalog(using: settingsSnapshot)
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard let self else { return }
                self.workspacePlatformState.registryEntries = entries
                self.workspacePlatformState.lastRegistryRefreshAt = Date()
                self.workspacePlatformState.isRefreshingRegistry = false
                self.pluginRegistryRefreshTask = nil
            }
        }
    }

    func addPluginRegistry(named name: String, source: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedName.isEmpty, !trimmedSource.isEmpty else {
            alertContext = AlertContext(
                title: "Registry Details Needed",
                message: "Add both a registry name and a JSON source URL or file path."
            )
            return
        }

        if settings.pluginRegistries.contains(where: { $0.source.caseInsensitiveCompare(trimmedSource) == .orderedSame }) {
            alertContext = AlertContext(
                title: "Registry Already Added",
                message: "That registry source is already configured."
            )
            return
        }

        settings.pluginRegistries.append(
            PluginRegistryConfiguration(name: trimmedName, source: trimmedSource, isEnabled: true)
        )
        settings.pluginRegistries.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        AppSettingsStore.save(settings)
        workspacePlatformState.registryDraftName = ""
        workspacePlatformState.registryDraftSource = ""
        refreshPluginRegistry()
        workspacePlatformState.lastStatusMessage = "Added plugin registry \(trimmedName)"
    }

    func setPluginRegistryEnabled(_ registry: PluginRegistryConfiguration, isEnabled: Bool) {
        guard let index = settings.pluginRegistries.firstIndex(where: { $0.id == registry.id }) else {
            return
        }

        settings.pluginRegistries[index].isEnabled = isEnabled
        AppSettingsStore.save(settings)
        refreshPluginRegistry()
        workspacePlatformState.lastStatusMessage = "\(registry.name) registry \(isEnabled ? "enabled" : "disabled")"
    }

    func removePluginRegistry(_ registry: PluginRegistryConfiguration) {
        settings.pluginRegistries.removeAll { $0.id == registry.id }
        AppSettingsStore.save(settings)
        refreshPluginRegistry()
        workspacePlatformState.lastStatusMessage = "Removed plugin registry \(registry.name)"
    }

    func installRegistryPlugin(_ entry: PluginRegistryEntry) {
        do {
            _ = try PluginRegistryService.install(entry)
            if !settings.enabledPluginIDs.contains(entry.id), entry.defaultEnabled {
                settings.enabledPluginIDs.append(entry.id)
            }
            AppSettingsStore.save(settings)
            refreshPluginWorkspaceState()
            workspacePlatformState.lastStatusMessage = "Installed plugin \(entry.name)"
        } catch {
            present(error: error, title: "Couldn’t Install Plugin")
        }
    }

    func uninstallPlugin(_ plugin: EditorPlugin) {
        do {
            try PluginRegistryService.uninstall(plugin: plugin)
            settings.enabledPluginIDs.removeAll { $0 == plugin.id }
            AppSettingsStore.save(settings)
            refreshPluginWorkspaceState()
            workspacePlatformState.lastStatusMessage = "Removed plugin \(plugin.manifest.name)"
        } catch {
            present(error: error, title: "Couldn’t Remove Plugin")
        }
    }

    func exportSyncBundle() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "ForgeTextSync.json"

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url?.standardizedFileURL else {
                return
            }

            Task { @MainActor in
                guard let self else { return }
                do {
                    try WorkspacePlatformService.exportSyncBundle(
                        settings: self.settings,
                        workspaceSessions: self.workspaceSessions,
                        aiSessions: self.aiWorkbenchState.sessions,
                        to: url
                    )
                    self.workspacePlatformState.lastStatusMessage = "Exported sync bundle"
                } catch {
                    self.present(error: error, title: "Couldn’t Export Sync Bundle")
                }
            }
        }
    }

    func importSyncBundle() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url?.standardizedFileURL else {
                return
            }

            Task { @MainActor in
                guard let self else { return }
                do {
                    let bundle = try WorkspacePlatformService.importSyncBundle(from: url)
                    self.settings = bundle.appSettings
                    self.workspaceSessions = bundle.workspaceSessions
                    self.aiWorkbenchState.sessions = bundle.aiSessions.sorted { $0.updatedAt > $1.updatedAt }
                    self.aiWorkbenchState.selectedSessionID = self.aiWorkbenchState.sessions.first?.id
                    AppSettingsStore.save(self.settings)
                    WorkspaceSessionStore.save(self.workspaceSessions)
                    AIConversationStore.save(self.aiWorkbenchState.sessions)
                    self.refreshPluginWorkspaceState()
                    self.refreshPluginRegistry()
                    self.workspacePlatformState.lastStatusMessage = "Imported sync bundle"
                } catch {
                    self.present(error: error, title: "Couldn’t Import Sync Bundle")
                }
            }
        }
    }

    func showWorkspaceSessionsPanel() {
        showingWorkspaceSessions = true
    }

    func saveCurrentWorkspaceSession(named name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            alertContext = AlertContext(title: "Session Name Needed", message: "Give this workspace session a name before saving it.")
            return
        }

        let session = WorkspaceSessionRecord(
            name: trimmedName,
            openFilePaths: documents.compactMap { $0.fileURL?.path },
            openRemoteSpecs: documents.compactMap { $0.remoteReference?.spec },
            selectedFilePath: selectedDocument?.fileURL?.path,
            selectedRemoteSpec: selectedDocument?.remoteReference?.spec,
            workspaceRootPath: projectSearchState.rootURL?.path,
            workspaceRootPaths: workspaceRootURLs.map(\.path),
            activeWorkspaceRootPath: activeWorkspaceURL?.path,
            workspaceFilePath: workspacePlatformState.workspaceFilePath,
            selectedProfileID: workspacePlatformState.selectedProfileID,
            theme: settings.theme,
            wrapLines: settings.wrapLines,
            fontSize: settings.fontSize
        )

        workspaceSessions.removeAll { $0.name.caseInsensitiveCompare(trimmedName) == .orderedSame }
        workspaceSessions.insert(session, at: 0)
        WorkspaceSessionStore.save(workspaceSessions)
    }

    func deleteWorkspaceSession(_ session: WorkspaceSessionRecord) {
        workspaceSessions.removeAll { $0.id == session.id }
        WorkspaceSessionStore.save(workspaceSessions)
    }

    func loadWorkspaceSession(_ session: WorkspaceSessionRecord) {
        let fileURLs = session.openFilePaths.map(URL.init(fileURLWithPath:))
        documents = []
        selectedDocumentID = nil
        recentFiles = Array(Set(recentFiles + fileURLs)).prefix(20).map { $0 }
        recentRemoteLocations = Array(Set(recentRemoteLocations + session.openRemoteSpecs.compactMap(RemoteFileReference.parse))).prefix(20).map { $0 }
        let sessionRoots = (session.workspaceRootPaths.isEmpty ? session.workspaceRootPath.map { [$0] } ?? [] : session.workspaceRootPaths)
            .map { URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL }
        let activeRoot = (session.activeWorkspaceRootPath ?? session.workspaceRootPath).map { URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL }
        setWorkspaceRoots(
            sessionRoots,
            activeRoot: activeRoot,
            workspaceFileURL: session.workspaceFilePath.map(URL.init(fileURLWithPath:)),
            workspaceName: session.name,
            selectedProfileID: session.selectedProfileID
        )
        settings.theme = session.theme
        settings.wrapLines = session.wrapLines
        settings.fontSize = session.fontSize
        if let profileID = session.selectedProfileID,
           let profile = settings.profiles.first(where: { $0.id == profileID }) {
            applyWorkspaceProfile(profile)
        }

        openDocuments(at: fileURLs)

        for spec in session.openRemoteSpecs {
            openRestoredRemoteDocument(spec)
        }

        if let selectedFilePath = session.selectedFilePath,
           let selectedDocument = documents.first(where: { $0.fileURL?.path == selectedFilePath }) {
            selectedDocumentID = selectedDocument.id
        } else if let selectedRemoteSpec = session.selectedRemoteSpec,
                  let selectedDocument = documents.first(where: { $0.remoteReference?.spec == selectedRemoteSpec }) {
            selectedDocumentID = selectedDocument.id
        }

        AppSettingsStore.save(settings)
        scheduleSessionSave()
        showingWorkspaceSessions = false
        refreshPluginWorkspaceState()
    }

    func saveCurrentLogFilter(name: String?, query: String, severity: LogSeverityFilterMode, start: String, end: String, grouping: LogGroupingMode) {
        let generatedName = name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let filterName: String
        if let generatedName, !generatedName.isEmpty {
            filterName = generatedName
        } else if !query.isEmpty {
            filterName = "Filter: \(query)"
        } else if !start.isEmpty || !end.isEmpty {
            filterName = "Range \(start.isEmpty ? "..." : start) - \(end.isEmpty ? "..." : end)"
        } else {
            filterName = "Saved Log Filter \(settings.savedLogFilters.count + 1)"
        }

        settings.savedLogFilters.removeAll { $0.name.caseInsensitiveCompare(filterName) == .orderedSame }
        settings.savedLogFilters.insert(
            SavedLogFilter(
                name: filterName,
                query: query,
                severity: severity,
                startTimestamp: start,
                endTimestamp: end,
                grouping: grouping
            ),
            at: 0
        )
        AppSettingsStore.save(settings)
    }

    func deleteSavedLogFilter(_ filter: SavedLogFilter) {
        settings.savedLogFilters.removeAll { $0.id == filter.id }
        AppSettingsStore.save(settings)
    }

    func revertToSaved() {
        guard let selectedDocument else {
            return
        }

        guard selectedDocument.fileURL != nil else {
            return
        }

        if selectedDocument.isDirty {
            pendingAction = .revert(selectedDocument.id)
            showingDiscardChanges = true
            return
        }

        reloadDocumentFromDisk(id: selectedDocument.id, preserveSelection: false, announce: "Reverted to saved")
    }

    func resolveDiscardChanges() {
        showingDiscardChanges = false
        guard let pendingAction else {
            return
        }

        self.pendingAction = nil

        switch pendingAction {
        case let .close(id):
            finalizeClose(id: id)
        case let .revert(id):
            reloadDocumentFromDisk(id: id, preserveSelection: false, announce: "Reverted to saved")
        }
    }

    func cancelDiscardChanges() {
        showingDiscardChanges = false
        pendingAction = nil
    }

    func updateSelectedDocumentText(_ text: String) {
        guard let selectedDocumentID else {
            return
        }

        updateDocumentText(text, for: selectedDocumentID)
    }

    func updateDocumentText(_ text: String, for id: UUID) {
        updateDocument(id: id) { document in
            guard !document.isReadOnly else {
                return
            }

            guard document.text != text else {
                return
            }

            document.text = text
            document.refreshLanguageIfNeeded()
            document.syncDirtyState()
            document.statusMessage = document.isDirty ? "Unsaved changes" : "Saved"
            recomputeFindState(for: &document)
        }

        invalidateGitInsightState(for: id, clearLineDecorations: true)
        scheduleAutosave()
        refreshDocumentDiagnostics(for: id)
    }

    func updateSelectedDocumentSelection(_ selectedRange: NSRange) {
        guard let selectedDocumentID else {
            return
        }

        updateDocumentSelection(selectedRange, for: selectedDocumentID)
    }

    func updateDocumentSelection(_ selectedRange: NSRange, for id: UUID) {
        updateDocument(id: id) { document in
            guard document.selectedRange != selectedRange else {
                return
            }

            document.selectedRange = selectedRange

            if let selectedMatchIndex = document.findState.matchRanges.firstIndex(where: { $0 == selectedRange }) {
                document.findState.currentMatchIndex = selectedMatchIndex
            }
        }
    }

    func textBinding(for id: UUID) -> Binding<String> {
        Binding(
            get: { self.document(withID: id)?.text ?? "" },
            set: { self.updateDocumentText($0, for: id) }
        )
    }

    func selectionBinding(for id: UUID) -> Binding<NSRange> {
        Binding(
            get: { self.document(withID: id)?.selectedRange ?? NSRange(location: 0, length: 0) },
            set: { self.updateDocumentSelection($0, for: id) }
        )
    }

    func completionSession(for document: EditorDocument) -> EditorCompletionSession? {
        EditorCompletionService.session(
            in: document.text,
            selectedRange: document.selectedRange,
            language: document.language,
            sourceURL: document.sourceURL
        )
    }

    func applyCompletion(_ suggestion: EditorCompletionSuggestion, for documentID: UUID) {
        guard let document = document(withID: documentID) else {
            return
        }

        guard let session = completionSession(for: document) else {
            return
        }

        guard session.suggestions.contains(suggestion) else {
            return
        }

        let mutation = EditorCompletionService.mutation(for: suggestion, in: session)
        let replacementRange = NSRange(
            location: min(max(mutation.replacementRange.location, 0), (document.text as NSString).length),
            length: min(
                max(mutation.replacementRange.length, 0),
                (document.text as NSString).length - min(max(mutation.replacementRange.location, 0), (document.text as NSString).length)
            )
        )

        updateDocument(id: documentID) { updatedDocument in
            guard !updatedDocument.isReadOnly else {
                return
            }

            updatedDocument.text = (updatedDocument.text as NSString).replacingCharacters(
                in: replacementRange,
                with: mutation.replacementText
            )
            updatedDocument.selectedRange = mutation.selectedRange
            updatedDocument.refreshLanguageIfNeeded()
            updatedDocument.syncDirtyState()
            updatedDocument.statusMessage = "Inserted prediction"
            recomputeFindState(for: &updatedDocument)
        }

        requestEditorFocus()
        scheduleAutosave()
        refreshDocumentDiagnostics(for: documentID)
    }

    func isPluginEnabled(_ pluginID: String) -> Bool {
        let isPersistedEnabled = PluginHostService.normalizedEnabledPluginIDs(from: settings, installedPlugins: pluginCatalog).contains(pluginID)
        guard isPersistedEnabled else {
            return false
        }

        if workspaceTrustMode == .restricted {
            return PluginHostService.isAllowedInRestrictedMode(pluginID: pluginID)
        }

        return true
    }

    func togglePluginEnabled(_ pluginID: String) {
        var enabledIDs = PluginHostService.normalizedEnabledPluginIDs(from: settings, installedPlugins: pluginCatalog)

        if enabledIDs.contains(pluginID) {
            enabledIDs.remove(pluginID)
        } else {
            enabledIDs.insert(pluginID)
        }

        settings.enabledPluginIDs = pluginCatalog.map(\.id).filter { enabledIDs.contains($0) }
        AppSettingsStore.save(settings)
        refreshPluginWorkspaceState()
    }

    func availableSnippets(matching query: String = "") -> [EditorPluginSnippet] {
        guard let selectedDocument else {
            return []
        }

        let snippets = PluginHostService.snippets(
            for: selectedDocument.language,
            using: settings,
            workspaceRoots: workspaceRootURLs,
            trustMode: workspaceTrustMode
        )
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedQuery.isEmpty else {
            return snippets
        }

        return snippets.filter { snippet in
            let candidate = [snippet.title, snippet.detail, snippet.previewText]
                .joined(separator: " ")
            return candidate.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    func showPluginManagerPanel() {
        refreshPluginRegistry()
        showingPluginManager = true
    }

    func showGitWorkbenchPanel() {
        refreshGitWorkbench()
        showingGitWorkbench = true
    }

    func showProblemsPanelView() {
        showingProblemsPanel = true
    }

    func showTestExplorerPanel() {
        if testExplorerState.selectedTaskID == nil {
            testExplorerState.selectedTaskID = availableTestTasks.first?.id
        }
        showingTestExplorer = true
    }

    func showAIWorkbenchPanel() {
        guard ensureTrustedWorkspace(for: "AI workbench actions") else {
            return
        }
        ensureAIProviderSelection()
        ensureAISession()
        showingAIWorkbench = true
    }

    func showSnippetLibraryPanel() {
        showingSnippetLibrary = true
    }

    func showTaskRunnerPanel() {
        guard ensureTrustedWorkspace(for: "workspace tasks") else {
            return
        }
        refreshPluginWorkspaceState()
        showingTaskRunner = true
    }

    func showTerminalConsolePanel() {
        guard ensureTrustedWorkspace(for: "embedded terminal commands") else {
            return
        }
        if terminalPanelState.commandText.isEmpty {
            terminalPanelState.commandText = EmbeddedTerminalService.suggestedCommands.first ?? ""
        }

        showingTerminalConsole = true
    }

    func updateSelectedAIProviderID(_ id: UUID) {
        settings.preferredAIProviderID = id
        AppSettingsStore.save(settings)
    }

    func updateSelectedAIProviderName(_ value: String) {
        updateSelectedAIProvider { $0.name = value }
    }

    func updateSelectedAIProviderBaseURL(_ value: String) {
        updateSelectedAIProvider { $0.baseURLString = value }
    }

    func updateSelectedAIProviderModel(_ value: String) {
        updateSelectedAIProvider { $0.model = value }
    }

    func updateSelectedAIProviderAPIKey(_ value: String) {
        updateSelectedAIProvider { $0.apiKey = value }
    }

    func updateSelectedAIProviderEnabled(_ isEnabled: Bool) {
        updateSelectedAIProvider { $0.isEnabled = isEnabled }
    }

    func updateSelectedAIProviderTemperature(_ value: Double) {
        updateSelectedAIProvider { $0.temperature = value }
    }

    func createAISession() {
        let session = AIChatSession(title: "New Chat")
        aiWorkbenchState.sessions.insert(session, at: 0)
        aiWorkbenchState.selectedSessionID = session.id
        AIConversationStore.save(aiWorkbenchState.sessions)
    }

    func selectAISession(_ id: UUID) {
        aiWorkbenchState.selectedSessionID = id
    }

    func deleteAISession(_ id: UUID) {
        aiWorkbenchState.sessions.removeAll { $0.id == id }
        aiWorkbenchState.selectedSessionID = aiWorkbenchState.sessions.first?.id
        AIConversationStore.save(aiWorkbenchState.sessions)
    }

    func runEmbeddedTerminalCommand(_ commandOverride: String? = nil) {
        guard ensureTrustedWorkspace(for: "embedded terminal commands") else {
            return
        }
        let command = (commandOverride ?? terminalPanelState.commandText).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else {
            alertContext = AlertContext(title: "Command Needed", message: "Enter a shell command to run in the embedded terminal.")
            return
        }

        let workingDirectory = activeWorkspaceURL
        terminalPanelState.commandText = command
        terminalPanelState.lastRun = TerminalCommandRun(
            command: command,
            workingDirectoryPath: workingDirectory?.path,
            startedAt: Date(),
            output: "Running \(command)...",
            status: .running
        )
        terminalPanelState.history.removeAll { $0 == command }
        terminalPanelState.history.insert(command, at: 0)
        terminalPanelState.history = Array(terminalPanelState.history.prefix(20))
        showingTerminalConsole = true

        Task.detached(priority: .userInitiated) {
            let run = await EmbeddedTerminalService.run(command: command, currentDirectoryURL: workingDirectory)
            let problems = ProblemMatcherService.parseProblems(from: run.output, source: "Embedded Terminal")

            await MainActor.run {
                self.terminalPanelState.lastRun = run
                self.problemsPanelState.records = problems
                self.problemsPanelState.sourceDescription = "Embedded Terminal"
                self.problemsPanelState.lastUpdatedAt = Date()
                if run.status == .failed {
                    self.alertContext = AlertContext(
                        title: "Command Failed",
                        message: "The embedded terminal command exited unsuccessfully. Review the terminal output for details."
                    )
                }
            }
        }
    }

    func refreshWorkspaceExplorer() {
        workspaceExplorerState.includeHiddenFiles = settings.showHiddenFilesInExplorer
        workspaceExplorerState.nodes = WorkspaceExplorerService.loadTree(
            roots: workspaceRootURLs,
            includeHiddenFiles: workspaceExplorerState.includeHiddenFiles,
            favoritePaths: Set(settings.workspaceFavoritePaths)
        )
        workspaceExplorerState.selectedRootPath = activeWorkspaceURL?.path
        workspaceExplorerState.lastRefreshedAt = Date()
        workspaceExplorerState.statusMessage = workspaceExplorerState.nodes.isEmpty ? "Choose a workspace folder to browse files." : nil
    }

    func toggleWorkspaceFavorite(_ url: URL) {
        let path = url.standardizedFileURL.path
        if let index = settings.workspaceFavoritePaths.firstIndex(of: path) {
            settings.workspaceFavoritePaths.remove(at: index)
        } else {
            settings.workspaceFavoritePaths.append(path)
        }

        AppSettingsStore.save(settings)
        refreshWorkspaceExplorer()
    }

    func openWorkspaceExplorerNode(_ node: WorkspaceExplorerNode) {
        if node.isDirectory {
            activateWorkspace(at: node.url, statusMessage: "Workspace updated", openPreferredFile: false)
            return
        }

        openDocuments(at: [node.url])
    }

    func runRemoteSearch() {
        guard ensureTrustedWorkspace(for: "remote grep") else {
            return
        }
        let connection = selectedDocument?.remoteReference?.connection
            ?? RemoteFileReference.parse(remoteLocationDraft)?.connection
            ?? recentRemoteLocations.first?.connection

        guard let connection else {
            alertContext = AlertContext(title: "Remote Connection Needed", message: "Choose or enter a remote connection before running grep.")
            return
        }

        let rootPath = remoteWorkspaceState.searchRootPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let query = remoteWorkspaceState.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !rootPath.isEmpty, !query.isEmpty else {
            alertContext = AlertContext(title: "Remote Search Needs More Info", message: "Enter both a remote folder path and a search query.")
            return
        }

        remoteWorkspaceState.isSearching = true
        remoteWorkspaceState.statusMessage = "Searching \(connection):\(rootPath)"
        let executionMode = remoteWorkspaceState.executionMode

        Task.detached(priority: .userInitiated) {
            do {
                let results = try RemoteFileService.search(
                    connection: connection,
                    rootPath: rootPath,
                    query: query,
                    mode: executionMode
                )
                await MainActor.run {
                    self.remoteWorkspaceState.grepResults = results
                    self.remoteWorkspaceState.isSearching = false
                    self.remoteWorkspaceState.statusMessage = results.isEmpty ? "No remote matches found" : "\(results.count) remote matches"
                }
            } catch {
                await MainActor.run {
                    self.remoteWorkspaceState.isSearching = false
                    self.present(error: error, title: "Couldn’t Search Remote Host")
                }
            }
        }
    }

    func openRemoteSearchHit(_ hit: RemoteSearchHit) {
        let spec = "\(hit.connection):\(hit.path)"
        openRemoteDocument(spec: spec)

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            if let document = documents.first(where: { $0.remoteReference?.spec == spec }) {
                goToLine(hit.lineNumber, in: document.id)
            }
        }
    }

    func runRemoteCommand() {
        guard ensureTrustedWorkspace(for: "remote commands") else {
            return
        }
        let connection = selectedDocument?.remoteReference?.connection
            ?? RemoteFileReference.parse(remoteLocationDraft)?.connection
            ?? recentRemoteLocations.first?.connection
        let command = remoteWorkspaceState.commandText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let connection, !command.isEmpty else {
            alertContext = AlertContext(title: "Remote Command Needed", message: "Enter a remote connection and shell command to run.")
            return
        }

        remoteWorkspaceState.isRunningCommand = true
        remoteWorkspaceState.lastCommandStatus = .running
        remoteWorkspaceState.lastCommandOutput = "Running \(command) on \(connection)..."
        let executionMode = remoteWorkspaceState.executionMode

        Task.detached(priority: .userInitiated) {
            do {
                let result = try RemoteFileService.run(
                    connection: connection,
                    command: command,
                    mode: executionMode
                )
                let stdout = String(data: result.stdout, encoding: .utf8) ?? ""
                let stderr = String(data: result.stderr, encoding: .utf8) ?? ""
                let output = [stdout, stderr]
                    .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    .joined(separator: stdout.isEmpty || stderr.isEmpty ? "" : "\n\n")

                await MainActor.run {
                    self.remoteWorkspaceState.isRunningCommand = false
                    self.remoteWorkspaceState.lastCommandStatus = result.terminationStatus == 0 ? .succeeded : .failed
                    self.remoteWorkspaceState.lastCommandOutput = output.isEmpty ? "Command finished without output." : output
                }
            } catch {
                await MainActor.run {
                    self.remoteWorkspaceState.isRunningCommand = false
                    self.remoteWorkspaceState.lastCommandStatus = .failed
                    self.remoteWorkspaceState.lastCommandOutput = error.localizedDescription
                    self.present(error: error, title: "Couldn’t Run Remote Command")
                }
            }
        }
    }

    func stageSelectedFileInGit() {
        guard let document = selectedDocument, let fileURL = document.fileURL else {
            return
        }

        do {
            try GitService.stage(fileURL: fileURL, workspaceRoot: activeWorkspaceURL)
            refreshPluginWorkspaceState()
            updateDocument(id: document.id) { updatedDocument in
                updatedDocument.statusMessage = "Staged in Git"
            }
        } catch {
            present(error: error, title: "Couldn’t Stage File")
        }
    }

    func switchGitBranch(_ branch: String) {
        do {
            try GitService.checkout(branch: branch, at: activeWorkspaceURL)
            refreshPluginWorkspaceState()
            alertContext = AlertContext(title: "Switched Branch", message: "ForgeText checked out \(branch).")
        } catch {
            present(error: error, title: "Couldn’t Switch Branch")
        }
    }

    func selectPluginTask(_ id: String) {
        pluginTaskState.selectedTaskID = id
    }

    func insertSnippet(_ snippet: EditorPluginSnippet) {
        guard let selectedDocumentID, let document = selectedDocument else {
            return
        }

        guard !document.isReadOnly else {
            alertContext = AlertContext(title: "Read-Only Preview", message: "Snippets can only be inserted into editable documents.")
            return
        }

        let selectedText: String
        if document.selectedRange.length > 0 {
            selectedText = (document.text as NSString).substring(with: document.selectedRange)
        } else {
            selectedText = ""
        }

        var body = snippet.body.replacingOccurrences(of: "$SELECTION", with: selectedText)
        let markerRange = (body as NSString).range(of: "$0")
        let cursorOffset: Int?

        if markerRange.location != NSNotFound {
            body = (body as NSString).replacingCharacters(in: markerRange, with: "")
            cursorOffset = markerRange.location
        } else {
            cursorOffset = nil
        }

        updateDocument(id: selectedDocumentID) { updatedDocument in
            guard !updatedDocument.isReadOnly else {
                return
            }

            let text = updatedDocument.text as NSString
            let safeRange = NSRange(
                location: min(max(updatedDocument.selectedRange.location, 0), text.length),
                length: min(max(updatedDocument.selectedRange.length, 0), text.length - min(max(updatedDocument.selectedRange.location, 0), text.length))
            )
            updatedDocument.text = text.replacingCharacters(in: safeRange, with: body)
            let insertionPoint = safeRange.location + (cursorOffset ?? (body as NSString).length)
            updatedDocument.selectedRange = NSRange(location: insertionPoint, length: 0)
            updatedDocument.refreshLanguageIfNeeded()
            updatedDocument.syncDirtyState()
            updatedDocument.statusMessage = "Inserted snippet: \(snippet.title)"
            recomputeFindState(for: &updatedDocument)
        }

        requestEditorFocus()
        scheduleAutosave()
        refreshDocumentDiagnostics(for: selectedDocumentID)
    }

    func insertSnippet(withID snippetID: String) {
        guard let snippet = availableSnippets().first(where: { $0.id == snippetID }) else {
            return
        }

        insertSnippet(snippet)
    }

    func runPluginDiagnostics() {
        guard let selectedDocument else {
            return
        }

        let diagnostics = documentDiagnosticsByID[selectedDocument.id] ?? PluginDiagnosticsService.diagnostics(for: selectedDocument)
        documentDiagnosticsByID[selectedDocument.id] = diagnostics
        pluginDiagnosticsState.diagnostics = diagnostics
        pluginDiagnosticsState.documentID = selectedDocument.id
        pluginDiagnosticsState.lastRunAt = Date()
        pluginDiagnosticsState.statusMessage = diagnostics.isEmpty ? "No issues found" : "\(diagnostics.count) diagnostic\(diagnostics.count == 1 ? "" : "s")"
        showingPluginDiagnostics = true
    }

    func jumpToDiagnostic(_ diagnostic: PluginDiagnostic) {
        guard let lineNumber = diagnostic.lineNumber, let selectedDocumentID else {
            return
        }

        showingPluginDiagnostics = false
        goToLine(lineNumber, in: selectedDocumentID)
    }

    func formatSelectedDocumentUsingPlugins() {
        guard let selectedDocumentID, let document = selectedDocument else {
            return
        }

        guard !document.isReadOnly else {
            alertContext = AlertContext(title: "Read-Only Preview", message: "This document can’t be reformatted because it is read-only.")
            return
        }

        do {
            let formattedText = try PluginFormattingService.format(document)

            updateDocument(id: selectedDocumentID) { updatedDocument in
                updatedDocument.text = formattedText
                updatedDocument.selectedRange = NSRange(location: 0, length: 0)
                updatedDocument.syncDirtyState()
                updatedDocument.statusMessage = "Formatted document"
                recomputeFindState(for: &updatedDocument)
            }

            scheduleAutosave()
            refreshDocumentDiagnostics(for: selectedDocumentID)
        } catch {
            present(error: error, title: "Couldn’t Format Document")
        }
    }

    func runPrimaryWorkspaceTask(_ role: PluginTaskRole) {
        refreshPluginWorkspaceState()

        guard let task = pluginTaskState.tasks.first(where: { $0.role == role }) else {
            alertContext = AlertContext(
                title: "Task Not Available",
                message: "ForgeText could not find a \(role.displayName.lowercased()) task for the current workspace."
            )
            return
        }

        runWorkspaceTask(task)
    }

    func runWorkspaceTask(withID taskID: String) {
        guard let task = pluginTaskState.tasks.first(where: { $0.id == taskID }) else {
            return
        }

        runWorkspaceTask(task)
    }

    func refreshGitStatus() {
        refreshPluginWorkspaceState(showNoGitAlert: true)
    }

    func refreshGitWorkbench(showNoRepositoryAlert: Bool = false) {
        gitRefreshTask?.cancel()
        gitRefreshGeneration += 1
        let generation = gitRefreshGeneration
        let workspaceURL = activeWorkspaceURL

        guard workspaceURL != nil else {
            gitRepositorySummary = nil
            availableGitBranches = []
            gitPanelState.changedFiles = []
            gitPanelState.stashes = []
            gitPanelState.graphEntries = []
            gitPanelState.remotes = []
            gitPanelState.conflictSections = []

            if showNoRepositoryAlert {
                alertContext = AlertContext(
                    title: "No Git Repository",
                    message: "ForgeText couldn’t find a Git repository for the current workspace or document."
                )
            }
            return
        }

        gitRefreshTask = Task.detached(priority: .userInitiated) { [weak self] in
            let snapshot = GitService.snapshot(for: workspaceURL)

            await MainActor.run {
                guard let self, self.gitRefreshGeneration == generation else {
                    return
                }

                self.gitRepositorySummary = snapshot.summary
                self.availableGitBranches = snapshot.branches
                self.gitPanelState.changedFiles = snapshot.changedFiles
                self.gitPanelState.stashes = snapshot.stashes
                self.gitPanelState.graphEntries = snapshot.graphEntries
                self.gitPanelState.remotes = snapshot.remotes
                let selectedConflict = self.gitPanelState.selectedConflictFileID
                    .flatMap { id in snapshot.changedFiles.first(where: { $0.id == id && $0.isConflicted }) }
                    ?? snapshot.changedFiles.first(where: \.isConflicted)
                self.gitPanelState.selectedConflictFileID = selectedConflict?.id
                self.gitPanelState.conflictSections = selectedConflict.map { GitConflictService.sections(from: $0.absoluteURL) } ?? []

                if showNoRepositoryAlert, snapshot.summary == nil {
                    self.alertContext = AlertContext(
                        title: "No Git Repository",
                        message: "ForgeText couldn’t find a Git repository for the current workspace or document."
                    )
                }
            }
        }
    }

    func openGitChangedFile(_ file: GitChangedFile) {
        openDocuments(at: [file.absoluteURL])
    }

    func stageGitChangedFile(_ file: GitChangedFile) {
        do {
            try GitService.stage(fileURL: file.absoluteURL, workspaceRoot: activeWorkspaceURL)
            refreshGitWorkbench()
        } catch {
            present(error: error, title: "Couldn’t Stage File")
        }
    }

    func unstageGitChangedFile(_ file: GitChangedFile) {
        do {
            try GitService.unstage(fileURL: file.absoluteURL, workspaceRoot: activeWorkspaceURL)
            refreshGitWorkbench()
        } catch {
            present(error: error, title: "Couldn’t Unstage File")
        }
    }

    func fetchGitRepository() {
        runGitOperation(successMessage: "Fetched remote changes") {
            try GitService.fetch(at: activeWorkspaceURL)
        }
    }

    func pullGitRepository() {
        runGitOperation(successMessage: "Pulled latest changes") {
            try GitService.pull(at: activeWorkspaceURL)
        }
    }

    func pushGitRepository() {
        runGitOperation(successMessage: "Pushed current branch") {
            try GitService.push(at: activeWorkspaceURL)
        }
    }

    func commitGitChanges() {
        let message = gitPanelState.commitMessage
        runGitOperation(successMessage: "Committed staged changes") {
            try GitService.commit(message: message, at: activeWorkspaceURL)
        } onSuccess: {
            self.gitPanelState.commitMessage = ""
        }
    }

    func createGitBranch() {
        let branchName = gitPanelState.newBranchName
        runGitOperation(successMessage: "Created and switched branch") {
            try GitService.createBranch(named: branchName, at: activeWorkspaceURL)
        } onSuccess: {
            self.gitPanelState.newBranchName = ""
        }
    }

    func stashGitChanges() {
        let message = gitPanelState.stashMessage
        runGitOperation(successMessage: "Stashed working tree changes") {
            try GitService.stashSave(message: message, at: activeWorkspaceURL)
        } onSuccess: {
            self.gitPanelState.stashMessage = ""
        }
    }

    func popGitStash(_ stash: GitStashEntry?) {
        runGitOperation(successMessage: "Applied stash") {
            try GitService.stashPop(stash?.id, at: activeWorkspaceURL)
        }
    }

    func compareSelectedDocumentWithGitHead() {
        guard let document = selectedDocument, let fileURL = document.fileURL else {
            alertContext = AlertContext(
                title: "Compare with Git HEAD",
                message: "Open a saved local file before comparing against Git."
            )
            return
        }

        do {
            let headText = try GitService.headContents(for: fileURL, workspaceRoot: activeWorkspaceURL)
            let lines = DocumentComparisonService.compare(left: document.text, right: headText)
            comparisonState = DocumentComparisonState(
                title: "Compare with Git HEAD",
                leftTitle: document.displayName,
                rightTitle: "HEAD",
                lines: lines,
                changedLineCount: lines.filter { $0.kind != .unchanged }.count
            )
        } catch {
            present(error: error, title: "Couldn’t Compare with Git HEAD")
        }
    }

    func pluginStatusItems(for document: EditorDocument) -> [PluginStatusItem] {
        var items: [PluginStatusItem] = []

        if isPluginEnabled("forge.workspace-tasks"), !pluginTaskState.tasks.isEmpty {
            items.append(
                PluginStatusItem(
                    id: "tasks",
                    text: "Tasks \(pluginTaskState.tasks.count)",
                    symbolName: "play.square.stack",
                    tone: .accent
                )
            )
        }

        if isPluginEnabled("forge.snippet-library") {
            let snippetCount = PluginHostService.snippets(
                for: document.language,
                using: settings,
                workspaceRoots: workspaceRootURLs,
                trustMode: workspaceTrustMode
            ).count
            if snippetCount > 0 {
                items.append(
                    PluginStatusItem(
                        id: "snippets-\(document.language.rawValue)",
                        text: "Snippets \(snippetCount)",
                        symbolName: "text.badge.plus",
                        tone: .neutral
                    )
                )
            }
        }

        let diagnosticCount = inlineDiagnostics(for: document).count
        if diagnosticCount > 0 {
            let hasErrors = inlineDiagnostics(for: document).contains { $0.severity == .error }
            items.append(
                PluginStatusItem(
                    id: "diagnostics-\(document.id.uuidString)",
                    text: "Issues \(diagnosticCount)",
                    symbolName: hasErrors ? "xmark.octagon" : "exclamationmark.triangle",
                    tone: hasErrors ? .danger : .warning
                )
            )
        }

        if !problemsPanelState.records.isEmpty {
            let hasErrors = problemsPanelState.records.contains(where: { $0.severity == .error })
            items.append(
                PluginStatusItem(
                    id: "problems",
                    text: "Problems \(problemsPanelState.records.count)",
                    symbolName: hasErrors ? "xmark.octagon" : "exclamationmark.triangle",
                    tone: hasErrors ? .danger : .warning
                )
            )
        }

        if isPluginEnabled("forge.git-tools"), let gitRepositorySummary {
            items.append(
                PluginStatusItem(
                    id: "git-branch",
                    text: gitRepositorySummary.branchName,
                    symbolName: "point.topleft.down.curvedto.point.bottomright.up",
                    tone: .neutral
                )
            )

            if gitRepositorySummary.modifiedCount > 0 {
                items.append(
                    PluginStatusItem(
                        id: "git-modified",
                        text: "\(gitRepositorySummary.modifiedCount) modified",
                        symbolName: "pencil.line",
                        tone: .warning
                    )
                )
            }

            if gitRepositorySummary.stagedCount > 0 {
                items.append(
                    PluginStatusItem(
                        id: "git-staged",
                        text: "\(gitRepositorySummary.stagedCount) staged",
                        symbolName: "tray.and.arrow.down",
                        tone: .success
                    )
                )
            }

            if gitRepositorySummary.untrackedCount > 0 {
                items.append(
                    PluginStatusItem(
                        id: "git-untracked",
                        text: "\(gitRepositorySummary.untrackedCount) untracked",
                        symbolName: "questionmark.folder",
                        tone: .warning
                    )
                )
            }

            if gitRepositorySummary.conflictedCount > 0 {
                items.append(
                    PluginStatusItem(
                        id: "git-conflicted",
                        text: "\(gitRepositorySummary.conflictedCount) conflicted",
                        symbolName: "exclamationmark.triangle",
                        tone: .danger
                    )
                )
            }
        }

        return items
    }

    func openProblem(_ record: ProblemRecord) {
        guard let filePath = record.filePath else {
            showingProblemsPanel = false
            return
        }

        let url = URL(fileURLWithPath: filePath)
        openDocuments(at: [url])
        if let lineNumber = record.lineNumber,
           let documentID = documents.first(where: { $0.fileURL?.standardizedFileURL == url.standardizedFileURL })?.id {
            goToLine(lineNumber, in: documentID)
        }
        showingProblemsPanel = false
    }

    func runSelectedTestTask() {
        guard let selectedTaskID = testExplorerState.selectedTaskID else {
            return
        }

        runWorkspaceTask(withID: selectedTaskID)
        showingTestExplorer = true
    }

    func runSelectedCoverageTask() {
        guard let selectedTaskID = testExplorerState.selectedTaskID,
              let task = pluginTaskState.tasks.first(where: { $0.id == selectedTaskID })
        else {
            return
        }

        guard task.supportsCoverage else {
            alertContext = AlertContext(
                title: "Coverage Not Supported",
                message: "ForgeText doesn’t have a coverage run profile for this detected test task yet."
            )
            return
        }

        runWorkspaceTask(task, enableCoverage: true)
        showingTestExplorer = true
    }

    func sendAIPrompt(_ promptOverride: String? = nil, quickAction: AIQuickAction? = nil) {
        ensureAIProviderSelection()
        ensureAISession()

        guard let provider = selectedAIProvider else {
            alertContext = AlertContext(title: "AI Provider Needed", message: "Choose or enable an AI provider before sending a prompt.")
            return
        }

        let promptText = (promptOverride ?? aiWorkbenchState.draftPrompt).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !promptText.isEmpty || quickAction == .draftCommitMessage else {
            alertContext = AlertContext(title: "Prompt Needed", message: "Enter a prompt before sending it to the selected AI provider.")
            return
        }

        let selectedText = selectedDocument.flatMap(selectedText(in:))
        let workspaceRules = settings.aiIncludeWorkspaceRules ? AIRulesService.loadRules(for: activeWorkspaceURL) : nil
        let effectivePrompt: String
        if quickAction == .draftCommitMessage {
            let diff = (try? GitService.diffForWorkingTree(at: activeWorkspaceURL)) ?? ""
            effectivePrompt = diff.isEmpty ? "Draft a commit message for the current repository changes." : "Draft a Git commit message for these staged changes:\n\n\(diff)"
        } else {
            effectivePrompt = promptText
        }

        let preparedPrompt = AIProviderService.buildPrompt(
            userPrompt: effectivePrompt,
            currentDocument: settings.aiIncludeCurrentDocument ? selectedDocument : nil,
            selectedText: settings.aiIncludeSelection ? selectedText : nil,
            workspaceRules: workspaceRules,
            includeCurrentDocument: settings.aiIncludeCurrentDocument,
            includeSelectedText: settings.aiIncludeSelection,
            includeWorkspaceRules: settings.aiIncludeWorkspaceRules,
            quickAction: quickAction
        )

        aiWorkbenchState.isSending = true
        aiWorkbenchState.lastAction = quickAction
        aiWorkbenchState.statusMessage = "Sending prompt to \(provider.name)..."
        showingAIWorkbench = true

        let priorMessages = selectedAISession?.messages ?? []

        Task {
            do {
                let response = try await AIProviderService.send(
                    prompt: preparedPrompt,
                    sessionMessages: priorMessages.filter { $0.role != .system },
                    provider: provider
                )

                await MainActor.run {
                    self.recordAIInteraction(
                        prompt: effectivePrompt.isEmpty ? quickAction?.displayName ?? "AI Request" : effectivePrompt,
                        response: response,
                        provider: provider
                    )
                    self.aiWorkbenchState.isSending = false
                    self.aiWorkbenchState.lastResponseText = response
                    self.aiWorkbenchState.statusMessage = "Received response from \(provider.name)"
                    if quickAction == .draftCommitMessage {
                        self.gitPanelState.commitMessage = response
                        self.showingGitWorkbench = true
                    } else {
                        self.aiWorkbenchState.draftPrompt = ""
                    }
                }
            } catch {
                await MainActor.run {
                    self.aiWorkbenchState.isSending = false
                    self.aiWorkbenchState.statusMessage = error.localizedDescription
                    self.present(error: error, title: "Couldn’t Complete AI Request")
                }
            }
        }
    }

    func runAIQuickAction(_ action: AIQuickAction) {
        switch action {
        case .explainSelection:
            sendAIPrompt("Explain the selected code or text.", quickAction: action)
        case .improveSelection:
            sendAIPrompt("Improve the selected code or text while preserving intent.", quickAction: action)
        case .generateTests:
            sendAIPrompt("Generate strong automated tests for the selected code or current file.", quickAction: action)
        case .summarizeFile:
            sendAIPrompt("Summarize the current file for another developer.", quickAction: action)
        case .draftCommitMessage:
            sendAIPrompt("", quickAction: action)
        }
    }

    func insertLastAIResponseAtCursor() {
        guard let selectedDocumentID, let response = aiWorkbenchState.lastResponseText else {
            return
        }

        insertText(response, replacingSelection: false, in: selectedDocumentID)
    }

    func replaceSelectionWithLastAIResponse() {
        guard let selectedDocumentID, let response = aiWorkbenchState.lastResponseText else {
            return
        }

        insertText(response, replacingSelection: true, in: selectedDocumentID)
    }

    func showFindReplace() {
        guard let selectedDocumentID else {
            return
        }

        if selectedDocument?.presentationMode.isStructured == true {
            showRawTextView()
        }

        updateDocument(id: selectedDocumentID) { document in
            document.findState.isPresented = true

            if document.findState.query.isEmpty, document.selectedRange.length > 0 {
                let selectedText = (document.text as NSString).substring(with: document.selectedRange)
                if !selectedText.contains("\n"), !selectedText.isEmpty {
                    document.findState.query = selectedText
                }
            }

            recomputeFindState(for: &document)
        }
    }

    func hideFindReplace() {
        guard let selectedDocumentID else {
            return
        }

        updateDocument(id: selectedDocumentID) { document in
            document.findState.isPresented = false
        }
    }

    func updateFindQuery(_ query: String) {
        guard let selectedDocumentID else {
            return
        }

        updateDocument(id: selectedDocumentID) { document in
            document.findState.query = query
            recomputeFindState(for: &document)
        }
    }

    func updateReplacementQuery(_ replacement: String) {
        guard let selectedDocumentID else {
            return
        }

        updateDocument(id: selectedDocumentID) { document in
            document.findState.replacement = replacement
        }
    }

    func setCaseSensitiveFind(_ enabled: Bool) {
        guard let selectedDocumentID else {
            return
        }

        updateDocument(id: selectedDocumentID) { document in
            document.findState.isCaseSensitive = enabled
            recomputeFindState(for: &document)
        }
    }

    func setRegexFind(_ enabled: Bool) {
        guard let selectedDocumentID else {
            return
        }

        updateDocument(id: selectedDocumentID) { document in
            document.findState.usesRegularExpression = enabled
            recomputeFindState(for: &document)
        }
    }

    func findNextMatch() {
        moveToMatch(step: 1)
    }

    func findPreviousMatch() {
        moveToMatch(step: -1)
    }

    func replaceCurrentMatch() {
        guard let selectedDocumentID, let document = selectedDocument else {
            return
        }

        let targetRange = document.findState.currentMatchRange ?? document.selectedRange
        guard let replacement = TextSearchService.replaceCurrent(
            in: document.text,
            selectedRange: targetRange,
            query: document.findState.query,
            replacement: document.findState.replacement,
            options: searchOptions(for: document)
        ) else {
            moveToMatch(step: 1)
            return
        }

        updateDocument(id: selectedDocumentID) { updatedDocument in
            updatedDocument.text = replacement.text
            updatedDocument.selectedRange = replacement.selectedRange
            updatedDocument.syncDirtyState()
            updatedDocument.statusMessage = "Replaced 1 match"
            recomputeFindState(for: &updatedDocument)
        }

        scheduleAutosave()
        refreshDocumentDiagnostics(for: selectedDocumentID)
    }

    func replaceAllMatches() {
        guard let selectedDocumentID, let document = selectedDocument else {
            return
        }

        guard let replacement = TextSearchService.replaceAll(
            in: document.text,
            query: document.findState.query,
            replacement: document.findState.replacement,
            options: searchOptions(for: document)
        ) else {
            return
        }

        updateDocument(id: selectedDocumentID) { updatedDocument in
            updatedDocument.text = replacement.text
            updatedDocument.selectedRange = replacement.selectedRange
            updatedDocument.syncDirtyState()
            updatedDocument.statusMessage = replacement.replacementCount == 0
                ? "No matches to replace"
                : "Replaced \(replacement.replacementCount) matches"
            recomputeFindState(for: &updatedDocument)
        }

        scheduleAutosave()
        refreshDocumentDiagnostics(for: selectedDocumentID)
    }

    func showGoToLine() {
        if selectedDocument?.presentationMode.isStructured == true {
            showRawTextView()
        }

        showingGoToLine = true
    }

    func showProjectSearch() {
        if projectSearchState.rootURL == nil {
            projectSearchState.rootURL = selectedDocument?.fileURL?.deletingLastPathComponent()
        }

        projectSearchState.isPresented = true
    }

    func chooseWorkspaceRoot() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url?.standardizedFileURL else {
                return
            }

            Task { @MainActor in
                guard let self else { return }
                self.setWorkspaceRoots([url], activeRoot: url, workspaceName: url.lastPathComponent)
                self.projectSearchState.statusMessage = "Search root set"
                self.refreshPluginWorkspaceState()
            }
        }
    }

    func runProjectSearch() {
        let roots = workspaceRootURLs.isEmpty ? projectSearchState.rootURL.map { [$0] } ?? [] : workspaceRootURLs
        guard !roots.isEmpty else {
            chooseWorkspaceRoot()
            return
        }

        let query = projectSearchState.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else {
            projectSearchState.statusMessage = "Enter a search query"
            return
        }

        projectSearchTask?.cancel()
        projectSearchState.isSearching = true
        projectSearchState.statusMessage = nil

        let options = SearchOptions(
            isCaseSensitive: projectSearchState.isCaseSensitive,
            usesRegularExpression: projectSearchState.usesRegularExpression
        )
        let includeHiddenFiles = projectSearchState.includeHiddenFiles

        projectSearchTask = Task.detached(priority: .userInitiated) {
            let summary = WorkspaceSearchService.search(
                roots: roots,
                query: query,
                options: options,
                includeHiddenFiles: includeHiddenFiles
            )

            await MainActor.run {
                self.projectSearchState.isSearching = false
                self.projectSearchState.hits = summary.hits
                self.projectSearchState.scannedFileCount = summary.scannedFileCount
                self.projectSearchState.skippedFileCount = summary.skippedFileCount
                self.projectSearchState.elapsedTime = summary.elapsedTime
                self.projectSearchState.statusMessage = summary.hits.isEmpty ? "No matches found" : nil
            }
        }
    }

    func openProjectSearchHit(_ hit: ProjectSearchHit) {
        openDocuments(at: [hit.fileURL])

        guard let document = documents.first(where: { $0.fileURL?.standardizedFileURL == hit.fileURL.standardizedFileURL }) else {
            return
        }

        let selectedRange = Self.rangeForLineColumn(
            hit.lineNumber,
            column: hit.columnNumber,
            length: hit.matchLength,
            in: document.text
        )

        updateDocument(id: document.id) { updatedDocument in
            updatedDocument.selectedRange = selectedRange
            updatedDocument.findState.isPresented = true
        }

        selectedDocumentID = document.id
        projectSearchState.isPresented = false
        requestEditorFocus()
    }

    func goToLine(_ lineNumber: Int) {
        guard let selectedDocumentID, let document = selectedDocument else {
            return
        }

        goToLine(lineNumber, in: selectedDocumentID, document: document)
    }

    func goToLine(_ lineNumber: Int, in documentID: UUID) {
        guard let document = document(withID: documentID) else {
            return
        }

        goToLine(lineNumber, in: documentID, document: document)
    }

    private func goToLine(_ lineNumber: Int, in documentID: UUID, document: EditorDocument) {
        if selectedDocumentID != documentID {
            selectedDocumentID = documentID
        }

        guard let range = Self.rangeForLine(lineNumber, in: document.text) else {
            alertContext = AlertContext(title: "Line Not Found", message: "That line number is outside the document.")
            return
        }

        updateDocument(id: documentID) { updatedDocument in
            updatedDocument.selectedRange = range
            if let matchIndex = updatedDocument.findState.matchRanges.firstIndex(where: { $0 == range }) {
                updatedDocument.findState.currentMatchIndex = matchIndex
            }
        }
        requestEditorFocus()
    }

    func reloadFromExternalChange() {
        guard let selectedDocumentID else {
            return
        }

        reloadDocumentFromDisk(id: selectedDocumentID, preserveSelection: true, announce: "Reloaded external changes")
    }

    func toggleFollowMode() {
        guard let selectedDocumentID, canFollowSelectedDocument else {
            return
        }

        updateDocument(id: selectedDocumentID) { document in
            document.followModeEnabled.toggle()
            document.statusMessage = document.followModeEnabled ? "Follow mode enabled" : "Follow mode disabled"
        }

        if selectedDocument?.followModeEnabled == true {
            reloadDocumentFromDisk(id: selectedDocumentID, preserveSelection: false, announce: "Follow mode enabled")
        }
    }

    func showCompareAgainstSaved() {
        guard let document = selectedDocument else {
            return
        }

        let baselineText: String
        let rightTitle: String

        if let fileURL = document.fileURL, let diskVersion = try? TextFileCodec.open(from: fileURL) {
            baselineText = diskVersion.text
            rightTitle = document.hasExternalChanges ? "Disk" : "Saved"
        } else {
            baselineText = document.lastSavedText
            rightTitle = "Saved Snapshot"
        }

        guard !baselineText.isEmpty || !document.text.isEmpty else {
            alertContext = AlertContext(title: "Nothing to Compare", message: "This document doesn’t have a saved baseline yet.")
            return
        }

        let lines = DocumentComparisonService.compare(left: document.text, right: baselineText)
        comparisonState = DocumentComparisonState(
            title: "Compare Current Document",
            leftTitle: "Current",
            rightTitle: rightTitle,
            lines: lines,
            changedLineCount: lines.filter { $0.kind != .unchanged }.count
        )
    }

    func compareSelectedDocumentWithFile() {
        guard let document = selectedDocument else {
            return
        }

        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url?.standardizedFileURL else {
                return
            }

            guard let file = try? TextFileCodec.open(from: url) else {
                Task { @MainActor in
                    self?.alertContext = AlertContext(title: "Couldn’t Compare File", message: "ForgeText couldn’t read that file for comparison.")
                }
                return
            }

            let lines = DocumentComparisonService.compare(left: document.text, right: file.text)
            Task { @MainActor in
                self?.comparisonState = DocumentComparisonState(
                    title: "Compare with \(url.lastPathComponent)",
                    leftTitle: document.displayName,
                    rightTitle: url.lastPathComponent,
                    lines: lines,
                    changedLineCount: lines.filter { $0.kind != .unchanged }.count
                )
            }
        }
    }

    func openSelectedDocumentInTerminal() {
        let directoryURL = selectedDocument?.fileURL?.deletingLastPathComponent() ?? projectSearchState.rootURL
        guard let directoryURL else {
            return
        }

        TerminalService.openDirectory(directoryURL)
    }

    func keepCurrentVersionAfterExternalChange() {
        guard let selectedDocumentID, let selectedDocument, let fileURL = selectedDocument.fileURL else {
            return
        }

        updateDocument(id: selectedDocumentID) { document in
            document.hasExternalChanges = false
            document.fileMissingOnDisk = false
            document.lastKnownDiskFingerprint = DiskFingerprint.capture(for: fileURL)
            document.statusMessage = "Keeping ForgeText version"
        }
    }

    func setTheme(_ theme: EditorTheme) {
        settings.theme = theme
        AppSettingsStore.save(settings)
    }

    func setLanguage(_ language: DocumentLanguage) {
        guard let selectedDocumentID else {
            return
        }

        updateDocument(id: selectedDocumentID) { document in
            let wasShowingStructuredPresentation = document.presentationMode.isStructured
            document.language = language
            document.prefersStructuredPresentation = wasShowingStructuredPresentation && language.structuredPresentationMode != nil
            document.syncPresentationMode()
            document.statusMessage = "Language set to \(language.displayName)"
        }
        refreshDocumentDiagnostics(for: selectedDocumentID)
    }

    func showStructuredView() {
        guard let selectedDocumentID else {
            return
        }

        updateDocument(id: selectedDocumentID) { document in
            guard document.availableStructuredPresentationMode != nil else {
                return
            }

            document.prefersStructuredPresentation = true
            document.syncPresentationMode()
            document.statusMessage = "Showing \(document.presentationMode.displayName.lowercased())"
        }
    }

    func showRawTextView() {
        guard let selectedDocumentID else {
            return
        }

        updateDocument(id: selectedDocumentID) { document in
            document.prefersStructuredPresentation = false
            document.syncPresentationMode()
            document.statusMessage = "Showing raw text view"
        }

        requestEditorFocus()
    }

    func setEncoding(_ encoding: String.Encoding) {
        guard let selectedDocumentID else {
            return
        }

        updateDocument(id: selectedDocumentID) { document in
            document.encoding = encoding
            document.statusMessage = "Encoding set to \(encoding.displayName)"
        }
    }

    func setLineEnding(_ lineEnding: LineEnding) {
        guard let selectedDocumentID else {
            return
        }

        updateDocument(id: selectedDocumentID) { document in
            document.lineEnding = lineEnding
            document.statusMessage = "Line endings set to \(lineEnding.label)"
        }
    }

    func toggleByteOrderMark() {
        guard let selectedDocumentID else {
            return
        }

        updateDocument(id: selectedDocumentID) { document in
            document.includesByteOrderMark.toggle()
            document.statusMessage = document.includesByteOrderMark ? "Byte order mark enabled" : "Byte order mark disabled"
        }
    }

    func prettyPrintJSON() {
        formatSelectedJSON(prettyPrinted: true)
    }

    func minifyJSON() {
        formatSelectedJSON(prettyPrinted: false)
    }

    func exportSettings() {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "ForgeTextSettings.json"

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else {
                return
            }

            do {
                try AppSettingsStore.export(self?.settings ?? AppSettings(), to: url)
            } catch {
                Task { @MainActor in
                    self?.present(error: error, title: "Couldn’t Export Settings")
                }
            }
        }
    }

    func importSettings() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowsMultipleSelection = false

        panel.begin { [weak self] response in
            guard response == .OK, let url = panel.url else {
                return
            }

            do {
                let importedSettings = try AppSettingsStore.import(from: url)
                Task { @MainActor in
                    self?.settings = importedSettings
                    AppSettingsStore.save(importedSettings)
                    self?.refreshPluginWorkspaceState()
                    self?.refreshPluginRegistry()
                }
            } catch {
                Task { @MainActor in
                    self?.present(error: error, title: "Couldn’t Import Settings")
                }
            }
        }
    }

    func toggleWrapLines() {
        settings.wrapLines.toggle()
        AppSettingsStore.save(settings)
    }

    func increaseFontSize() {
        settings.fontSize = min(24, settings.fontSize + 1)
        AppSettingsStore.save(settings)
    }

    func decreaseFontSize() {
        settings.fontSize = max(11, settings.fontSize - 1)
        AppSettingsStore.save(settings)
    }

    func paletteItems(matching query: String) -> [PaletteItem] {
        var items: [PaletteItem] = [
            PaletteItem(id: "new", title: "New Document", subtitle: "Create a fresh untitled document", symbolName: "plus.square", action: .newDocument),
            PaletteItem(id: "open", title: "Open Files", subtitle: "Choose files from disk", symbolName: "folder", action: .openDocuments),
            PaletteItem(id: "openWorkspace", title: "Open Workspace File", subtitle: "Load a multi-root ForgeText workspace file", symbolName: "square.3.layers.3d.down.left", action: .openWorkspaceFile),
            PaletteItem(id: "saveWorkspace", title: "Save Workspace File", subtitle: "Persist the current roots and profile into a workspace file", symbolName: "square.3.layers.3d.top.filled", action: .saveWorkspaceFile),
            PaletteItem(id: "workspaceCenter", title: "Workspace Center", subtitle: "Manage workspace roots, trust, profiles, and sync", symbolName: "square.3.layers.3d", action: .showWorkspacePlatform),
            PaletteItem(id: "appearancePreferences", title: "Appearance Preferences", subtitle: "Tune Retro Pro, density, focus mode, and inspector settings", symbolName: "paintbrush.pointed", action: .showAppearancePreferences),
            PaletteItem(id: "cloneRepository", title: "Clone Repository", subtitle: "Clone a GitHub or Git repository and open it as a workspace", symbolName: "square.and.arrow.down.on.square", action: .cloneRepository),
            PaletteItem(id: "openRemote", title: "Open Remote File", subtitle: "Open a document over SSH", symbolName: "network", action: .openRemote),
            PaletteItem(id: "gitWorkbench", title: "Git Workbench", subtitle: "Commit, push, pull, stash, and inspect repository changes", symbolName: "point.topleft.down.curvedto.point.bottomright.up", action: .showGitWorkbench),
            PaletteItem(id: "problems", title: "Problems Panel", subtitle: "Review matched build, test, and lint problems", symbolName: "exclamationmark.bubble", action: .showProblemsPanel),
            PaletteItem(id: "tests", title: "Test Explorer", subtitle: "Run detected test tasks and inspect results", symbolName: "checklist.checked", action: .showTestExplorer),
            PaletteItem(id: "aiWorkbench", title: "AI Workbench", subtitle: "Chat with configured models and run editor AI actions", symbolName: "sparkles.rectangle.stack", action: .showAIWorkbench),
            PaletteItem(id: "plugins", title: "Plugin Manager", subtitle: "Enable built-in IDE plugins and review their capabilities", symbolName: "puzzlepiece.extension", action: .showPluginManager),
            PaletteItem(id: "snippets", title: "Snippet Library", subtitle: "Browse and insert snippets for the active document", symbolName: "text.badge.plus", action: .showSnippetLibrary),
            PaletteItem(id: "tasks", title: "Task Runner", subtitle: "Run workspace build, test, and lint tasks", symbolName: "play.square.stack", action: .showTaskRunner),
            PaletteItem(id: "terminalConsole", title: "Embedded Terminal", subtitle: "Run workspace shell commands inside ForgeText", symbolName: "terminal.fill", action: .showTerminalConsole),
            PaletteItem(id: "refreshExplorer", title: "Refresh Workspace Explorer", subtitle: "Reload the workspace file tree and favorites", symbolName: "folder.badge.gearshape", action: .refreshWorkspaceExplorer),
            PaletteItem(id: "searchFolder", title: "Search in Folder", subtitle: "Run a project-wide text search", symbolName: "magnifyingglass", action: .searchInFolder),
            PaletteItem(id: "save", title: "Save", subtitle: "Write the current document to disk", symbolName: "square.and.arrow.down", action: .saveDocument),
            PaletteItem(id: "savePrivileged", title: "Privileged Save", subtitle: "Save the current file with administrator privileges", symbolName: "lock.open.display", action: .savePrivileged),
            PaletteItem(id: "close", title: "Close Document", subtitle: "Close the active tab", symbolName: "xmark.circle", action: .closeDocument),
            PaletteItem(id: "find", title: "Find and Replace", subtitle: "Search within the current document", symbolName: "magnifyingglass", action: .showFind),
            PaletteItem(id: "line", title: "Go To Line", subtitle: "Jump directly to a line number", symbolName: "text.line.first.and.arrowtriangle.forward", action: .goToLine),
            PaletteItem(id: "nextMatch", title: "Next Match", subtitle: "Jump to the next search result", symbolName: "arrow.down.circle", action: .nextMatch),
            PaletteItem(id: "prevMatch", title: "Previous Match", subtitle: "Jump to the previous search result", symbolName: "arrow.up.circle", action: .previousMatch),
            PaletteItem(id: "comment", title: "Toggle Comment", subtitle: "Comment or uncomment the current line or selection", symbolName: "text.badge.minus", action: .toggleComment),
            PaletteItem(id: "formatDocument", title: "Format Document", subtitle: "Apply the built-in formatter for the current file type", symbolName: "wand.and.stars", action: .formatDocument),
            PaletteItem(id: "diagnostics", title: "Run Diagnostics", subtitle: "Inspect the current document for structural issues", symbolName: "stethoscope", action: .runPluginDiagnostics),
            PaletteItem(id: "refreshGit", title: "Refresh Git Status", subtitle: "Reload branch and working tree information", symbolName: "arrow.clockwise", action: .refreshGitStatus),
            PaletteItem(id: "compareGitHead", title: "Compare with Git HEAD", subtitle: "Review the current file against the last commit", symbolName: "arrow.left.arrow.right.square", action: .compareWithGitHead),
            PaletteItem(id: "stageGit", title: "Stage Current File", subtitle: "Add the active file to the Git index", symbolName: "tray.and.arrow.down", action: .stageCurrentFileInGit),
            PaletteItem(id: "aiExplain", title: "AI: Explain Selection", subtitle: "Ask the selected model to explain the current selection", symbolName: AIQuickAction.explainSelection.symbolName, action: .runAIQuickAction(.explainSelection)),
            PaletteItem(id: "aiImprove", title: "AI: Improve Selection", subtitle: "Ask the selected model to improve the current selection", symbolName: AIQuickAction.improveSelection.symbolName, action: .runAIQuickAction(.improveSelection)),
            PaletteItem(id: "aiTests", title: "AI: Generate Tests", subtitle: "Ask the selected model for tests covering the current code", symbolName: AIQuickAction.generateTests.symbolName, action: .runAIQuickAction(.generateTests)),
            PaletteItem(id: "aiSummary", title: "AI: Summarize File", subtitle: "Ask the selected model to summarize the current file", symbolName: AIQuickAction.summarizeFile.symbolName, action: .runAIQuickAction(.summarizeFile)),
            PaletteItem(id: "aiCommit", title: "AI: Draft Commit Message", subtitle: "Generate a Git commit message from the current diff", symbolName: AIQuickAction.draftCommitMessage.symbolName, action: .runAIQuickAction(.draftCommitMessage)),
            PaletteItem(id: "compareSaved", title: "Compare with Saved", subtitle: "Review the current buffer against disk", symbolName: "square.split.2x1", action: .compareWithSaved),
            PaletteItem(id: "compareFile", title: "Compare with File", subtitle: "Choose another file and compare it", symbolName: "doc.on.doc", action: .compareWithFile),
            PaletteItem(id: "follow", title: "Toggle Follow Mode", subtitle: "Auto-reload changes from disk", symbolName: "arrow.triangle.2.circlepath", action: .toggleFollowMode),
            PaletteItem(id: "terminal", title: "Open in Terminal", subtitle: "Open the current file folder in Terminal", symbolName: "terminal", action: .openInTerminal),
            PaletteItem(id: "prettyJSON", title: "Pretty Print JSON", subtitle: "Format the current JSON document", symbolName: "curlybraces", action: .prettyPrintJSON),
            PaletteItem(id: "minifyJSON", title: "Minify JSON", subtitle: "Compress the current JSON document", symbolName: "curlybraces.square", action: .minifyJSON),
            PaletteItem(id: "exportSettings", title: "Export Settings", subtitle: "Save ForgeText preferences to a file", symbolName: "square.and.arrow.up", action: .exportSettings),
            PaletteItem(id: "importSettings", title: "Import Settings", subtitle: "Load ForgeText preferences from a file", symbolName: "square.and.arrow.down", action: .importSettings),
            PaletteItem(id: "exportSync", title: "Export Sync Bundle", subtitle: "Export settings, sessions, and AI chats together", symbolName: "externaldrive.badge.plus", action: .exportSyncBundle),
            PaletteItem(id: "importSync", title: "Import Sync Bundle", subtitle: "Import settings, sessions, and AI chats together", symbolName: "externaldrive.badge.checkmark", action: .importSyncBundle),
            PaletteItem(id: "trustWorkspace", title: "Trust Workspace", subtitle: "Allow tasks, AI, remote commands, and plugins for this workspace", symbolName: "checkmark.shield", action: .trustWorkspace),
            PaletteItem(id: "restrictWorkspace", title: "Restrict Workspace", subtitle: "Disable risky workspace execution paths until trusted again", symbolName: "lock.shield", action: .restrictWorkspace),
            PaletteItem(id: "wrap", title: settings.wrapLines ? "Disable Line Wrap" : "Enable Line Wrap", subtitle: "Toggle soft wrapping in the editor", symbolName: "paragraphformat", action: .toggleWrapLines),
            PaletteItem(id: "outline", title: settings.showsOutline ? "Hide Outline" : "Show Outline", subtitle: "Toggle the document outline rail", symbolName: "list.bullet.indent", action: .toggleOutline),
            PaletteItem(id: "inspector", title: settings.showsInspector ? "Hide Inspector" : "Show Inspector", subtitle: "Toggle the right-side inspector drawer", symbolName: "sidebar.trailing", action: .toggleInspector),
            PaletteItem(id: "breadcrumbs", title: settings.showsBreadcrumbs ? "Hide Breadcrumbs" : "Show Breadcrumbs", subtitle: "Toggle the workspace breadcrumb trail", symbolName: "chevron.left.slash.chevron.right", action: .toggleBreadcrumbs),
            PaletteItem(id: "focusMode", title: settings.focusModeEnabled ? "Exit Focus Mode" : "Enter Focus Mode", subtitle: "Hide surrounding chrome for quieter editing", symbolName: "viewfinder", action: .toggleFocusMode),
            PaletteItem(id: "splitAlt", title: "Split: Raw + Structured", subtitle: "Show the current document in both raw and structured forms", symbolName: "rectangle.split.2x1", action: .setSplitMode(.alternatePresentation)),
            PaletteItem(id: "splitDoc", title: "Split: Second Document", subtitle: "Edit another open document side by side", symbolName: "rectangle.split.2x1.fill", action: .setSplitMode(.secondDocument)),
            PaletteItem(id: "splitOff", title: "Split: Single Pane", subtitle: "Return to the single-editor layout", symbolName: "rectangle", action: .setSplitMode(.off)),
            PaletteItem(id: "saveSession", title: "Save Workspace Session", subtitle: "Capture the current workspace as a named session", symbolName: "square.stack.3d.down.right", action: .saveWorkspaceSession),
            PaletteItem(id: "showSessions", title: "Open Workspace Sessions", subtitle: "Load or manage saved workspace sessions", symbolName: "square.stack.3d.up", action: .showWorkspaceSessions),
            PaletteItem(id: "fontUp", title: "Increase Font Size", subtitle: "Make the editor text larger", symbolName: "plus.magnifyingglass", action: .increaseFontSize),
            PaletteItem(id: "fontDown", title: "Decrease Font Size", subtitle: "Make the editor text smaller", symbolName: "minus.magnifyingglass", action: .decreaseFontSize),
        ]

        items += EditorTheme.allCases.map {
            PaletteItem(
                id: "theme-\($0.rawValue)",
                title: "Theme: \($0.displayName)",
                subtitle: "Apply the \($0.displayName) editor theme",
                symbolName: "paintpalette",
                action: .setTheme($0)
            )
        }

        items += AppChromeStyle.allCases.map {
            PaletteItem(
                id: "chrome-\($0.rawValue)",
                title: "Appearance: \($0.displayName)",
                subtitle: $0.summary,
                symbolName: "paintbrush.pointed",
                action: .setChromeStyle($0)
            )
        }

        items += InterfaceDensity.allCases.map {
            PaletteItem(
                id: "density-\($0.rawValue)",
                title: "Density: \($0.displayName)",
                subtitle: "Use the \($0.displayName.lowercased()) interface density",
                symbolName: "rectangle.compress.vertical",
                action: .setInterfaceDensity($0)
            )
        }

        items += String.Encoding.commonSaveEncodings.map {
            PaletteItem(
                id: "encoding-\($0.rawValue)",
                title: "Encoding: \($0.displayName)",
                subtitle: "Save the document using \($0.displayName)",
                symbolName: "character.book.closed",
                action: .setEncoding($0)
            )
        }

        items += LineEnding.allCases.map {
            PaletteItem(
                id: "lineEnding-\($0.rawValue)",
                title: "Line Endings: \($0.label)",
                subtitle: "Normalize line endings to \($0.label)",
                symbolName: "return",
                action: .setLineEnding($0)
            )
        }

        items.append(
            PaletteItem(
                id: "toggleBom",
                title: "Toggle Byte Order Mark",
                subtitle: "Enable or disable BOM on save",
                symbolName: "textformat.abc",
                action: .toggleByteOrderMark
            )
        )

        if availableTestTasks.contains(where: \.supportsCoverage) {
            items.append(
                PaletteItem(
                    id: "coverage",
                    title: "Run Coverage Task",
                    subtitle: "Run the selected test task with coverage enabled when supported",
                    symbolName: "chart.bar.doc.horizontal",
                    action: .runCoverageTask
                )
            )
        }

        if let selectedDocument {
            if selectedDocument.availableStructuredPresentationMode != nil {
                items.append(
                    PaletteItem(
                        id: "structuredView",
                        title: structuredToggleTitle(for: selectedDocument),
                        subtitle: selectedDocument.presentationMode.isStructured
                            ? "Switch back to the text editor"
                            : structuredToggleSubtitle(for: selectedDocument),
                        symbolName: structuredToggleSymbol(for: selectedDocument),
                        action: selectedDocument.presentationMode.isStructured ? .showRawText : .showStructuredView
                    )
                )
            }

            items += DocumentLanguage.allCases.map {
                PaletteItem(
                    id: "language-\($0.rawValue)",
                    title: "Language: \($0.displayName)",
                    subtitle: "Highlight the active document as \($0.displayName)",
                    symbolName: $0.symbolName,
                    action: .setLanguage($0)
                )
            }

            items += documents.map {
                PaletteItem(
                    id: "doc-\($0.id.uuidString)",
                    title: $0.displayName,
                    subtitle: $0.pathDescription,
                    symbolName: $0.language.symbolName,
                    action: .switchDocument($0.id)
                )
            }

            if selectedDocument.fileURL != nil {
                items.append(
                    PaletteItem(
                        id: "switch-current-\(selectedDocument.id.uuidString)",
                        title: "Current Document",
                        subtitle: selectedDocument.displayName,
                        symbolName: selectedDocument.language.symbolName,
                        action: .switchDocument(selectedDocument.id)
                    )
                )
            }
        }

        items += recentFiles.map {
            PaletteItem(
                id: "recent-\($0.path)",
                title: $0.lastPathComponent,
                subtitle: $0.path(percentEncoded: false),
                symbolName: "clock.arrow.circlepath",
                action: .openRecent($0)
            )
        }

        items += recentRemoteLocations.map {
            PaletteItem(
                id: "recent-remote-\($0.spec)",
                title: $0.displayName,
                subtitle: $0.pathDescription,
                symbolName: "network",
                action: .openRemoteSpec($0.spec)
            )
        }

        items += enabledPlugins.flatMap(\.commands).map { command in
            PaletteItem(
                id: "plugin-command-\(command.id)",
                title: command.title,
                subtitle: command.subtitle,
                symbolName: command.symbolName,
                action: paletteAction(for: command.action)
            )
        }

        items += pluginTaskState.tasks.map { task in
            PaletteItem(
                id: "plugin-task-\(task.id)",
                title: task.title,
                subtitle: task.subtitle,
                symbolName: task.symbolName,
                action: .runWorkspaceTask(task.id)
            )
        }

        items += availableGitBranches.map { branch in
            PaletteItem(
                id: "git-branch-\(branch)",
                title: "Switch to \(branch)",
                subtitle: "Check out the \(branch) Git branch",
                symbolName: "point.topleft.down.curvedto.point.bottomright.up",
                action: .switchGitBranch(branch)
            )
        }

        items += availableSnippets().map { snippet in
            PaletteItem(
                id: "plugin-snippet-\(snippet.id)",
                title: "Snippet: \(snippet.title)",
                subtitle: snippet.detail,
                symbolName: snippet.symbolName,
                action: .insertSnippet(snippet.id)
            )
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return items
        }

        let scoredItems: [(PaletteItem, Int)] = items.compactMap { item -> (PaletteItem, Int)? in
            let candidate = item.title + " " + item.subtitle
            guard let score = Self.fuzzyScore(query: trimmedQuery, candidate: candidate) else {
                return nil
            }

            return (item, score)
        }

        return scoredItems.sorted { lhs, rhs in
            if lhs.1 == rhs.1 {
                return lhs.0.title.localizedCaseInsensitiveCompare(rhs.0.title) == .orderedAscending
            }

            return lhs.1 > rhs.1
        }
        .map(\.0)
    }

    func performPaletteAction(_ action: PaletteAction) {
        showingCommandPalette = false

        switch action {
        case .newDocument:
            newDocument()
        case .openDocuments:
            openDocument()
        case .openWorkspaceFile:
            openWorkspaceFilePanel()
        case .saveWorkspaceFile:
            saveWorkspaceFile()
        case .showWorkspacePlatform:
            showWorkspacePlatformPanel()
        case .cloneRepository:
            showCloneRepositoryPanel()
        case .openRemote:
            openRemotePanel()
        case .showGitWorkbench:
            showGitWorkbenchPanel()
        case .showProblemsPanel:
            showProblemsPanelView()
        case .showTestExplorer:
            showTestExplorerPanel()
        case .showAIWorkbench:
            showAIWorkbenchPanel()
        case let .runAIQuickAction(action):
            runAIQuickAction(action)
        case let .openRemoteSpec(spec):
            openRemoteDocument(spec: spec)
        case .showPluginManager:
            showPluginManagerPanel()
        case .showSnippetLibrary:
            showSnippetLibraryPanel()
        case .showTaskRunner:
            showTaskRunnerPanel()
        case .showTerminalConsole:
            showTerminalConsolePanel()
        case .searchInFolder:
            showProjectSearch()
        case .saveDocument:
            saveDocument()
        case .savePrivileged:
            saveDocumentPrivileged()
        case .closeDocument:
            closeSelectedDocument()
        case .showFind:
            showFindReplace()
        case .goToLine:
            showingGoToLine = true
        case .nextMatch:
            findNextMatch()
        case .previousMatch:
            findPreviousMatch()
        case .toggleComment:
            NSApp.sendAction(#selector(EditorTextView.toggleCommentSelection(_:)), to: nil, from: nil)
        case .showStructuredView:
            showStructuredView()
        case .showRawText:
            showRawTextView()
        case .compareWithSaved:
            showCompareAgainstSaved()
        case .compareWithFile:
            compareSelectedDocumentWithFile()
        case .toggleFollowMode:
            toggleFollowMode()
        case .openInTerminal:
            openSelectedDocumentInTerminal()
        case .prettyPrintJSON:
            prettyPrintJSON()
        case .minifyJSON:
            minifyJSON()
        case .formatDocument:
            formatSelectedDocumentUsingPlugins()
        case .runPluginDiagnostics:
            runPluginDiagnostics()
        case .compareWithGitHead:
            compareSelectedDocumentWithGitHead()
        case .refreshGitStatus:
            refreshGitStatus()
        case .stageCurrentFileInGit:
            stageSelectedFileInGit()
        case let .switchGitBranch(branch):
            switchGitBranch(branch)
        case .refreshWorkspaceExplorer:
            refreshWorkspaceExplorer()
        case let .runPrimaryWorkspaceTask(role):
            runPrimaryWorkspaceTask(role)
        case let .runWorkspaceTask(taskID):
            runWorkspaceTask(withID: taskID)
        case .runCoverageTask:
            runSelectedCoverageTask()
        case let .insertSnippet(snippetID):
            insertSnippet(withID: snippetID)
        case .exportSettings:
            exportSettings()
        case .importSettings:
            importSettings()
        case .exportSyncBundle:
            exportSyncBundle()
        case .importSyncBundle:
            importSyncBundle()
        case .trustWorkspace:
            trustCurrentWorkspace()
        case .restrictWorkspace:
            restrictCurrentWorkspace()
        case .toggleWrapLines:
            toggleWrapLines()
        case .toggleOutline:
            toggleOutlinePanel()
        case .toggleInspector:
            toggleInspectorPanel()
        case .toggleBreadcrumbs:
            toggleBreadcrumbs()
        case .toggleFocusMode:
            toggleFocusMode()
        case .showAppearancePreferences:
            showAppearancePreferences()
        case let .setChromeStyle(style):
            setChromeStyle(style)
        case let .setInterfaceDensity(density):
            setInterfaceDensity(density)
        case let .setSplitMode(mode):
            setSecondaryPaneMode(mode)
        case .saveWorkspaceSession:
            showingWorkspaceSessions = true
        case .showWorkspaceSessions:
            showWorkspaceSessionsPanel()
        case .increaseFontSize:
            increaseFontSize()
        case .decreaseFontSize:
            decreaseFontSize()
        case let .setEncoding(encoding):
            setEncoding(encoding)
        case let .setLineEnding(lineEnding):
            setLineEnding(lineEnding)
        case .toggleByteOrderMark:
            toggleByteOrderMark()
        case let .setTheme(theme):
            setTheme(theme)
        case let .setLanguage(language):
            setLanguage(language)
        case let .switchDocument(id):
            selectDocument(id)
        case let .openRecent(url):
            openDocuments(at: [url])
        }
    }

    private func saveDocument(id: UUID, to url: URL, initiatedByAutosave: Bool) {
        guard let document = document(withID: id) else {
            return
        }

        do {
            try TextFileCodec.save(document: document, to: url)
            invalidateGitInsightState(for: id, clearLineDecorations: true)

            updateDocument(id: id) { updatedDocument in
                updatedDocument.fileURL = url
                updatedDocument.remoteReference = nil
                updatedDocument.untitledName = url.lastPathComponent
                updatedDocument.lastSavedText = updatedDocument.text
                updatedDocument.isDirty = false
                updatedDocument.hasExternalChanges = false
                updatedDocument.fileMissingOnDisk = false
                updatedDocument.hasRecoveredDraft = false
                updatedDocument.lastKnownDiskFingerprint = DiskFingerprint.capture(for: url)
                updatedDocument.lastSavedAt = Date()
                updatedDocument.statusMessage = initiatedByAutosave ? "Autosaved" : "Saved"
                updatedDocument.isReadOnly = false
                updatedDocument.isPartialPreview = false
                updatedDocument.fileSize = DiskFingerprint.capture(for: url)?.fileSize
                updatedDocument.refreshLanguageIfNeeded()
                updatedDocument.syncPresentationMode()
            }

            RecoveryService.deleteSnapshot(for: id)
            recordRecentFile(url)
            refreshPluginWorkspaceState()
            refreshDocumentDiagnostics(for: id)
        } catch {
            if !initiatedByAutosave, PrivilegedFileService.isPermissionFailure(error), PrivilegedFileService.likelyNeedsPrivilege(for: url) {
                alertContext = AlertContext(
                    title: "Permission Needed",
                    message: "ForgeText couldn’t write to this path normally. Try File > Privileged Save to save it with administrator privileges."
                )
            } else {
                present(error: error, title: initiatedByAutosave ? "Autosave Failed" : "Couldn’t Save File")
            }
        }
    }

    private func saveRemoteDocument(id: UUID) {
        guard let document = document(withID: id) else {
            return
        }

        Task.detached(priority: .userInitiated) {
            do {
                try RemoteFileService.save(document: document)

                await MainActor.run {
                    self.updateDocument(id: id) { updatedDocument in
                        updatedDocument.lastSavedText = updatedDocument.text
                        updatedDocument.isDirty = false
                        updatedDocument.hasRecoveredDraft = false
                        updatedDocument.lastSavedAt = Date()
                        updatedDocument.statusMessage = "Saved to remote host"
                        updatedDocument.fileSize = Int64(updatedDocument.text.utf8.count)
                    }
                    RecoveryService.deleteSnapshot(for: id)
                    self.recordRecentRemote(document.remoteReference)
                    self.refreshPluginWorkspaceState()
                    self.refreshDocumentDiagnostics(for: id)
                }
            } catch {
                await MainActor.run {
                    self.present(error: error, title: "Couldn’t Save Remote File")
                }
            }
        }
    }

    private func finalizeClose(id: UUID) {
        RecoveryService.deleteSnapshot(for: id)
        documents.removeAll { $0.id == id }
        documentDiagnosticsByID[id] = nil
        invalidateGitInsightState(for: id, clearLineDecorations: true)

        if selectedDocumentID == id {
            selectedDocumentID = documents.last?.id
        }

        if documents.isEmpty {
            let document = EditorDocument.untitled(named: nextUntitledName())
            documents = [document]
            selectedDocumentID = document.id
        }

        requestEditorFocus()

        scheduleSessionSave()
        refreshPluginWorkspaceState()
    }

    private func restoreWorkspace() {
        let session = SessionStore.load()
        recentFiles = session.recentFilePaths
            .map(URL.init(fileURLWithPath:))
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        recentRemoteLocations = session.recentRemoteSpecs.compactMap(RemoteFileReference.parse)
        let sessionRoots = (session.workspaceRootPaths.isEmpty ? session.workspaceRootPath.map { [$0] } ?? [] : session.workspaceRootPaths)
            .map { URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL }
        let activeRoot = (session.activeWorkspaceRootPath ?? session.workspaceRootPath).map { URL(fileURLWithPath: $0, isDirectory: true).standardizedFileURL }
        setWorkspaceRoots(
            sessionRoots,
            activeRoot: activeRoot,
            workspaceFileURL: session.workspaceFilePath.map(URL.init(fileURLWithPath:)),
            workspaceName: WorkspacePlatformService.preferredWorkspaceName(for: sessionRoots),
            selectedProfileID: session.selectedProfileID
        )

        let recoveredDocuments = RecoveryService.loadRecoveredDocuments()
        documents = recoveredDocuments

        let recoveredPaths = Set(recoveredDocuments.compactMap { $0.fileURL?.standardizedFileURL.path })
        let recoveredRemoteSpecs = Set(recoveredDocuments.compactMap { $0.remoteReference?.spec })

        for path in session.openFilePaths where !recoveredPaths.contains(path) {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            guard FileManager.default.fileExists(atPath: url.path) else {
                continue
            }

            do {
                let file = try TextFileCodec.open(from: url)
                documents.append(EditorDocument.loaded(file: file, url: url))
            } catch {
                continue
            }
        }

        for remoteSpec in session.openRemoteSpecs where !recoveredRemoteSpecs.contains(remoteSpec) {
            openRestoredRemoteDocument(remoteSpec)
        }

        if documents.isEmpty {
            let document = EditorDocument.untitled(named: nextUntitledName())
            documents = [document]
            selectedDocumentID = document.id
        } else if
            let selectedFilePath = session.selectedFilePath,
            let selectedDocument = documents.first(where: { $0.fileURL?.path == selectedFilePath })
        {
            selectedDocumentID = selectedDocument.id
        } else if
            let selectedRemoteSpec = session.selectedRemoteSpec,
            let selectedDocument = documents.first(where: { $0.remoteReference?.spec == selectedRemoteSpec })
        {
            selectedDocumentID = selectedDocument.id
        } else {
            selectedDocumentID = documents.first?.id
        }

        requestEditorFocus()
        refreshPluginWorkspaceState()
        refreshAllDocumentDiagnostics()
    }

    private func startFileMonitoring() {
        fileMonitorTimer?.invalidate()
        fileMonitorTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollExternalChanges()
            }
        }
    }

    private func pollExternalChanges() {
        let currentDocuments = documents

        for document in currentDocuments {
            guard let fileURL = document.fileURL else {
                continue
            }

            let currentFingerprint = DiskFingerprint.capture(for: fileURL)

            guard let currentFingerprint else {
                continue
            }

            if !currentFingerprint.isReachable {
                updateDocument(id: document.id) { updatedDocument in
                    updatedDocument.fileMissingOnDisk = true
                    updatedDocument.hasExternalChanges = true
                    updatedDocument.statusMessage = "File missing on disk"
                }
                continue
            }

            if let lastKnownFingerprint = document.lastKnownDiskFingerprint, currentFingerprint != lastKnownFingerprint {
                if document.followModeEnabled {
                    reloadDocumentFromDisk(id: document.id, preserveSelection: false, announce: "Followed external changes")
                } else if document.isDirty {
                    updateDocument(id: document.id) { updatedDocument in
                        updatedDocument.hasExternalChanges = true
                        updatedDocument.fileMissingOnDisk = false
                        updatedDocument.statusMessage = "Changed outside ForgeText"
                    }
                } else {
                    reloadDocumentFromDisk(id: document.id, preserveSelection: true, announce: "Reloaded external changes")
                }
            }
        }
    }

    private func reloadDocumentFromDisk(id: UUID, preserveSelection: Bool, announce: String) {
        guard let document = document(withID: id), let fileURL = document.fileURL else {
            return
        }

        do {
            let file = try TextFileCodec.open(from: fileURL)
            invalidateGitInsightState(for: id, clearLineDecorations: true)

            updateDocument(id: id) { updatedDocument in
                let restoredSelection: NSRange
                if updatedDocument.followModeEnabled {
                    let textLength = (file.text as NSString).length
                    restoredSelection = NSRange(location: textLength, length: 0)
                } else if preserveSelection {
                    restoredSelection = NSRange(location: min(document.selectedRange.location, (file.text as NSString).length), length: 0)
                } else {
                    restoredSelection = NSRange(location: 0, length: 0)
                }

                updatedDocument.text = file.text
                updatedDocument.encoding = file.encoding
                updatedDocument.includesByteOrderMark = file.includesByteOrderMark
                updatedDocument.lineEnding = file.lineEnding
                updatedDocument.selectedRange = restoredSelection
                updatedDocument.isDirty = false
                updatedDocument.lastSavedText = file.text
                updatedDocument.hasExternalChanges = false
                updatedDocument.fileMissingOnDisk = false
                updatedDocument.hasRecoveredDraft = false
                updatedDocument.lastKnownDiskFingerprint = DiskFingerprint.capture(for: fileURL)
                updatedDocument.lastSavedAt = Date()
                updatedDocument.statusMessage = announce
                updatedDocument.isReadOnly = file.isReadOnly
                updatedDocument.isPartialPreview = file.isPartialPreview
                updatedDocument.fileSize = file.fileSize
                updatedDocument.presentationMode = file.presentationMode == .binaryHex ? .binaryHex : updatedDocument.presentationMode
                updatedDocument.refreshLanguageIfNeeded()
                updatedDocument.syncPresentationMode()
                recomputeFindState(for: &updatedDocument)
            }

            RecoveryService.deleteSnapshot(for: id)
            refreshDocumentDiagnostics(for: id)
        } catch {
            present(error: error, title: "Couldn’t Reload File")
        }
    }

    private func recomputeFindState(for document: inout EditorDocument) {
        let result = TextSearchService.search(
            in: document.text,
            query: document.findState.query,
            options: searchOptions(for: document)
        )

        document.findState.matchRanges = result.ranges
        document.findState.errorMessage = result.errorMessage

        if let currentSelectionMatch = result.ranges.firstIndex(where: { $0 == document.selectedRange }) {
            document.findState.currentMatchIndex = currentSelectionMatch
        } else if result.ranges.isEmpty {
            document.findState.currentMatchIndex = nil
        } else {
            document.findState.currentMatchIndex = 0
        }
    }

    private func moveToMatch(step: Int) {
        guard let selectedDocumentID else {
            return
        }

        updateDocument(id: selectedDocumentID) { document in
            guard !document.findState.matchRanges.isEmpty else {
                return
            }

            let currentIndex = document.findState.currentMatchIndex ?? (step < 0 ? document.findState.matchRanges.count : -1)
            let count = document.findState.matchRanges.count
            let nextIndex = (currentIndex + step + count) % count
            document.findState.currentMatchIndex = nextIndex
            document.selectedRange = document.findState.matchRanges[nextIndex]
        }
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                self?.performAutosaveCycle()
            }
        }
    }

    private func performAutosaveCycle() {
        let dirtyDocuments = documents.filter { $0.isDirty && !$0.isReadOnly }

        for document in dirtyDocuments {
            if settings.autosaveToDisk, let fileURL = document.fileURL {
                saveDocument(id: document.id, to: fileURL, initiatedByAutosave: true)
            } else if settings.autosaveToDisk, document.isRemote {
                saveRemoteDocument(id: document.id)
            } else {
                RecoveryService.saveSnapshot(for: document)
                updateDocument(id: document.id) { updatedDocument in
                    updatedDocument.statusMessage = "Recovery snapshot updated"
                    updatedDocument.hasRecoveredDraft = true
                }
            }
        }
    }

    private func scheduleSessionSave() {
        sessionSaveTask?.cancel()
        sessionSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            await MainActor.run {
                self?.persistSession()
            }
        }
    }

    private func persistSession() {
        let openFiles = documents.compactMap(\.fileURL)
        let selectedFile = selectedDocument?.fileURL
        let openRemoteSpecs = documents.compactMap { $0.remoteReference?.spec }
        let selectedRemoteSpec = selectedDocument?.remoteReference?.spec
        SessionStore.save(
            openFiles: openFiles,
            openRemoteSpecs: openRemoteSpecs,
            recentFiles: recentFiles,
            recentRemoteSpecs: recentRemoteLocations.map(\.spec),
            selectedFile: selectedFile,
            selectedRemoteSpec: selectedRemoteSpec,
            workspaceRoot: projectSearchState.rootURL,
            workspaceRoots: workspaceRootURLs,
            activeWorkspaceRoot: activeWorkspaceURL,
            workspaceFileURL: workspacePlatformState.workspaceFilePath.map(URL.init(fileURLWithPath:)),
            selectedProfileID: workspacePlatformState.selectedProfileID
        )
        AppSettingsStore.save(settings)
    }

    private func recordRecentFile(_ url: URL) {
        let standardizedURL = url.standardizedFileURL
        recentFiles.removeAll { $0.standardizedFileURL == standardizedURL }
        recentFiles.insert(standardizedURL, at: 0)
        recentFiles = Array(recentFiles.prefix(20))
        scheduleSessionSave()
    }

    private func recordRecentRemote(_ reference: RemoteFileReference?) {
        guard let reference else {
            return
        }

        recentRemoteLocations.removeAll { $0.spec == reference.spec }
        recentRemoteLocations.insert(reference, at: 0)
        recentRemoteLocations = Array(recentRemoteLocations.prefix(20))
        scheduleSessionSave()
    }

    func processLaunchArgumentsIfNeeded() {
        guard !processedLaunchArguments else {
            return
        }

        processedLaunchArguments = true
        let plan = LaunchCommandService.parse(arguments: Array(CommandLine.arguments.dropFirst()))

        if let workspaceFileURL = plan.workspaceFileURL {
            loadWorkspaceFile(at: workspaceFileURL)
        }

        if let profileName = plan.profileName,
           let profile = settings.profiles.first(where: { $0.name.caseInsensitiveCompare(profileName) == .orderedSame }) {
            applyWorkspaceProfile(profile)
        }

        if plan.fileURLs.isEmpty == false {
            openDocuments(at: plan.fileURLs)
        }

        if let lineTarget = plan.lineTarget {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 200_000_000)
                if let targetDocument = documents.first(where: { $0.fileURL?.standardizedFileURL == lineTarget.fileURL.standardizedFileURL }) {
                    goToLine(lineTarget.lineNumber, in: targetDocument.id)
                }
            }
        }

        if let diffRequest = plan.diffRequest {
            do {
                let left = try TextFileCodec.open(from: diffRequest.leftURL)
                let right = try TextFileCodec.open(from: diffRequest.rightURL)
                let lines = DocumentComparisonService.compare(left: left.text, right: right.text)
                comparisonState = DocumentComparisonState(
                    title: "CLI Compare",
                    leftTitle: diffRequest.leftURL.lastPathComponent,
                    rightTitle: diffRequest.rightURL.lastPathComponent,
                    lines: lines,
                    changedLineCount: lines.filter { $0.kind != .unchanged }.count
                )
            } catch {
                present(error: error, title: "Couldn’t Open Diff Files")
            }
        }
    }

    func loadWorkspaceFile(at url: URL) {
        do {
            let descriptor = try WorkspacePlatformService.loadWorkspace(from: url)
            setWorkspaceRoots(
                descriptor.rootURLs,
                activeRoot: descriptor.activeRootURL,
                workspaceFileURL: descriptor.workspaceFileURL,
                workspaceName: descriptor.name,
                selectedProfileID: descriptor.selectedProfileID
            )
            if let profileID = descriptor.selectedProfileID,
               let profile = settings.profiles.first(where: { $0.id == profileID }) {
                applyWorkspaceProfile(profile)
            }
            workspacePlatformState.lastStatusMessage = "Loaded workspace \(descriptor.name)"
            if documents.isEmpty, let landingFileURL = descriptor.activeRootURL.flatMap(preferredWorkspaceLandingFile(in:)) {
                openDocuments(at: [landingFileURL])
            } else {
                refreshPluginWorkspaceState()
            }
        } catch {
            present(error: error, title: "Couldn’t Open Workspace")
        }
    }

    func saveWorkspaceFile(to url: URL) {
        do {
            let descriptor = WorkspacePlatformService.descriptor(
                name: workspacePlatformState.workspaceName,
                roots: workspaceRootURLs,
                activeRoot: activeWorkspaceURL,
                workspaceFileURL: url,
                selectedProfileID: workspacePlatformState.selectedProfileID
            )
            try WorkspacePlatformService.saveWorkspace(descriptor, to: url)
            setWorkspaceRoots(
                descriptor.rootURLs,
                activeRoot: descriptor.activeRootURL,
                workspaceFileURL: descriptor.workspaceFileURL,
                workspaceName: descriptor.name,
                selectedProfileID: descriptor.selectedProfileID
            )
            workspacePlatformState.lastStatusMessage = "Saved workspace file"
        } catch {
            present(error: error, title: "Couldn’t Save Workspace")
        }
    }

    func setRemoteExecutionMode(_ mode: RemoteExecutionMode) {
        remoteWorkspaceState.executionMode = mode
        checkRemoteAgent()
    }

    func checkRemoteAgent() {
        guard let connection = currentRemoteConnection else {
            remoteWorkspaceState.agentStatus = nil
            return
        }

        guard remoteWorkspaceState.executionMode == .remoteAgent else {
            remoteWorkspaceState.agentStatus = RemoteAgentStatus.unavailable(connection: connection, installPath: RemoteAgentService.installPath)
            return
        }

        Task.detached(priority: .utility) {
            let status = RemoteAgentService.status(connection: connection)
            await MainActor.run {
                self.remoteWorkspaceState.agentStatus = status
            }
        }
    }

    func installRemoteAgent() {
        guard ensureTrustedWorkspace(for: "remote agent installation") else {
            return
        }

        guard let connection = currentRemoteConnection else {
            alertContext = AlertContext(title: "Remote Connection Needed", message: "Choose a remote file or enter a remote location before installing the agent.")
            return
        }

        Task.detached(priority: .userInitiated) {
            do {
                let status = try RemoteAgentService.install(on: connection)
                await MainActor.run {
                    self.remoteWorkspaceState.agentStatus = status
                    self.remoteWorkspaceState.statusMessage = "Installed remote agent on \(connection)"
                }
            } catch {
                await MainActor.run {
                    self.present(error: error, title: "Couldn’t Install Remote Agent")
                }
            }
        }
    }

    func selectGitConflictFile(_ file: GitChangedFile) {
        gitPanelState.selectedConflictFileID = file.id
        gitPanelState.conflictSections = file.isConflicted ? GitConflictService.sections(from: file.absoluteURL) : []
    }

    func resolveSelectedGitConflict(using strategy: GitConflictResolutionStrategy) {
        guard let selectedID = gitPanelState.selectedConflictFileID,
              let file = gitPanelState.changedFiles.first(where: { $0.id == selectedID })
        else {
            return
        }

        do {
            let text = try String(contentsOf: file.absoluteURL)
            let resolvedText = GitConflictService.resolveAllConflicts(in: text, strategy: strategy)
            try resolvedText.write(to: file.absoluteURL, atomically: true, encoding: .utf8)
            gitPanelState.lastOperationMessage = "Resolved conflicts using \(strategy.displayName.lowercased()) blocks"
            refreshGitWorkbench()
            openDocuments(at: [file.absoluteURL])
        } catch {
            present(error: error, title: "Couldn’t Resolve Conflicts")
        }
    }

    private var currentRemoteConnection: String? {
        selectedDocument?.remoteReference?.connection
            ?? RemoteFileReference.parse(remoteLocationDraft)?.connection
            ?? recentRemoteLocations.first?.connection
    }

    private func ensureTrustedWorkspace(for feature: String) -> Bool {
        guard workspaceTrustMode == .restricted, !workspaceRootURLs.isEmpty else {
            return true
        }

        alertContext = AlertContext(
            title: "Workspace Is Restricted",
            message: "Trust this workspace in Workspace Center before running \(feature). Restricted mode keeps commands, tasks, AI, and external plugins safer by default."
        )
        return false
    }

    private func setWorkspaceRoots(
        _ roots: [URL],
        activeRoot: URL?,
        workspaceFileURL: URL? = nil,
        workspaceName: String? = nil,
        selectedProfileID: UUID? = nil
    ) {
        let descriptor = WorkspacePlatformService.descriptor(
            name: workspaceName ?? workspacePlatformState.workspaceName,
            roots: roots,
            activeRoot: activeRoot,
            workspaceFileURL: workspaceFileURL,
            selectedProfileID: selectedProfileID
        )

        workspacePlatformState.workspaceName = descriptor.name
        workspacePlatformState.rootPaths = descriptor.rootURLs.map(\.path)
        workspacePlatformState.activeRootPath = descriptor.activeRootURL?.path
        workspacePlatformState.workspaceFilePath = descriptor.workspaceFileURL?.path
        workspacePlatformState.selectedProfileID = descriptor.selectedProfileID
        projectSearchState.rootURL = descriptor.activeRootURL ?? descriptor.rootURLs.first
        workspaceExplorerState.selectedRootPath = descriptor.activeRootURL?.path
        invalidateAllGitInsightState()
        scheduleSessionSave()
    }

    private func refreshWorkspacePlatformState() {
        let roots = workspaceRootURLs
        workspacePlatformState.rootPaths = roots.map(\.path)
        workspacePlatformState.activeRootPath = activeWorkspaceURL?.path
        workspacePlatformState.workspaceName = workspacePlatformState.workspaceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? WorkspacePlatformService.preferredWorkspaceName(for: roots)
            : workspacePlatformState.workspaceName
    }

    private func openRestoredRemoteDocument(_ spec: String) {
        let executionMode = remoteWorkspaceState.executionMode
        Task.detached(priority: .utility) {
            do {
                let document = try RemoteFileService.open(spec: spec, mode: executionMode)
                await MainActor.run {
                    guard !self.documents.contains(where: { $0.remoteReference?.spec == spec }) else {
                        return
                    }

                    self.documents.append(document)
                    self.recordRecentRemote(document.remoteReference)
                    self.refreshPluginWorkspaceState()
                    self.refreshDocumentDiagnostics(for: document.id)
                }
            } catch {
                await MainActor.run {
                    self.present(error: error, title: "Couldn’t Restore Remote File")
                }
            }
        }
    }

    private func updateDocument(id: UUID, mutate: (inout EditorDocument) -> Void) {
        guard let index = documents.firstIndex(where: { $0.id == id }) else {
            return
        }

        var updatedDocuments = documents
        mutate(&updatedDocuments[index])
        documents = updatedDocuments
        scheduleSessionSave()
    }

    private func document(withID id: UUID) -> EditorDocument? {
        documents.first { $0.id == id }
    }

    private func gitBlameCacheKey(for documentID: UUID, lineNumber: Int) -> String {
        "\(documentID.uuidString)-\(lineNumber)"
    }

    private func cancelGitLineDecorationRefresh(for documentID: UUID, clearCache: Bool) {
        gitLineDecorationTasks[documentID]?.cancel()
        gitLineDecorationTasks[documentID] = nil

        if clearCache {
            gitLineDecorationsByDocumentID[documentID] = nil
        }
    }

    private func invalidateGitInsightState(for documentID: UUID, clearLineDecorations: Bool) {
        cancelGitLineDecorationRefresh(for: documentID, clearCache: clearLineDecorations)
        gitBlameCache = gitBlameCache.filter { !$0.key.hasPrefix(documentID.uuidString) }
        for key in Array(gitBlameTasks.keys).filter({ $0.hasPrefix(documentID.uuidString) }) {
            gitBlameTasks[key]?.cancel()
            gitBlameTasks[key] = nil
        }
    }

    private func invalidateAllGitInsightState() {
        for documentID in Array(gitLineDecorationTasks.keys) {
            cancelGitLineDecorationRefresh(for: documentID, clearCache: true)
        }
        gitLineDecorationsByDocumentID.removeAll()

        for key in Array(gitBlameTasks.keys) {
            gitBlameTasks[key]?.cancel()
            gitBlameTasks[key] = nil
        }
        gitBlameCache.removeAll()
    }

    private func nextUntitledName() -> String {
        defer { untitledCounter += 1 }
        return untitledCounter == 1 ? "Untitled" : "Untitled \(untitledCounter)"
    }

    private func requestEditorFocus() {
        editorFocusToken = UUID()
    }

    private func activateWorkspace(at rootURL: URL, statusMessage: String, openPreferredFile: Bool) {
        let standardizedRoot = rootURL.standardizedFileURL
        setWorkspaceRoots([standardizedRoot], activeRoot: standardizedRoot, workspaceName: standardizedRoot.lastPathComponent)
        projectSearchState.statusMessage = statusMessage

        if openPreferredFile, let landingFileURL = preferredWorkspaceLandingFile(in: standardizedRoot) {
            openDocuments(at: [landingFileURL])
        } else {
            refreshPluginWorkspaceState()
            scheduleSessionSave()
        }
    }

    private func refreshPluginWorkspaceState(showNoGitAlert: Bool = false) {
        pluginCatalog = PluginHostService.installedPlugins(workspaceRoots: workspaceRootURLs)
        let externalPluginTasks = enabledPlugins.flatMap(\.tasks)
        pluginTaskState.tasks = WorkspaceTaskService.detectTasks(rootURLs: workspaceRootURLs) + externalPluginTasks

        if let selectedTaskID = pluginTaskState.selectedTaskID,
           pluginTaskState.tasks.contains(where: { $0.id == selectedTaskID }) {
            // keep current selection
        } else {
            pluginTaskState.selectedTaskID = pluginTaskState.tasks.first?.id
        }

        if let selectedTestTaskID = testExplorerState.selectedTaskID,
           availableTestTasks.contains(where: { $0.id == selectedTestTaskID }) {
            // keep current selection
        } else {
            testExplorerState.selectedTaskID = availableTestTasks.first?.id
        }

        refreshGitWorkbench(showNoRepositoryAlert: showNoGitAlert)
        refreshWorkspaceExplorer()
        refreshWorkspacePlatformState()
    }

    private func runWorkspaceTask(_ task: EditorPluginTask, enableCoverage: Bool = false) {
        guard ensureTrustedWorkspace(for: "workspace tasks") else {
            return
        }
        pluginTaskState.selectedTaskID = task.id
        showingTaskRunner = true
        let commandDescription = enableCoverage ? "\(task.commandDescription) [coverage]" : task.commandDescription

        pluginTaskState.lastRun = PluginTaskRun(
            taskID: task.id,
            taskTitle: task.title,
            commandDescription: commandDescription,
            startedAt: Date(),
            output: "Running \(commandDescription)...",
            status: .running
        )

        let workspaceRoot = activeWorkspaceURL
        let currentDocument = selectedDocument

        Task.detached(priority: .userInitiated) {
            let run = await WorkspaceTaskService.run(
                task,
                workspaceRoot: workspaceRoot,
                currentDocument: currentDocument,
                enableCoverage: enableCoverage
            )
            let problems = ProblemMatcherService.parseProblems(from: run.output, source: task.title)
            let coverageSummary = TestCoverageService.summary(from: run.output)

            await MainActor.run {
                self.pluginTaskState.lastRun = run
                self.pluginTaskState.lastCoverageSummary = coverageSummary
                self.problemsPanelState.records = problems
                self.problemsPanelState.sourceDescription = task.title
                self.problemsPanelState.lastUpdatedAt = Date()
                if task.role == .test {
                    self.testExplorerState.lastRun = run
                    self.testExplorerState.selectedTaskID = task.id
                    self.testExplorerState.coverageSummary = coverageSummary
                }
                if run.status == .failed {
                    self.alertContext = AlertContext(
                        title: "Task Failed",
                        message: "\(task.title) exited unsuccessfully. Review the task runner output for details."
                    )
                }
            }
        }
    }

    private func paletteAction(for action: EditorPluginCommandAction) -> PaletteAction {
        switch action {
        case .showTaskRunner:
            return .showTaskRunner
        case .showSnippetLibrary:
            return .showSnippetLibrary
        case .runDiagnostics:
            return .runPluginDiagnostics
        case .formatDocument:
            return .formatDocument
        case let .runPrimaryTask(role):
            return .runPrimaryWorkspaceTask(role)
        case .refreshGitStatus:
            return .refreshGitStatus
        case .compareWithGitHead:
            return .compareWithGitHead
        }
    }

    private func runGitOperation(
        successMessage: String,
        operation: () throws -> Void,
        onSuccess: (() -> Void)? = nil
    ) {
        gitPanelState.isBusy = true
        do {
            try operation()
            onSuccess?()
            gitPanelState.lastOperationMessage = successMessage
            gitPanelState.isBusy = false
            refreshPluginWorkspaceState()
        } catch {
            gitPanelState.isBusy = false
            gitPanelState.lastOperationMessage = error.localizedDescription
            present(error: error, title: "Git Operation Failed")
        }
    }

    private func ensureAIProviderSelection() {
        if settings.preferredAIProviderID == nil {
            settings.preferredAIProviderID = settings.aiProviders.first(where: \.isEnabled)?.id
            AppSettingsStore.save(settings)
        }
    }

    private func ensureAISession() {
        if aiWorkbenchState.sessions.isEmpty {
            let session = AIChatSession(title: "New Chat")
            aiWorkbenchState.sessions = [session]
            aiWorkbenchState.selectedSessionID = session.id
            AIConversationStore.save(aiWorkbenchState.sessions)
        } else if aiWorkbenchState.selectedSessionID == nil {
            aiWorkbenchState.selectedSessionID = aiWorkbenchState.sessions.first?.id
        }
    }

    private func updateSelectedAIProvider(_ mutate: (inout AIProviderConfiguration) -> Void) {
        guard let providerID = settings.preferredAIProviderID,
              let index = settings.aiProviders.firstIndex(where: { $0.id == providerID }) else {
            return
        }

        mutate(&settings.aiProviders[index])
        AppSettingsStore.save(settings)
    }

    private func recordAIInteraction(prompt: String, response: String, provider: AIProviderConfiguration) {
        ensureAISession()
        guard let sessionID = aiWorkbenchState.selectedSessionID,
              let index = aiWorkbenchState.sessions.firstIndex(where: { $0.id == sessionID }) else {
            return
        }

        var session = aiWorkbenchState.sessions[index]
        if session.messages.isEmpty {
            session.title = String(prompt.prefix(48))
        }

        session.messages.append(
            AIChatMessage(role: .user, content: prompt, providerName: provider.name, model: provider.model)
        )
        session.messages.append(
            AIChatMessage(role: .assistant, content: response, providerName: provider.name, model: provider.model)
        )
        session.updatedAt = Date()

        aiWorkbenchState.sessions[index] = session
        aiWorkbenchState.sessions.sort { $0.updatedAt > $1.updatedAt }
        aiWorkbenchState.selectedSessionID = session.id
        AIConversationStore.save(aiWorkbenchState.sessions)
    }

    private func selectedText(in document: EditorDocument) -> String? {
        let safeRange = NSIntersectionRange(document.selectedRange, NSRange(location: 0, length: (document.text as NSString).length))
        guard safeRange.length > 0 else {
            return nil
        }

        return (document.text as NSString).substring(with: safeRange)
    }

    private func insertText(_ text: String, replacingSelection: Bool, in documentID: UUID) {
        updateDocument(id: documentID) { updatedDocument in
            guard !updatedDocument.isReadOnly else {
                return
            }

            let fullText = updatedDocument.text as NSString
            let safeRange = NSIntersectionRange(updatedDocument.selectedRange, NSRange(location: 0, length: fullText.length))
            let targetRange = replacingSelection ? safeRange : NSRange(location: safeRange.location + safeRange.length, length: 0)
            let updatedText = fullText.replacingCharacters(in: targetRange, with: text)
            let cursorLocation = targetRange.location + (text as NSString).length

            updatedDocument.text = updatedText
            updatedDocument.selectedRange = NSRange(location: cursorLocation, length: 0)
            updatedDocument.syncDirtyState()
            updatedDocument.statusMessage = replacingSelection ? "Replaced selection from AI response" : "Inserted AI response"
            recomputeFindState(for: &updatedDocument)
        }

        requestEditorFocus()
        scheduleAutosave()
        refreshDocumentDiagnostics(for: documentID)
    }

    private func preferredWorkspaceLandingFile(in rootURL: URL) -> URL? {
        let candidateNames = [
            "README.md",
            "README.markdown",
            "README.mdown",
            "README.txt",
            "README",
        ]

        for name in candidateNames {
            let fileURL = rootURL.appendingPathComponent(name)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                return fileURL
            }
        }

        return nil
    }

    private func refreshDocumentDiagnostics(for id: UUID) {
        guard let document = document(withID: id), !document.isLargeFileMode else {
            documentDiagnosticsByID[id] = []
            return
        }

        gitBlameCache = gitBlameCache.filter { !$0.key.hasPrefix(id.uuidString) }
        documentDiagnosticsByID[id] = PluginDiagnosticsService.diagnostics(for: document)
    }

    private func refreshAllDocumentDiagnostics() {
        for document in documents {
            refreshDocumentDiagnostics(for: document.id)
        }
    }

    private func structuredToggleTitle(for document: EditorDocument) -> String {
        guard let structuredPresentationMode = document.availableStructuredPresentationMode else {
            return "Show Raw Text"
        }

        return document.presentationMode == structuredPresentationMode ? "Show Raw Text" : "Show \(structuredPresentationMode.displayName)"
    }

    private func structuredToggleSubtitle(for document: EditorDocument) -> String {
        guard let structuredPresentationMode = document.availableStructuredPresentationMode else {
            return "Switch back to the text editor"
        }

        switch structuredPresentationMode {
        case .structuredTable:
            return "Render tabular data as a structured grid"
        case .structuredJSON:
            return "Inspect JSON as a searchable tree"
        case .logExplorer:
            return "Explore log events with filters and detail cards"
        case .structuredConfig:
            return "Inspect configuration sections and key-value pairs"
        case .archiveBrowser:
            return "Browse archive contents without extracting them"
        case .httpRequest:
            return "Run and inspect HTTP requests from the current document"
        case .editor, .readOnlyPreview, .binaryHex:
            return "Switch document presentation"
        }
    }

    private func structuredToggleSymbol(for document: EditorDocument) -> String {
        guard let structuredPresentationMode = document.availableStructuredPresentationMode else {
            return "doc.text"
        }

        return document.presentationMode == structuredPresentationMode ? "doc.text" : structuredPresentationMode.symbolName
    }

    private func searchOptions(for document: EditorDocument) -> SearchOptions {
        SearchOptions(
            isCaseSensitive: document.findState.isCaseSensitive,
            usesRegularExpression: document.findState.usesRegularExpression
        )
    }

    private func formatSelectedJSON(prettyPrinted: Bool) {
        guard let selectedDocumentID, let document = selectedDocument else {
            return
        }

        guard let data = document.text.data(using: .utf8) else {
            alertContext = AlertContext(title: "Couldn’t Format JSON", message: "The current document isn’t valid UTF-8 text.")
            return
        }

        do {
            let object = try JSONSerialization.jsonObject(with: data)
            let options: JSONSerialization.WritingOptions = prettyPrinted ? [.prettyPrinted, .sortedKeys] : [.sortedKeys]
            let formattedData = try JSONSerialization.data(withJSONObject: object, options: options)
            guard let formattedText = String(data: formattedData, encoding: .utf8) else {
                throw TextFileCodec.CodecError.unableToDecode
            }

            updateDocument(id: selectedDocumentID) { updatedDocument in
                updatedDocument.text = formattedText
                updatedDocument.selectedRange = NSRange(location: 0, length: 0)
                updatedDocument.syncDirtyState()
                updatedDocument.statusMessage = prettyPrinted ? "Pretty-printed JSON" : "Minified JSON"
                recomputeFindState(for: &updatedDocument)
            }

            scheduleAutosave()
        } catch {
            present(error: error, title: "Couldn’t Format JSON")
        }
    }

    private static func rangeForLine(_ lineNumber: Int, in text: String) -> NSRange? {
        guard lineNumber > 0 else {
            return nil
        }

        let nsText = text as NSString

        if lineNumber == 1 {
            return NSRange(location: 0, length: 0)
        }

        var currentLine = 1
        var index = 0

        while index < nsText.length {
            let lineRange = nsText.lineRange(for: NSRange(location: index, length: 0))
            index = NSMaxRange(lineRange)
            currentLine += 1

            if currentLine == lineNumber {
                return NSRange(location: min(index, nsText.length), length: 0)
            }
        }

        return lineNumber == currentLine ? NSRange(location: nsText.length, length: 0) : nil
    }

    private static func rangeForLineColumn(_ lineNumber: Int, column: Int, length: Int, in text: String) -> NSRange {
        guard let lineStart = rangeForLine(lineNumber, in: text) else {
            return NSRange(location: 0, length: 0)
        }

        let nsText = text as NSString
        let lineRange = nsText.lineRange(for: lineStart)
        let clampedColumn = max(column - 1, 0)
        let location = min(lineRange.location + clampedColumn, NSMaxRange(lineRange) - 1)
        return NSRange(location: max(location, 0), length: max(length, 0))
    }

    private static func fuzzyScore(query: String, candidate: String) -> Int? {
        let normalizedQuery = query.lowercased()
        let normalizedCandidate = candidate.lowercased()

        if normalizedCandidate.contains(normalizedQuery) {
            return 10_000 - normalizedCandidate.count
        }

        var score = 0
        var queryIndex = normalizedQuery.startIndex

        for character in normalizedCandidate where queryIndex < normalizedQuery.endIndex {
            if character == normalizedQuery[queryIndex] {
                score += 10
                queryIndex = normalizedQuery.index(after: queryIndex)
            } else {
                score -= 1
            }
        }

        return queryIndex == normalizedQuery.endIndex ? score : nil
    }

    private func present(error: Error, title: String) {
        let message: String

        if let localizedError = error as? LocalizedError, let description = localizedError.errorDescription {
            message = description
        } else {
            message = error.localizedDescription
        }

        alertContext = AlertContext(title: title, message: message)
    }
}
