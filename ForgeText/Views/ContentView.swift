import SwiftUI

struct ContentView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            DocumentSidebarView(appState: appState)
        } detail: {
            if let document = appState.selectedDocument, let metrics = appState.selectedMetrics {
                DocumentWorkspaceView(appState: appState, document: document, metrics: metrics)
            } else {
                EmptyWorkspaceView(appState: appState)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .background(RetroBackdropView())
        .sheet(isPresented: $appState.showingCommandPalette) {
            CommandPaletteView(appState: appState)
        }
        .sheet(isPresented: $appState.showingGoToLine) {
            GoToLineView(appState: appState)
        }
        .sheet(isPresented: $appState.showingCloneRepository) {
            CloneRepositoryView(appState: appState)
        }
        .sheet(isPresented: $appState.showingGitWorkbench) {
            GitWorkbenchView(appState: appState)
        }
        .sheet(isPresented: $appState.projectSearchState.isPresented) {
            ProjectSearchView(appState: appState)
        }
        .sheet(isPresented: $appState.showingRemoteOpen) {
            RemoteOpenView(appState: appState)
        }
        .sheet(isPresented: $appState.showingWorkspacePlatform) {
            WorkspacePlatformView(appState: appState)
        }
        .sheet(isPresented: $appState.showingProblemsPanel) {
            ProblemsPanelView(appState: appState)
        }
        .sheet(isPresented: $appState.showingTestExplorer) {
            TestExplorerView(appState: appState)
        }
        .sheet(isPresented: $appState.showingAIWorkbench) {
            AIWorkbenchView(appState: appState)
        }
        .sheet(isPresented: $appState.showingWorkspaceSessions) {
            WorkspaceSessionsView(appState: appState)
        }
        .sheet(isPresented: $appState.showingKeyboardShortcuts) {
            KeyboardShortcutsView()
        }
        .sheet(isPresented: $appState.showingPluginManager) {
            PluginManagerView(appState: appState)
        }
        .sheet(isPresented: $appState.showingSnippetLibrary) {
            SnippetLibraryView(appState: appState)
        }
        .sheet(isPresented: $appState.showingTaskRunner) {
            TaskRunnerView(appState: appState)
        }
        .sheet(isPresented: $appState.showingPluginDiagnostics) {
            PluginDiagnosticsView(appState: appState)
        }
        .sheet(isPresented: $appState.showingTerminalConsole) {
            TerminalConsoleView(appState: appState)
        }
        .sheet(item: $appState.comparisonState) { comparisonState in
            CompareView(state: comparisonState)
        }
        .confirmationDialog(
            "Discard unsaved changes?",
            isPresented: $appState.showingDiscardChanges,
            titleVisibility: .visible
        ) {
            Button("Discard Changes", role: .destructive) {
                appState.resolveDiscardChanges()
            }

            Button("Cancel", role: .cancel) {
                appState.cancelDiscardChanges()
            }
        } message: {
            Text("Any unsaved edits in the current document will be lost.")
        }
        .alert(item: $appState.alertContext) { context in
            Alert(
                title: Text(context.title),
                message: Text(context.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

private struct DocumentSidebarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack {
            RetroBackdropView()

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            BrandMarkView(size: 40)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("ForgeText")
                                    .font(.system(size: 24, weight: .black, design: .monospaced))
                                    .tracking(1.0)
                                    .foregroundStyle(RetroPalette.ink)

                                Text("native developer workbench :: webclass of '99")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(RetroPalette.link)
                            }

                            Spacer(minLength: 0)

                            RetroCapsuleLabel(text: "local", accent: RetroPalette.chromeCyan)
                        }

                        Text("Text, code, logs, configs, Git, tasks, and AI in one portal-era Mac editor.")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(RetroPalette.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .retroPanel(fill: RetroPalette.railFill, accent: RetroPalette.chromePink)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                        spacing: 10
                    ) {
                        sidebarAction(
                            "New",
                            systemImage: "plus.square",
                            subtitle: "Document",
                            action: appState.newDocument
                        )
                        sidebarAction(
                            "Open",
                            systemImage: "folder",
                            subtitle: "Files",
                            action: appState.openDocument
                        )
                        sidebarAction(
                            "Command",
                            systemImage: "command",
                            subtitle: "Palette",
                            action: { appState.showingCommandPalette = true }
                        )
                    }

                    sidebarSection("Open Documents") {
                        ForEach(appState.documents) { document in
                            DocumentSidebarRow(
                                document: document,
                                isSelected: appState.selectedDocumentID == document.id,
                                onSelect: { appState.selectDocument(document.id) },
                                onClose: { appState.closeDocument(id: document.id) }
                            )
                        }
                    }

                    sidebarSection("Recent Files") {
                        if appState.recentFiles.isEmpty {
                            Text("Recent files will appear here after you open or save documents.")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(RetroPalette.visited)
                                .fixedSize(horizontal: false, vertical: true)
                        } else {
                            ForEach(appState.recentFiles, id: \.path) { url in
                                Button {
                                    appState.openDocuments(at: [url])
                                } label: {
                                    fileCard(
                                        title: url.lastPathComponent,
                                        subtitle: url.path(percentEncoded: false),
                                        symbolName: "clock.arrow.circlepath"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    if !appState.recentRemoteLocations.isEmpty {
                        sidebarSection("Recent Remote") {
                            ForEach(appState.recentRemoteLocations, id: \.spec) { reference in
                                Button {
                                    appState.remoteLocationDraft = reference.spec
                                    appState.openRemoteDocument()
                                } label: {
                                    fileCard(
                                        title: reference.displayName,
                                        subtitle: reference.pathDescription,
                                        symbolName: "network"
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    sidebarSection("Workspace") {
                        Button {
                            appState.showWorkspacePlatformPanel()
                        } label: {
                            fileCard(
                                title: "Workspace Center",
                                subtitle: "\(appState.workspaceRootURLs.count) roots • \(appState.workspaceTrustMode.displayName.lowercased()) mode",
                                symbolName: "square.3.layers.3d"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open workspace center")

                        Button {
                            appState.chooseWorkspaceRoot()
                        } label: {
                            fileCard(
                                title: appState.projectSearchState.rootURL?.lastPathComponent ?? "Choose Folder",
                                subtitle: appState.projectSearchState.rootURL?.path(percentEncoded: false) ?? "Set a project root for folder search and terminal tools.",
                                symbolName: "folder.badge.gearshape"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Choose workspace root folder")

                        Button {
                            appState.showCloneRepositoryPanel()
                        } label: {
                            fileCard(
                                title: "Clone Repository",
                                subtitle: "Clone a GitHub or Git repo directly into a local workspace folder",
                                symbolName: "square.and.arrow.down.on.square"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Clone a repository into a local workspace")

                        Button {
                            appState.openRemotePanel()
                        } label: {
                            fileCard(
                                title: "Open Remote File",
                                subtitle: "Use SSH-style locations like user@host:/path/to/file",
                                symbolName: "network"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open a remote file")

                        Button {
                            appState.showWorkspaceSessionsPanel()
                        } label: {
                            fileCard(
                                title: "Workspace Sessions",
                                subtitle: "Save and reopen grouped files, remotes, and workspace settings",
                                symbolName: "square.stack.3d.up"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open workspace sessions")

                        Button {
                            appState.showingKeyboardShortcuts = true
                        } label: {
                            fileCard(
                                title: "Keyboard Shortcuts",
                                subtitle: "Quick reference for editor navigation and text commands",
                                symbolName: "keyboard"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Show keyboard shortcuts")

                        Button {
                            appState.showTerminalConsolePanel()
                        } label: {
                            fileCard(
                                title: "Embedded Terminal",
                                subtitle: "Run shell commands without leaving ForgeText",
                                symbolName: "terminal.fill"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open embedded terminal")

                        Button {
                            appState.showGitWorkbenchPanel()
                        } label: {
                            fileCard(
                                title: "Git Workbench",
                                subtitle: "Commit, push, pull, stash, and inspect repository changes",
                                symbolName: "point.topleft.down.curvedto.point.bottomright.up"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open Git workbench")

                        Button {
                            appState.showAIWorkbenchPanel()
                        } label: {
                            fileCard(
                                title: "AI Workbench",
                                subtitle: "Use different models and providers for chat, editing, and commit drafts",
                                symbolName: "sparkles.rectangle.stack"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open AI workbench")

                        Button {
                            appState.showProblemsPanelView()
                        } label: {
                            fileCard(
                                title: "Problems",
                                subtitle: "Review matched build, test, lint, and terminal problems",
                                symbolName: "exclamationmark.bubble"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open problems panel")

                        Button {
                            appState.showTestExplorerPanel()
                        } label: {
                            fileCard(
                                title: "Test Explorer",
                                subtitle: "Run detected workspace tests and inspect results",
                                symbolName: "checklist.checked"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open test explorer")
                    }

                    WorkspaceExplorerView(appState: appState)

                    sidebarSection("Plugins") {
                        Button {
                            appState.showPluginManagerPanel()
                        } label: {
                            fileCard(
                                title: "Plugin Manager",
                                subtitle: "Enable built-in IDE plugins and inspect their capabilities",
                                symbolName: "puzzlepiece.extension"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open plugin manager")

                        Button {
                            appState.showTaskRunnerPanel()
                        } label: {
                            fileCard(
                                title: "Task Runner",
                                subtitle: "Run workspace build, test, and lint commands from detected project files",
                                symbolName: "play.square.stack"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open task runner")

                        Button {
                            appState.showSnippetLibraryPanel()
                        } label: {
                            fileCard(
                                title: "Snippet Library",
                                subtitle: "Insert format-aware snippets into the current document",
                                symbolName: "text.badge.plus"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open snippet library")
                    }
                }
                .padding(16)
            }
        }
        .frame(minWidth: 292)
        .background(RetroBackdropView())
    }

    private func sidebarAction(
        _ title: String,
        systemImage: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(RetroPalette.chromeGold)
                    .frame(height: 4)

                VStack(spacing: 8) {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 34, height: 34)
                        .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromePink)

                    VStack(spacing: 2) {
                        Text(title)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(RetroPalette.ink)

                        Text(subtitle)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(RetroPalette.link)
                            .lineLimit(1)
                    }
                    .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
            }
            .frame(maxWidth: .infinity, minHeight: 86)
            .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromeBlue)
        }
        .buttonStyle(.plain)
    }

    private func fileCard(title: String, subtitle: String, symbolName: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbolName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(RetroPalette.chromePink)
                .frame(width: 26, height: 26)
                .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeTeal)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(RetroPalette.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(RetroPalette.chromeBlue.opacity(0.7))
        }
        .padding(11)
        .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeTeal)
    }

    private func sidebarSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            RetroSectionHeader(title: title, accent: RetroPalette.chromePink)
            content()
        }
    }
}

private struct DocumentSidebarRow: View {
    let document: EditorDocument
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: documentIconName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(isSelected ? RetroPalette.chromePink : RetroPalette.link)
                .frame(width: 26, height: 26)
                .retroInsetPanel(fill: RetroPalette.fieldFill, accent: isSelected ? RetroPalette.chromePink : RetroPalette.chromeTeal)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(document.displayName)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)
                        .lineLimit(1)

                    if document.isDirty {
                        RetroCapsuleLabel(text: "edit", accent: RetroPalette.warning)
                    }
                }

                Text(document.pathDescription)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
            }
            .buttonStyle(RetroIconButtonStyle(accent: isSelected ? RetroPalette.chromePink : RetroPalette.chromeTeal))
        }
        .padding(10)
        .retroPanel(
            fill: isSelected ? RetroPalette.panelFill : RetroPalette.panelFillMuted,
            accent: isSelected ? RetroPalette.chromePink : RetroPalette.chromeTeal
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(isSelected ? RetroPalette.chromeGold : Color.clear)
                .frame(width: 4)
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
    }

    private var documentIconName: String {
        if document.isRemote {
            return "network"
        }

        if document.availableStructuredPresentationMode == .archiveBrowser {
            return "archivebox"
        }

        return document.language.symbolName
    }
}

private struct DocumentWorkspaceView: View {
    @ObservedObject var appState: AppState
    let document: EditorDocument
    let metrics: EditorMetrics

    private var backgroundColor: Color {
        Color(nsColor: appState.settings.theme.backgroundColor)
    }

    private var currentLine: Int {
        metrics.cursorLine
    }

    private var breadcrumbTrail: [String] {
        DocumentOutlineService.breadcrumbTrail(for: document, cursorLine: currentLine)
    }

    private var alternatePresentationMode: DocumentPresentationMode? {
        if document.presentationMode == .binaryHex {
            return nil
        }

        if document.presentationMode == .archiveBrowser {
            return .editor
        }

        guard let structuredMode = document.availableStructuredPresentationMode else {
            return nil
        }

        return document.presentationMode == structuredMode ? .editor : structuredMode
    }

    private var secondaryDocumentCandidates: [EditorDocument] {
        appState.documents.filter { $0.id != document.id }
    }

    private var completionSession: EditorCompletionSession? {
        guard !document.isReadOnly, !document.presentationMode.isStructured else {
            return nil
        }

        return appState.completionSession(for: document)
    }

    private var pluginStatusItems: [PluginStatusItem] {
        appState.pluginStatusItems(for: document)
    }

    private var currentLineDiagnostics: [PluginDiagnostic] {
        appState.inlineDiagnostics(for: document, lineNumber: currentLine)
    }

    private var currentLineBlame: GitBlameInfo? {
        appState.gitBlame(for: document, lineNumber: currentLine)
    }

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(spacing: 0) {
                DocumentTabStripView(appState: appState)
                RetroRule()
                header

                if appState.settings.showsBreadcrumbs, !breadcrumbTrail.isEmpty {
                    RetroRule()
                    breadcrumbBar
                }

                if document.hasExternalChanges || document.fileMissingOnDisk {
                    statusBanner(
                        title: document.fileMissingOnDisk ? "File Missing on Disk" : "External Changes Detected",
                        message: document.fileMissingOnDisk
                            ? "The file is no longer available at its saved path. You can keep editing and save elsewhere."
                            : "This document changed outside ForgeText. Reload it or keep your current version.",
                        accent: document.fileMissingOnDisk ? RetroPalette.danger : RetroPalette.warning
                    ) {
                        Button("Compare") {
                            appState.showCompareAgainstSaved()
                        }

                        if !document.fileMissingOnDisk {
                            Button("Reload") {
                                appState.reloadFromExternalChange()
                            }
                        }

                        Button("Keep Mine") {
                            appState.keepCurrentVersionAfterExternalChange()
                        }
                    }
                }

                if document.isPartialPreview || document.presentationMode == .binaryHex || document.followModeEnabled || document.presentationMode == .archiveBrowser {
                    statusBanner(
                        title: bannerTitle,
                        message: bannerMessage,
                        accent: bannerAccent
                    ) {
                        if document.fileURL != nil {
                            Button(document.followModeEnabled ? "Disable Follow" : "Enable Follow") {
                                appState.toggleFollowMode()
                            }
                        }

                        if document.fileURL != nil {
                            Button("Open in Terminal") {
                                appState.openSelectedDocumentInTerminal()
                            }
                        }
                    }
                }

                if document.findState.isPresented, !document.presentationMode.isStructured {
                    RetroRule()
                    FindReplaceBar(appState: appState, document: document)
                }

                if let completionSession {
                    RetroRule()
                    PredictionStripView(session: completionSession) { suggestion in
                        appState.applyCompletion(suggestion, for: document.id)
                    }
                }

                if !currentLineDiagnostics.isEmpty || currentLineBlame != nil {
                    RetroRule()
                    editorInsightBar
                }

                RetroRule()

                workspaceArea

                RetroRule()

                StatusBarView(document: document, metrics: metrics, settings: appState.settings, pluginStatusItems: pluginStatusItems)
            }
            .padding(10)
        }
        .background(backgroundColor)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    appState.newDocument()
                } label: {
                    Label("New", systemImage: "plus.square")
                }

                Button {
                    appState.openDocument()
                } label: {
                    Label("Open", systemImage: "folder")
                }

                Button {
                    appState.openRemotePanel()
                } label: {
                    Label("Remote", systemImage: "network")
                }

                Button {
                    appState.saveDocument()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }

                Button {
                    appState.showFindReplace()
                } label: {
                    Label("Find", systemImage: "magnifyingglass")
                }

                Button {
                    appState.showProjectSearch()
                } label: {
                    Label("Search Files", systemImage: "magnifyingglass")
                }

                Button {
                    appState.showingCommandPalette = true
                } label: {
                    Label("Palette", systemImage: "command")
                }

                Button {
                    appState.showWorkspacePlatformPanel()
                } label: {
                    Label("Workspace", systemImage: "square.3.layers.3d")
                }

                Button {
                    appState.showTaskRunnerPanel()
                } label: {
                    Label("Tasks", systemImage: "play.square.stack")
                }

                Button {
                    appState.showTerminalConsolePanel()
                } label: {
                    Label("Console", systemImage: "terminal.fill")
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                BrandMarkView(size: 28)

                VStack(alignment: .leading, spacing: 6) {
                    Text(document.displayName)
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .tracking(0.8)
                        .foregroundStyle(RetroPalette.ink)

                    FlowBadgeRow {
                        if document.isRemote {
                            headerBadge("Remote", color: RetroPalette.chromeCyan)
                        }

                        if document.isDirty {
                            headerBadge("Edited", color: RetroPalette.warning)
                        }

                        if document.hasRecoveredDraft {
                            headerBadge("Recovered", color: RetroPalette.success)
                        }

                        if document.isLargeFileMode {
                            headerBadge("Large File", color: RetroPalette.chromeGold)
                        }

                        if appState.workspaceTrustMode == .restricted {
                            headerBadge("Restricted", color: RetroPalette.warning)
                        }

                        if let structuredBadge {
                            headerBadge(structuredBadge.text, color: structuredBadge.color)
                        }
                    }

                    Text(document.pathDescription)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(RetroPalette.link)
                        .textSelection(.enabled)
                }

                Spacer(minLength: 0)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    if let structuredPresentationMode = document.availableStructuredPresentationMode {
                        Button {
                            toggleStructuredPresentation(structuredPresentationMode)
                        } label: {
                            headerControl(
                                document.presentationMode == structuredPresentationMode ? "Raw Text" : structuredPresentationMode.displayName,
                                systemImage: document.presentationMode == structuredPresentationMode ? "doc.text" : structuredPresentationMode.symbolName
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    Menu {
                        ForEach(DocumentLanguage.allCases) { language in
                            Button(language.displayName) {
                                appState.setLanguage(language)
                            }
                        }
                    } label: {
                        headerControl(document.language.displayName, systemImage: document.language.symbolName)
                    }
                    .menuStyle(.borderlessButton)

                    Menu {
                        ForEach(EditorTheme.allCases) { theme in
                            Button(theme.displayName) {
                                appState.setTheme(theme)
                            }
                        }
                    } label: {
                        headerControl(appState.settings.theme.displayName, systemImage: "paintpalette")
                    }
                    .menuStyle(.borderlessButton)

                    Menu {
                        ForEach(WorkspaceSecondaryPaneMode.allCases) { mode in
                            Button(mode.displayName) {
                                appState.setSecondaryPaneMode(mode)
                            }
                        }

                        if appState.secondaryPaneMode == .secondDocument, !secondaryDocumentCandidates.isEmpty {
                            Divider()

                            ForEach(secondaryDocumentCandidates) { candidate in
                                Button(candidate.displayName) {
                                    appState.setSecondaryDocument(candidate.id)
                                }
                            }
                        }
                    } label: {
                        headerControl(splitControlTitle, systemImage: "rectangle.split.2x1")
                    }
                    .menuStyle(.borderlessButton)

                    Menu {
                        Button("Workspace Center") {
                            appState.showWorkspacePlatformPanel()
                        }

                        Divider()

                        if let gitRepositorySummary = appState.gitRepositorySummary {
                            Menu("Git Branches") {
                                ForEach(appState.availableGitBranches, id: \.self) { branch in
                                    Button(branch) {
                                        appState.switchGitBranch(branch)
                                    }
                                }
                            }

                            Button("Refresh Git Status") {
                                appState.refreshGitStatus()
                            }

                            Button("Compare with Git HEAD") {
                                appState.compareSelectedDocumentWithGitHead()
                            }
                            .disabled(document.fileURL == nil)

                            Button("Stage Current File") {
                                appState.stageSelectedFileInGit()
                            }
                            .disabled(document.fileURL == nil)

                            Divider()

                            Button("Git branch: \(gitRepositorySummary.branchName)") {}
                                .disabled(true)
                        }

                        Menu("Encoding") {
                            ForEach(String.Encoding.commonSaveEncodings, id: \.rawValue) { encoding in
                                Button(encoding.displayName) {
                                    appState.setEncoding(encoding)
                                }
                            }
                        }

                        Menu("Line Endings") {
                            ForEach(LineEnding.allCases, id: \.rawValue) { lineEnding in
                                Button(lineEnding.label) {
                                    appState.setLineEnding(lineEnding)
                                }
                            }
                        }

                        Button(document.includesByteOrderMark ? "Disable BOM" : "Enable BOM") {
                            appState.toggleByteOrderMark()
                        }
                        .disabled(!appState.canSave)

                        Divider()

                        Button(appState.settings.showsOutline ? "Hide Outline" : "Show Outline") {
                            appState.toggleOutlinePanel()
                        }

                        Button(appState.settings.showsBreadcrumbs ? "Hide Breadcrumbs" : "Show Breadcrumbs") {
                            appState.toggleBreadcrumbs()
                        }

                        Divider()

                        Button("Compare with Saved") {
                            appState.showCompareAgainstSaved()
                        }
                        .disabled(!appState.canCompareSelectedDocument)

                        Button("Workspace Sessions") {
                            appState.showWorkspaceSessionsPanel()
                        }

                        Button("Keyboard Shortcuts") {
                            appState.showingKeyboardShortcuts = true
                        }

                        Divider()

                        if let structuredPresentationMode = document.availableStructuredPresentationMode {
                            Button(document.presentationMode == structuredPresentationMode ? "Show Raw Text" : "Show \(structuredPresentationMode.displayName)") {
                                toggleStructuredPresentation(structuredPresentationMode)
                            }
                        }

                        Button(document.followModeEnabled ? "Disable Follow Mode" : "Enable Follow Mode") {
                            appState.toggleFollowMode()
                        }
                        .disabled(!appState.canFollowSelectedDocument)

                        Button("Open in Terminal") {
                            appState.openSelectedDocumentInTerminal()
                        }
                        .disabled(document.fileURL == nil && appState.projectSearchState.rootURL == nil)

                        if appState.canPrivilegedSaveSelectedDocument {
                            Button("Privileged Save") {
                                appState.saveDocumentPrivileged()
                            }
                        }
                    } label: {
                        headerControl("Document", systemImage: "slider.horizontal.3")
                    }
                    .menuStyle(.borderlessButton)

                    Button {
                        appState.showGoToLine()
                    } label: {
                        headerControl("Go to Line", systemImage: "text.line.first.and.arrowtriangle.forward")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 1)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .retroPanel(fill: RetroPalette.railFill, accent: RetroPalette.chromePink)
    }

    private var editorInsightBar: some View {
        HStack(alignment: .top, spacing: 12) {
            if let currentLineBlame {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Git Blame")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)

                    Text("\(currentLineBlame.author) · \(currentLineBlame.shortCommitHash) · \(currentLineBlame.summary)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(RetroPalette.link)
                        .lineLimit(2)
                }
            }

            if !currentLineDiagnostics.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Line Issues")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)

                    ForEach(currentLineDiagnostics) { diagnostic in
                        Text(diagnostic.message)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(diagnostic.severity == .error ? RetroPalette.danger : RetroPalette.warning)
                            .lineLimit(2)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeTeal)
    }

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(breadcrumbTrail.enumerated()), id: \.offset) { index, crumb in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(RetroPalette.chromePink)
                    }

                    Text(crumb)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeTeal)
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)
    }

    private var workspaceArea: some View {
        HSplitView {
            primaryWorkspaceArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if appState.settings.showsOutline {
                OutlinePanelView(
                    document: document,
                    currentLine: currentLine,
                    theme: appState.settings.theme,
                    onSelectLine: { lineNumber in
                        appState.goToLine(lineNumber, in: document.id)
                    }
                )
                .background(backgroundColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
    }

    @ViewBuilder
    private var primaryWorkspaceArea: some View {
        switch appState.secondaryPaneMode {
        case .off:
            documentPane(
                document: document,
                renderedMode: document.presentationMode,
                title: nil,
                isSelectedDocument: true
            )
        case .alternatePresentation:
            if let alternatePresentationMode {
                HSplitView {
                    documentPane(
                        document: document,
                        renderedMode: document.presentationMode,
                        title: paneTitle(for: document.presentationMode),
                        isSelectedDocument: true
                    )

                    documentPane(
                        document: document,
                        renderedMode: alternatePresentationMode,
                        title: paneTitle(for: alternatePresentationMode),
                        isSelectedDocument: true
                    )
                }
            } else {
                documentPane(
                    document: document,
                    renderedMode: document.presentationMode,
                    title: nil,
                    isSelectedDocument: true
                )
            }
        case .secondDocument:
            if let secondaryDocument = appState.selectedSecondaryDocument {
                HSplitView {
                    documentPane(
                        document: document,
                        renderedMode: document.presentationMode,
                        title: document.displayName,
                        isSelectedDocument: true
                    )

                    documentPane(
                        document: secondaryDocument,
                        renderedMode: secondaryDocument.presentationMode,
                        title: secondaryDocument.displayName,
                        isSelectedDocument: false
                    )
                }
            } else {
                documentPane(
                    document: document,
                    renderedMode: document.presentationMode,
                    title: nil,
                    isSelectedDocument: true
                )
            }
        }
    }

    private func paneTitle(for mode: DocumentPresentationMode) -> String {
        switch mode {
        case .editor, .readOnlyPreview:
            return "Raw Text"
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

    private func documentPane(
        document: EditorDocument,
        renderedMode: DocumentPresentationMode,
        title: String?,
        isSelectedDocument: Bool
    ) -> some View {
        let renderedDocument = withPresentationMode(document, renderedMode)

        return VStack(spacing: 0) {
            if let title {
                HStack(spacing: 10) {
                    Label(title, systemImage: renderedMode.symbolName)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)

                    Spacer(minLength: 0)

                    if !isSelectedDocument {
                        Text(renderedDocument.pathDescription)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(RetroPalette.link)
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeTeal)

                RetroRule()
            }

            documentSurface(for: renderedDocument)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id("\(renderedDocument.id.uuidString)-\(renderedMode.rawValue)")
        }
        .background(backgroundColor)
    }

    @ViewBuilder
    private func documentSurface(for document: EditorDocument) -> some View {
        switch document.presentationMode {
        case .structuredTable:
            CSVTableView(
                document: document,
                theme: appState.settings.theme,
                onShowRawText: appState.showRawTextView
            )
        case .structuredJSON:
            JSONTreeView(
                document: document,
                theme: appState.settings.theme,
                onShowRawText: appState.showRawTextView
            )
        case .logExplorer:
            LogExplorerView(
                document: document,
                theme: appState.settings.theme,
                savedFilters: appState.settings.savedLogFilters,
                onShowRawText: appState.showRawTextView,
                onToggleFollowMode: appState.toggleFollowMode,
                onSaveFilter: appState.saveCurrentLogFilter,
                onDeleteSavedFilter: appState.deleteSavedLogFilter
            )
        case .structuredConfig:
            ConfigInspectorView(
                document: document,
                theme: appState.settings.theme,
                onShowRawText: appState.showRawTextView,
                onSelectLine: { lineNumber in
                    appState.goToLine(lineNumber, in: document.id)
                }
            )
        case .archiveBrowser:
            ArchiveBrowserView(
                document: document,
                theme: appState.settings.theme
            )
        case .httpRequest:
            HTTPRequestView(
                document: document,
                theme: appState.settings.theme,
                onShowRawText: appState.showRawTextView
            )
        case .editor, .readOnlyPreview, .binaryHex:
            EditorContainerView(
                text: appState.textBinding(for: document.id),
                selectedRange: appState.selectionBinding(for: document.id),
                theme: appState.settings.theme,
                language: document.language,
                sourceURL: document.sourceURL,
                wrapLines: appState.settings.wrapLines,
                fontSize: CGFloat(appState.settings.fontSize),
                findState: document.findState,
                largeFileMode: document.isLargeFileMode,
                isEditable: !document.isReadOnly,
                focusRequestToken: appState.editorFocusToken,
                lineDecorations: appState.lineDecorations(for: document)
            )
        }
    }

    private func withPresentationMode(_ document: EditorDocument, _ mode: DocumentPresentationMode) -> EditorDocument {
        var updatedDocument = document
        updatedDocument.presentationMode = mode
        return updatedDocument
    }

    private var splitControlTitle: String {
        switch appState.secondaryPaneMode {
        case .off:
            return "Single Pane"
        case .alternatePresentation:
            return "Raw + Structured"
        case .secondDocument:
            return "Second Document"
        }
    }

    private var bannerTitle: String {
        if document.presentationMode == .archiveBrowser {
            return "Archive Browser"
        }

        if document.presentationMode == .binaryHex {
            return "Binary Hex Preview"
        }

        if document.isPartialPreview {
            return "Read-Only Preview"
        }

        return "Follow Mode"
    }

    private var bannerMessage: String {
        if document.presentationMode == .archiveBrowser {
            return "Archives open in a safe browser view so you can inspect contents without extracting them into the workspace."
        }

        if document.presentationMode == .binaryHex {
            return "ForgeText opened this file as a hex preview because it doesn’t decode cleanly as text."
        }

        if document.isPartialPreview {
            return "Large files are opened as read-only previews so the editor stays fast and safe."
        }

        return "This document automatically reloads when the file changes on disk."
    }

    private var bannerAccent: Color {
        if document.presentationMode == .archiveBrowser {
            return .indigo
        }

        return document.presentationMode == .binaryHex ? .purple : .blue
    }

    private func headerBadge(_ text: String, color: Color) -> some View {
        RetroCapsuleLabel(text: text, accent: color)
    }

    private func headerControl(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(RetroPalette.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeBlue)
    }

    private var structuredBadge: (text: String, color: Color)? {
        switch document.presentationMode {
        case .structuredTable:
            return ("Table", .blue)
        case .structuredJSON:
            return ("JSON Tree", .teal)
        case .logExplorer:
            return ("Log Explorer", .mint)
        case .structuredConfig:
            return ("Config", .green)
        case .archiveBrowser:
            return ("Archive", .indigo)
        case .httpRequest:
            return ("HTTP", .cyan)
        case .editor, .readOnlyPreview, .binaryHex:
            return nil
        }
    }

    private func toggleStructuredPresentation(_ mode: DocumentPresentationMode) {
        if document.presentationMode == mode {
            appState.showRawTextView()
        } else {
            appState.showStructuredView()
        }
    }

    private func statusBanner<Actions: View>(
        title: String,
        message: String,
        accent: Color,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RetroCapsuleLabel(text: "alert", accent: accent)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(RetroPalette.ink)
                Text(message)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                actions()
            }
            .buttonStyle(RetroActionButtonStyle(tone: .secondary))
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .retroPanel(fill: RetroPalette.panelFill, accent: accent)
    }
}

private struct PredictionStripView: View {
    let session: EditorCompletionSession
    let onSelectSuggestion: (EditorCompletionSuggestion) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Predictions")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(RetroPalette.ink)

                Text(session.prefix.isEmpty ? "Click to insert a format-aware suggestion" : "Tab accepts the first match")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(session.suggestions) { suggestion in
                        Button {
                            onSelectSuggestion(suggestion)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(suggestion.displayText)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                Text(suggestion.detail)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                            }
                            .frame(alignment: .leading)
                        }
                        .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                    }
                }
                .padding(.vertical, 1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromeTeal)
    }
}

private struct EmptyWorkspaceView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(spacing: 18) {
                BrandMarkView(size: 76)

                VStack(spacing: 8) {
                    Text("ForgeText")
                        .font(.system(size: 31, weight: .black, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(RetroPalette.ink)

                    Text("A native developer workbench for text, code, logs, configs, Git, and AI-driven editing.")
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(RetroPalette.link)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 560)
                }

                RetroSectionHeader(title: "Start Here", systemImage: "star.fill", accent: RetroPalette.chromePink)
                    .frame(maxWidth: 560)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 2), spacing: 12) {
                    heroAction("New Document", subtitle: "Start a fresh file", systemImage: "plus.square", tone: .accent) {
                        appState.newDocument()
                    }

                    heroAction("Open Files", subtitle: "Browse local files", systemImage: "folder", tone: .primary) {
                        appState.openDocument()
                    }

                    heroAction("Clone Repo", subtitle: "Pull a repository locally", systemImage: "square.and.arrow.down.on.square", tone: .primary) {
                        appState.showCloneRepositoryPanel()
                    }

                    heroAction("AI Workbench", subtitle: "Chat, edit, and draft", systemImage: "sparkles.rectangle.stack", tone: .secondary) {
                        appState.showAIWorkbenchPanel()
                    }

                    heroAction("Open Remote", subtitle: "Load over SSH-style paths", systemImage: "network", tone: .secondary) {
                        appState.openRemotePanel()
                    }

                    heroAction("Workspace Sessions", subtitle: "Resume a saved setup", systemImage: "square.stack.3d.up", tone: .secondary) {
                        appState.showWorkspaceSessionsPanel()
                    }
                }
                .frame(maxWidth: 560)
            }
            .padding(28)
            .retroPanel(fill: RetroPalette.railFill, accent: RetroPalette.chromePink)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func heroAction(
        _ title: String,
        subtitle: String,
        systemImage: String,
        tone: RetroActionButtonStyle.Tone,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .bold))
                    .frame(width: 28, height: 28)
                    .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeBlue)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                    Text(subtitle)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.primary.opacity(0.75))
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(RetroActionButtonStyle(tone: tone))
    }
}

private struct FlowBadgeRow<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                content
            }

            VStack(alignment: .leading, spacing: 6) {
                content
            }
        }
    }
}
