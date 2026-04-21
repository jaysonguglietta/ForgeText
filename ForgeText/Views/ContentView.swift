import SwiftUI

struct ContentView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Group {
            if appState.settings.focusModeEnabled {
                workspaceDetail
            } else {
                NavigationSplitView {
                    DocumentSidebarView(appState: appState)
                } detail: {
                    workspaceDetail
                }
                .navigationSplitViewStyle(.balanced)
            }
        }
        .background(RetroBackdropView())
        .retroChrome(style: appState.settings.chromeStyle, density: appState.settings.interfaceDensity)
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
        .sheet(isPresented: $appState.showingAppearancePreferences) {
            AppearancePreferencesView(appState: appState)
        }
        .sheet(isPresented: $appState.showingKeyboardShortcuts) {
            KeyboardShortcutsView()
        }
        .sheet(isPresented: $appState.showingQuickOpen) {
            QuickOpenView(appState: appState)
        }
        .sheet(isPresented: $appState.showingActivityCenter) {
            ActivityCenterView(appState: appState)
        }
        .sheet(isPresented: $appState.showingReleaseReadiness) {
            ReleaseReadinessView(appState: appState)
        }
        .sheet(isPresented: $appState.showingPerformanceHUD) {
            PerformanceHUDView(appState: appState)
        }
        .sheet(isPresented: $appState.showingAIContextCenter) {
            AIContextCenterView(appState: appState)
        }
        .sheet(isPresented: $appState.showingGitHubWorkflow) {
            GitHubWorkflowView(appState: appState)
        }
        .sheet(isPresented: $appState.showingFirstRunSetup) {
            FirstRunSetupView(appState: appState)
        }
        .sheet(isPresented: $appState.showingThemeLab) {
            ThemeLabView(appState: appState)
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

    @ViewBuilder
    private var workspaceDetail: some View {
        if let document = appState.selectedDocument, let metrics = appState.selectedMetrics {
            DocumentWorkspaceView(appState: appState, document: document, metrics: metrics)
                .id(document.id)
        } else {
            EmptyWorkspaceView(appState: appState)
        }
    }
}

