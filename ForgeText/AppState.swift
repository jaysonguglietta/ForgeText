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
        case openRemote
        case openRemoteSpec(String)
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
        case exportSettings
        case importSettings
        case toggleWrapLines
        case toggleOutline
        case toggleBreadcrumbs
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
    @Published var showingRemoteOpen = false
    @Published var showingWorkspaceSessions = false
    @Published var showingKeyboardShortcuts = false
    @Published var editorFocusToken = UUID()
    @Published var projectSearchState = ProjectSearchState()
    @Published var comparisonState: DocumentComparisonState?
    @Published var remoteLocationDraft = ""
    @Published var secondaryPaneMode: WorkspaceSecondaryPaneMode = .off
    @Published var secondaryDocumentID: UUID?

    private var pendingAction: PendingAction?
    private var autosaveTask: Task<Void, Never>?
    private var sessionSaveTask: Task<Void, Never>?
    private var projectSearchTask: Task<Void, Never>?
    private var fileMonitorTimer: Timer?
    private var untitledCounter = 1
    private let hadUncleanShutdown: Bool

    init() {
        settings = AppSettingsStore.load()
        workspaceSessions = WorkspaceSessionStore.load()
        hadUncleanShutdown = CrashRecoveryMonitor.markLaunch()
        restoreWorkspace()
        startFileMonitoring()

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

    func newDocument() {
        let document = EditorDocument.untitled(named: nextUntitledName())
        documents.append(document)
        selectedDocumentID = document.id
        requestEditorFocus()
        scheduleSessionSave()
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

    func openRemotePanel() {
        remoteLocationDraft = selectedDocument?.remoteReference?.spec ?? recentRemoteLocations.first?.spec ?? ""
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

        Task.detached(priority: .userInitiated) {
            do {
                let document = try RemoteFileService.open(spec: spec)
                await MainActor.run {
                    self.documents.append(document)
                    self.selectedDocumentID = document.id
                    self.recordRecentRemote(document.remoteReference)
                    self.requestEditorFocus()
                    self.scheduleSessionSave()
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
    }

    func selectDocument(_ id: UUID) {
        selectedDocumentID = id
        requestEditorFocus()
        scheduleSessionSave()
    }

    func selectNextDocument() {
        guard !documents.isEmpty, let selectedDocumentIndex else {
            return
        }

        let nextIndex = (selectedDocumentIndex + 1) % documents.count
        selectedDocumentID = documents[nextIndex].id
        requestEditorFocus()
        scheduleSessionSave()
    }

    func selectPreviousDocument() {
        guard !documents.isEmpty, let selectedDocumentIndex else {
            return
        }

        let previousIndex = (selectedDocumentIndex - 1 + documents.count) % documents.count
        selectedDocumentID = documents[previousIndex].id
        requestEditorFocus()
        scheduleSessionSave()
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

    func toggleBreadcrumbs() {
        settings.showsBreadcrumbs.toggle()
        AppSettingsStore.save(settings)
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
        projectSearchState.rootURL = session.workspaceRootPath.map(URL.init(fileURLWithPath:))
        settings.theme = session.theme
        settings.wrapLines = session.wrapLines
        settings.fontSize = session.fontSize

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

        scheduleAutosave()
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
                self?.projectSearchState.rootURL = url
                self?.projectSearchState.statusMessage = "Search root set"
                self?.scheduleSessionSave()
            }
        }
    }

    func runProjectSearch() {
        guard let rootURL = projectSearchState.rootURL else {
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
                root: rootURL,
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
            PaletteItem(id: "openRemote", title: "Open Remote File", subtitle: "Open a document over SSH", symbolName: "network", action: .openRemote),
            PaletteItem(id: "searchFolder", title: "Search in Folder", subtitle: "Run a project-wide text search", symbolName: "magnifyingglass", action: .searchInFolder),
            PaletteItem(id: "save", title: "Save", subtitle: "Write the current document to disk", symbolName: "square.and.arrow.down", action: .saveDocument),
            PaletteItem(id: "savePrivileged", title: "Privileged Save", subtitle: "Save the current file with administrator privileges", symbolName: "lock.open.display", action: .savePrivileged),
            PaletteItem(id: "close", title: "Close Document", subtitle: "Close the active tab", symbolName: "xmark.circle", action: .closeDocument),
            PaletteItem(id: "find", title: "Find and Replace", subtitle: "Search within the current document", symbolName: "magnifyingglass", action: .showFind),
            PaletteItem(id: "line", title: "Go To Line", subtitle: "Jump directly to a line number", symbolName: "text.line.first.and.arrowtriangle.forward", action: .goToLine),
            PaletteItem(id: "nextMatch", title: "Next Match", subtitle: "Jump to the next search result", symbolName: "arrow.down.circle", action: .nextMatch),
            PaletteItem(id: "prevMatch", title: "Previous Match", subtitle: "Jump to the previous search result", symbolName: "arrow.up.circle", action: .previousMatch),
            PaletteItem(id: "comment", title: "Toggle Comment", subtitle: "Comment or uncomment the current line or selection", symbolName: "text.badge.minus", action: .toggleComment),
            PaletteItem(id: "compareSaved", title: "Compare with Saved", subtitle: "Review the current buffer against disk", symbolName: "square.split.2x1", action: .compareWithSaved),
            PaletteItem(id: "compareFile", title: "Compare with File", subtitle: "Choose another file and compare it", symbolName: "doc.on.doc", action: .compareWithFile),
            PaletteItem(id: "follow", title: "Toggle Follow Mode", subtitle: "Auto-reload changes from disk", symbolName: "arrow.triangle.2.circlepath", action: .toggleFollowMode),
            PaletteItem(id: "terminal", title: "Open in Terminal", subtitle: "Open the current file folder in Terminal", symbolName: "terminal", action: .openInTerminal),
            PaletteItem(id: "prettyJSON", title: "Pretty Print JSON", subtitle: "Format the current JSON document", symbolName: "curlybraces", action: .prettyPrintJSON),
            PaletteItem(id: "minifyJSON", title: "Minify JSON", subtitle: "Compress the current JSON document", symbolName: "curlybraces.square", action: .minifyJSON),
            PaletteItem(id: "exportSettings", title: "Export Settings", subtitle: "Save ForgeText preferences to a file", symbolName: "square.and.arrow.up", action: .exportSettings),
            PaletteItem(id: "importSettings", title: "Import Settings", subtitle: "Load ForgeText preferences from a file", symbolName: "square.and.arrow.down", action: .importSettings),
            PaletteItem(id: "wrap", title: settings.wrapLines ? "Disable Line Wrap" : "Enable Line Wrap", subtitle: "Toggle soft wrapping in the editor", symbolName: "paragraphformat", action: .toggleWrapLines),
            PaletteItem(id: "outline", title: settings.showsOutline ? "Hide Outline" : "Show Outline", subtitle: "Toggle the document outline rail", symbolName: "list.bullet.indent", action: .toggleOutline),
            PaletteItem(id: "breadcrumbs", title: settings.showsBreadcrumbs ? "Hide Breadcrumbs" : "Show Breadcrumbs", subtitle: "Toggle the workspace breadcrumb trail", symbolName: "chevron.left.slash.chevron.right", action: .toggleBreadcrumbs),
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
        case .openRemote:
            openRemotePanel()
        case let .openRemoteSpec(spec):
            openRemoteDocument(spec: spec)
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
        case .exportSettings:
            exportSettings()
        case .importSettings:
            importSettings()
        case .toggleWrapLines:
            toggleWrapLines()
        case .toggleOutline:
            toggleOutlinePanel()
        case .toggleBreadcrumbs:
            toggleBreadcrumbs()
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
    }

    private func restoreWorkspace() {
        let session = SessionStore.load()
        recentFiles = session.recentFilePaths
            .map(URL.init(fileURLWithPath:))
            .filter { FileManager.default.fileExists(atPath: $0.path) }
        recentRemoteLocations = session.recentRemoteSpecs.compactMap(RemoteFileReference.parse)
        projectSearchState.rootURL = session.workspaceRootPath.map(URL.init(fileURLWithPath:))

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
            workspaceRoot: projectSearchState.rootURL
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

    private func openRestoredRemoteDocument(_ spec: String) {
        Task.detached(priority: .utility) {
            do {
                let document = try RemoteFileService.open(spec: spec)
                await MainActor.run {
                    guard !self.documents.contains(where: { $0.remoteReference?.spec == spec }) else {
                        return
                    }

                    self.documents.append(document)
                    self.recordRecentRemote(document.remoteReference)
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

    private func nextUntitledName() -> String {
        defer { untitledCounter += 1 }
        return untitledCounter == 1 ? "Untitled" : "Untitled \(untitledCounter)"
    }

    private func requestEditorFocus() {
        editorFocusToken = UUID()
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