private struct DocumentSidebarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack {
            RetroBackdropView()

            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 12) {
                            BrandMarkView(size: 34)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("ForgeText")
                                    .font(.system(size: 21, weight: .black, design: .monospaced))
                                    .tracking(0.7)
                                    .foregroundStyle(RetroPalette.ink)

                                Text("developer workbench :: webclass of '99")
                                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                                    .foregroundStyle(RetroPalette.link)
                            }

                            Spacer(minLength: 0)
                        }

                        Text("Text, code, logs, configs, Git, tasks, and AI in one portal-era Mac editor.")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(RetroPalette.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .retroPanel(fill: RetroPalette.railFill, accent: RetroPalette.chromeBlue)

                    LazyVGrid(
                        columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                        spacing: 8
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

                    sidebarSection("Control Center") {
                        Button {
                            appState.showQuickOpenPanel()
                        } label: {
                            fileCard(
                                title: "Quick Open",
                                subtitle: "Jump to indexed files and symbols across the workspace",
                                symbolName: "doc.text.magnifyingglass"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open quick open")

                        Button {
                            appState.showActivityCenterPanel()
                        } label: {
                            fileCard(
                                title: "Activity Center",
                                subtitle: "Review recent editor, index, release, and diagnostic events",
                                symbolName: "list.bullet.rectangle.portrait"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open activity center")

                        Button {
                            appState.showAIContextCenterPanel()
                        } label: {
                            fileCard(
                                title: "AI Context",
                                subtitle: "Review workspace rules and reusable prompts",
                                symbolName: "brain.head.profile"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open AI context center")

                        Button {
                            appState.showGitHubWorkflowPanel()
                        } label: {
                            fileCard(
                                title: "GitHub Workflow",
                                subtitle: "Open repository pages and branch compare flow",
                                symbolName: "arrow.triangle.branch"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open GitHub workflow")

                        Button {
                            appState.showFirstRunSetupPanel()
                        } label: {
                            fileCard(
                                title: "Setup Checklist",
                                subtitle: "Workspace, Git, AI, plugins, updates, and appearance",
                                symbolName: "checklist"
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Open setup checklist")
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
                .padding(13)
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
                VStack(spacing: 6) {
                    Image(systemName: systemImage)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(RetroPalette.chromeBlue)

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
                .padding(.horizontal, 7)
                .padding(.vertical, 9)
            }
            .frame(maxWidth: .infinity, minHeight: 68)
            .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)
        }
        .buttonStyle(.plain)
    }

    private func fileCard(title: String, subtitle: String, symbolName: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: symbolName)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(RetroPalette.chromeBlue)
                .frame(width: 18, height: 20)

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
                .foregroundStyle(RetroPalette.chromeBlue.opacity(0.45))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)
    }

    private func sidebarSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RetroSectionHeader(title: title, accent: RetroPalette.chromeBlue)
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
                .foregroundStyle(isSelected ? RetroPalette.chromeBlue : RetroPalette.link)
                .frame(width: 18, height: 22)

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
            .buttonStyle(RetroIconButtonStyle(accent: isSelected ? RetroPalette.chromeBlue : RetroPalette.chromeTeal))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .retroPanel(
            fill: isSelected ? RetroPalette.panelFill : RetroPalette.panelFillMuted,
            accent: isSelected ? RetroPalette.chromeBlue : RetroPalette.chromeTeal
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(isSelected ? RetroPalette.chromeGold.opacity(0.75) : Color.clear)
                .frame(width: 3)
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

    private var lineDecorationRefreshKey: String {
        let saveMarker = document.lastSavedAt?.timeIntervalSinceReferenceDate ?? -1
        let locationMarker = document.fileURL?.path ?? document.remoteReference?.spec ?? document.untitledName
        return "\(document.id.uuidString)|\(locationMarker)|\(document.isDirty)|\(saveMarker)"
    }

    private var gitBlameRefreshKey: String {
        let saveMarker = document.lastSavedAt?.timeIntervalSinceReferenceDate ?? -1
        return "\(lineDecorationRefreshKey)|\(currentLine)|\(saveMarker)"
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

    private var isFocusMode: Bool {
        appState.settings.focusModeEnabled
    }

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(spacing: 0) {
                if !isFocusMode {
                    DocumentTabStripView(appState: appState)
                    header
                }

                if !isFocusMode, appState.settings.showsBreadcrumbs, !breadcrumbTrail.isEmpty {
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

                if !isFocusMode, !appState.settings.showsInspector, (!currentLineDiagnostics.isEmpty || currentLineBlame != nil) {
                    RetroRule()
                    editorInsightBar
                }

                workspaceArea

                if !isFocusMode {
                    RetroRule()
                    StatusBarView(document: document, metrics: metrics, settings: appState.settings, pluginStatusItems: pluginStatusItems)
                }
            }
            .padding(isFocusMode ? 0 : 10)
        }
        .background(backgroundColor)
        .task(id: lineDecorationRefreshKey) {
            appState.prefetchLineDecorations(for: document)
        }
        .task(id: gitBlameRefreshKey) {
            appState.prefetchGitBlame(for: document, lineNumber: currentLine)
        }
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
                    appState.showQuickOpenPanel()
                } label: {
                    Label("Quick Open", systemImage: "doc.text.magnifyingglass")
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                BrandMarkView(size: 24)

                VStack(alignment: .leading, spacing: 6) {
                    Text(document.displayName)
                        .font(.system(size: 19, weight: .black, design: .monospaced))
                        .tracking(0.45)
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
                        .foregroundStyle(RetroPalette.mutedInk)
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
                        Button("New Document") {
                            appState.newDocument()
                        }

                        Button("Open Files...") {
                            appState.openDocument()
                        }

                        Button("Open Remote...") {
                            appState.openRemotePanel()
                        }

                        Button("Clone Repository...") {
                            appState.showCloneRepositoryPanel()
                        }

                        Divider()

                        Button("Save") {
                            appState.saveDocument()
                        }
                        .disabled(!appState.canSave)

                        Button("Save As...") {
                            appState.saveDocumentAs()
                        }
                        .disabled(document.isReadOnly)

                        if appState.canPrivilegedSaveSelectedDocument {
                            Button("Privileged Save") {
                                appState.saveDocumentPrivileged()
                            }
                        }
                    } label: {
                        headerControl("File", systemImage: "doc.badge.gearshape")
                    }
                    .menuStyle(.borderlessButton)

                    Menu {
                        Button(appState.settings.focusModeEnabled ? "Exit Focus Mode" : "Enter Focus Mode") {
                            appState.toggleFocusMode()
                        }

                        Button("Appearance Preferences...") {
                            appState.showAppearancePreferences()
                        }

                        Divider()

                        Menu("Retro Intensity") {
                            ForEach(AppChromeStyle.allCases) { style in
                                Button(style.displayName) {
                                    appState.setChromeStyle(style)
                                }
                            }
                        }

                        Menu("Density") {
                            ForEach(InterfaceDensity.allCases) { density in
                                Button(density.displayName) {
                                    appState.setInterfaceDensity(density)
                                }
                            }
                        }

                        Menu("Editor Theme") {
                            ForEach(EditorTheme.allCases) { theme in
                                Button(theme.displayName) {
                                    appState.setTheme(theme)
                                }
                            }
                        }

                        Menu("Language") {
                            ForEach(DocumentLanguage.allCases) { language in
                                Button(language.displayName) {
                                    appState.setLanguage(language)
                                }
                            }
                        }

                        Menu("Split Layout") {
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
                        }

                        Divider()

                        Button(appState.settings.showsInspector ? "Hide Inspector" : "Show Inspector") {
                            appState.toggleInspectorPanel()
                        }

                        Button(appState.settings.showsOutline ? "Hide Outline in Inspector" : "Show Outline in Inspector") {
                            appState.toggleOutlinePanel()
                        }

                        Button(appState.settings.showsBreadcrumbs ? "Hide Breadcrumbs" : "Show Breadcrumbs") {
                            appState.toggleBreadcrumbs()
                        }
                    } label: {
                        headerControl("View", systemImage: "rectangle.3.group")
                    }
                    .menuStyle(.borderlessButton)

                    Menu {
                        Button("Find / Replace") {
                            appState.showFindReplace()
                        }

                        Button("Search in Folder") {
                            appState.showProjectSearch()
                        }

                        Button("Go to Line") {
                            appState.showGoToLine()
                        }

                        Button("Command Palette") {
                            appState.showingCommandPalette = true
                        }

                        Button("Quick Open") {
                            appState.showQuickOpenPanel()
                        }

                        Divider()

                        Button("Workspace Center") {
                            appState.showWorkspacePlatformPanel()
                        }

                        Button("Git Workbench") {
                            appState.showGitWorkbenchPanel()
                        }

                        Button("AI Workbench") {
                            appState.showAIWorkbenchPanel()
                        }

                        Button("Task Runner") {
                            appState.showTaskRunnerPanel()
                        }

                        Button("Embedded Terminal") {
                            appState.showTerminalConsolePanel()
                        }

                        Button("Keyboard Shortcuts") {
                            appState.showingKeyboardShortcuts = true
                        }

                        Divider()

                        Button("Activity Center") {
                            appState.showActivityCenterPanel()
                        }

                        Button("AI Context Center") {
                            appState.showAIContextCenterPanel()
                        }

                        Button("GitHub Workflow") {
                            appState.showGitHubWorkflowPanel()
                        }

                        Button("Release Readiness") {
                            appState.showReleaseReadinessPanel()
                        }

                        Button("Performance HUD") {
                            appState.showPerformanceHUDPanel()
                        }

                        Button("First-Run Setup") {
                            appState.showFirstRunSetupPanel()
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

                            Button("Git branch: \(gitRepositorySummary.branchName)") {}
                                .disabled(true)

                            Divider()
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

                        Button("Compare with Saved") {
                            appState.showCompareAgainstSaved()
                        }
                        .disabled(!appState.canCompareSelectedDocument)

                        Button(document.followModeEnabled ? "Disable Follow Mode" : "Enable Follow Mode") {
                            appState.toggleFollowMode()
                        }
                        .disabled(!appState.canFollowSelectedDocument)

                        Button("Open in Terminal") {
                            appState.openSelectedDocumentInTerminal()
                        }
                        .disabled(document.fileURL == nil && appState.projectSearchState.rootURL == nil)
                    } label: {
                        headerControl("Tools", systemImage: "wrench.and.screwdriver")
                    }
                    .menuStyle(.borderlessButton)
                }
                .padding(.horizontal, 1)
            }
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 11)
        .retroPanel(fill: RetroPalette.railFill, accent: RetroPalette.chromeBlue)
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
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)
    }

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(breadcrumbTrail.enumerated()), id: \.offset) { index, crumb in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(RetroPalette.mutedInk)
                    }

                    Text(crumb)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeBlue)
                }
            }
            .padding(.horizontal, 15)
            .padding(.vertical, 8)
        }
        .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)
    }

    private var workspaceArea: some View {
        HSplitView {
            primaryWorkspaceArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !isFocusMode, appState.settings.showsInspector {
                InspectorPanelView(
                    document: document,
                    currentLine: currentLine,
                    theme: appState.settings.theme,
                    diagnostics: currentLineDiagnostics,
                    blame: currentLineBlame,
                    showsOutline: appState.settings.showsOutline,
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
                .padding(.vertical, 8)
                .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)

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
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeBlue.opacity(0.75))
    }

    private var structuredBadge: (text: String, color: Color)? {
        switch document.presentationMode {
        case .structuredTable:
            return ("Table", RetroPalette.chromeBlue)
        case .structuredJSON:
            return ("JSON Tree", RetroPalette.chromeTeal)
        case .logExplorer:
            return ("Log Explorer", RetroPalette.chromeTeal)
        case .structuredConfig:
            return ("Config", RetroPalette.success)
        case .archiveBrowser:
            return ("Archive", RetroPalette.visited)
        case .httpRequest:
            return ("HTTP", RetroPalette.chromeCyan)
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
        .padding(.horizontal, 15)
        .padding(.vertical, 10)
        .retroPanel(fill: RetroPalette.panelFillMuted, accent: accent)
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
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)
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
