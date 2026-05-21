import SwiftUI

struct ContentView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Group {
            if !appState.isSidebarVisible {
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
        .sheet(isPresented: $appState.showingGoToLine) {
            GoToLineView(appState: appState)
        }
        .sheet(isPresented: $appState.showingCloneRepository) {
            CloneRepositoryView(appState: appState)
        }
        .sheet(isPresented: $appState.showingGitWorkbench) {
            GitWorkbenchView(appState: appState)
        }
        .sheet(isPresented: $appState.showingRemoteOpen) {
            RemoteOpenView(appState: appState)
        }
        .sheet(isPresented: $appState.showingWorkspacePlatform) {
            WorkspacePlatformView(appState: appState)
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
        .sheet(item: $appState.aiPromptReviewState) { reviewState in
            AIPromptReviewView(appState: appState, reviewState: reviewState)
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
        .overlay {
            if appState.showingCommandPalette || appState.showingQuickOpen {
                WorkbenchQuickOverlay(appState: appState)
            }
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

private enum SidebarPane: String, CaseIterable, Identifiable {
    case explorer
    case sourceControl
    case workspace
    case jump
    case tools
    case extensions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .explorer:
            return "Explorer"
        case .sourceControl:
            return "Source Control"
        case .workspace:
            return "Workspace"
        case .jump:
            return "Navigate"
        case .tools:
            return "Tools"
        case .extensions:
            return "Extensions"
        }
    }

    var subtitle: String {
        switch self {
        case .explorer:
            return "Open files, switch documents, and browse the active folder."
        case .sourceControl:
            return "Review branch state, stage changes, and jump into Git workflows."
        case .workspace:
            return "Manage folders, sessions, remote files, and repository setup."
        case .jump:
            return "Move quickly through files, symbols, commands, and diagnostics."
        case .tools:
            return "Git, AI, terminal, problems, tests, and workflow utilities."
        case .extensions:
            return "Plugins, tasks, snippets, appearance, and setup."
        }
    }

    var symbolName: String {
        switch self {
        case .explorer:
            return "doc.on.doc"
        case .sourceControl:
            return "arrow.triangle.branch"
        case .workspace:
            return "sidebar.left"
        case .jump:
            return "magnifyingglass"
        case .tools:
            return "hammer"
        case .extensions:
            return "puzzlepiece.extension"
        }
    }
}

private struct DocumentSidebarView: View {
    @Environment(\.retroChromeStyle) private var chromeStyle
    @ObservedObject var appState: AppState
    @State private var selectedPane: SidebarPane = .explorer

    var body: some View {
        HStack(spacing: 0) {
            activityRail

            Rectangle()
                .fill(chromeStyle == .studio ? RetroPalette.studioDivider : RetroPalette.chromeBlue.opacity(0.18))
                .frame(width: 1)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    sidebarHeader
                    quickActionBar
                    selectedPaneContent
                }
                .padding(14)
            }
        }
        .frame(minWidth: 320)
    }

    private var activityRail: some View {
        VStack(spacing: 6) {
            ForEach(SidebarPane.allCases) { pane in
                Button {
                    selectedPane = pane
                    if pane == .sourceControl {
                        appState.refreshGitWorkbench()
                    }
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(selectedPane == pane ? RetroPalette.studioAccent.opacity(0.12) : Color.clear)

                        Image(systemName: pane.symbolName)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(selectedPane == pane ? RetroPalette.studioAccent : RetroPalette.mutedInk)
                    }
                    .frame(width: 34, height: 34)
                }
                .buttonStyle(.plain)
                .help(pane.title)
                .accessibilityLabel(pane.title)
            }

            Spacer(minLength: 0)

            Button {
                appState.showAppearancePreferences()
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(RetroPalette.studioPanel)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Appearance preferences")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .frame(width: 50)
        .background(
            chromeStyle == .studio ? RetroPalette.studioRail : RetroPalette.railFill
        )
    }

    private var sidebarHeader: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 10) {
                Text(selectedPane.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RetroPalette.ink)

                Spacer(minLength: 0)
            }

            Text(appState.activeWorkspaceURL?.lastPathComponent ?? selectedPane.subtitle)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(RetroPalette.mutedInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .retroPanel(fill: chromeStyle == .studio ? RetroPalette.studioPanel : RetroPalette.railFill, accent: RetroPalette.chromeBlue)
    }

    private var quickActionBar: some View {
        HStack(spacing: 8) {
            compactAction("New", systemImage: "plus.square", action: appState.newDocument)
            compactAction("Open", systemImage: "folder", action: appState.openDocument)
            compactAction("Palette", systemImage: "command", action: { appState.showingCommandPalette = true })
        }
    }

    @ViewBuilder
    private var selectedPaneContent: some View {
        switch selectedPane {
        case .explorer:
            explorerPane
        case .sourceControl:
            sourceControlPane
        case .workspace:
            workspacePane
        case .jump:
            jumpPane
        case .tools:
            toolsPane
        case .extensions:
            extensionsPane
        }
    }

    private var explorerPane: some View {
        Group {
            sidebarSection("Open Documents") {
                if appState.documents.isEmpty {
                    emptySidebarMessage("Open documents will appear here.")
                } else {
                    ForEach(appState.documents) { document in
                        DocumentSidebarRow(
                            document: document,
                            isSelected: appState.selectedDocumentID == document.id,
                            onSelect: { appState.selectDocument(document.id) },
                            onClose: { appState.closeDocument(id: document.id) }
                        )
                    }
                }
            }

            WorkspaceExplorerView(appState: appState)

            sidebarSection("Recent Files") {
                if appState.recentFiles.isEmpty {
                    emptySidebarMessage("Recent files will appear here after you open or save documents.")
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
        }
    }

    private var workspacePane: some View {
        Group {
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

                Button {
                    appState.chooseWorkspaceRoot()
                } label: {
                    fileCard(
                        title: appState.projectSearchState.rootURL?.lastPathComponent ?? "Choose Folder",
                        subtitle: appState.projectSearchState.rootURL?.path(percentEncoded: false) ?? "Set a project root for indexing, search, Git, and terminal tools.",
                        symbolName: "folder.badge.gearshape"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    appState.showCloneRepositoryPanel()
                } label: {
                    fileCard(
                        title: "Clone Repository",
                        subtitle: "Clone a repository directly into a local workspace folder.",
                        symbolName: "square.and.arrow.down.on.square"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    appState.openRemotePanel()
                } label: {
                    fileCard(
                        title: "Open Remote File",
                        subtitle: "Load a file from an SSH-style location like user@host:/path/to/file.",
                        symbolName: "network"
                    )
                }
                .buttonStyle(.plain)

                Button {
                    appState.showWorkspaceSessionsPanel()
                } label: {
                    fileCard(
                        title: "Workspace Sessions",
                        subtitle: "Save and reopen grouped files, remotes, and workbench state.",
                        symbolName: "square.stack.3d.up"
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var sourceControlPane: some View {
        Group {
            sidebarSection("Repository") {
                if let summary = appState.gitRepositorySummary {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(summary.branchName)
                                    .font(.system(size: 13, weight: .black, design: .monospaced))
                                    .foregroundStyle(RetroPalette.ink)

                                Text(summary.rootURL.path(percentEncoded: false))
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(RetroPalette.link)
                                    .lineLimit(2)
                            }

                            Spacer(minLength: 0)

                            Button {
                                appState.refreshGitWorkbench()
                            } label: {
                                Image(systemName: "arrow.clockwise")
                            }
                            .buttonStyle(RetroIconButtonStyle(accent: RetroPalette.chromeBlue))
                        }

                        FlowBadgeRow {
                            RetroCapsuleLabel(text: "\(summary.modifiedCount) modified", accent: RetroPalette.warning)
                            RetroCapsuleLabel(text: "\(summary.stagedCount) staged", accent: RetroPalette.success)
                            if summary.untrackedCount > 0 {
                                RetroCapsuleLabel(text: "\(summary.untrackedCount) untracked", accent: RetroPalette.chromeTeal)
                            }
                            if summary.conflictedCount > 0 {
                                RetroCapsuleLabel(text: "\(summary.conflictedCount) conflicted", accent: RetroPalette.danger)
                            }
                        }

                        HStack(spacing: 8) {
                            compactAction("Fetch", systemImage: "arrow.down.circle", action: appState.fetchGitRepository)
                            compactAction("Pull", systemImage: "arrow.down.to.line", action: appState.pullGitRepository)
                            compactAction("Push", systemImage: "arrow.up.to.line", action: appState.pushGitRepository)
                        }
                    }
                    .padding(10)
                    .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)
                } else {
                    emptySidebarMessage("Open a Git-backed workspace to inspect source control state.")
                }
            }

            sidebarSection("Changes") {
                if appState.gitPanelState.changedFiles.isEmpty {
                    emptySidebarMessage("No changed files in the current repository.")
                } else {
                    ForEach(Array(appState.gitPanelState.changedFiles.prefix(20))) { file in
                        sourceControlFileRow(file)
                    }
                }
            }

            sidebarSection("Open Full Workbench") {
                actionCard(
                    "Git Workbench",
                    subtitle: "Commit, branch, stash, resolve conflicts, and inspect history in the full Git surface.",
                    symbolName: "point.topleft.down.curvedto.point.bottomright.up",
                    action: appState.showGitWorkbenchPanel
                )
            }
        }
    }

    private var jumpPane: some View {
        Group {
            sidebarSection("Navigate") {
                actionCard("Quick Open", subtitle: "Jump to indexed files and symbols.", symbolName: "doc.text.magnifyingglass", action: appState.showQuickOpenPanel)
                actionCard("Command Palette", subtitle: "Search commands, documents, files, symbols, tasks, and themes.", symbolName: "command", action: { appState.showingCommandPalette = true })
                actionCard("Search in Folder", subtitle: "Search across the current workspace root.", symbolName: "magnifyingglass", action: appState.showProjectSearch)
                actionCard("Go to Line", subtitle: "Jump directly to a line in the active document.", symbolName: "number", action: appState.showGoToLine)
                actionCard("Keyboard Shortcuts", subtitle: "Review the main editor, navigation, and workbench shortcuts.", symbolName: "keyboard", action: { appState.showingKeyboardShortcuts = true })
                actionCard("Activity Center", subtitle: "Review indexing, diagnostics, and recent editor activity.", symbolName: "list.bullet.rectangle.portrait", action: appState.showActivityCenterPanel)
            }
        }
    }

    private var toolsPane: some View {
        Group {
            sidebarSection("Developer Tools") {
                actionCard("Embedded Terminal", subtitle: "Run shell commands without leaving ForgeText.", symbolName: "terminal.fill", action: appState.showTerminalConsolePanel)
                actionCard("Git Workbench", subtitle: "Commit, push, pull, stash, and inspect repository changes.", symbolName: "point.topleft.down.curvedto.point.bottomright.up", action: appState.showGitWorkbenchPanel)
                actionCard("AI Workbench", subtitle: "Use configured providers for chat, editing, and commit drafts.", symbolName: "sparkles.rectangle.stack", action: appState.showAIWorkbenchPanel)
                actionCard("AI Context", subtitle: "Review workspace rules and reusable prompts.", symbolName: "brain.head.profile", action: appState.showAIContextCenterPanel)
                actionCard("Problems", subtitle: "Review matched build, test, lint, and terminal problems.", symbolName: "exclamationmark.bubble", action: appState.showProblemsPanelView)
                actionCard("Test Explorer", subtitle: "Run detected workspace tests and inspect results.", symbolName: "checklist.checked", action: appState.showTestExplorerPanel)
                actionCard("GitHub Workflow", subtitle: "Open repository pages and branch compare workflows.", symbolName: "arrow.triangle.branch", action: appState.showGitHubWorkflowPanel)
            }
        }
    }

    private var extensionsPane: some View {
        Group {
            sidebarSection("Extensions + Setup") {
                actionCard("Plugin Manager", subtitle: "Enable built-in IDE plugins and inspect their capabilities.", symbolName: "puzzlepiece.extension", action: appState.showPluginManagerPanel)
                actionCard("Task Runner", subtitle: "Run workspace build, test, and lint commands from detected project files.", symbolName: "play.square.stack", action: appState.showTaskRunnerPanel)
                actionCard("Snippet Library", subtitle: "Insert format-aware snippets into the current document.", symbolName: "text.badge.plus", action: appState.showSnippetLibraryPanel)
                actionCard("Workbench + Advanced", subtitle: "Adjust layout, runtime, file handling, AI privacy, and editor theme.", symbolName: "slider.horizontal.3", action: appState.showAppearancePreferences)
                actionCard("Setup Checklist", subtitle: "Review workspace, Git, AI, plugin, and update readiness.", symbolName: "checklist", action: appState.showFirstRunSetupPanel)
            }
        }
    }

    private func compactAction(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 12, weight: .medium))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(RetroActionButtonStyle(tone: .secondary))
    }

    private func actionCard(_ title: String, subtitle: String, symbolName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            fileCard(title: title, subtitle: subtitle, symbolName: symbolName)
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
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(RetroPalette.ink)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.system(size: 11, weight: .regular))
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
        .retroPanel(
            fill: chromeStyle == .studio ? RetroPalette.studioPanelMuted : RetroPalette.panelFillMuted,
            accent: RetroPalette.chromeBlue
        )
    }

    private func sourceControlFileRow(_ file: GitChangedFile) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: file.isConflicted ? "exclamationmark.triangle.fill" : "doc.text")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(file.isConflicted ? RetroPalette.danger : RetroPalette.chromeBlue)
                    .frame(width: 16)

                VStack(alignment: .leading, spacing: 3) {
                    Text(file.displayName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RetroPalette.ink)
                        .lineLimit(1)

                    Text(file.relativePath)
                        .font(.system(size: 10, weight: .regular))
                        .foregroundStyle(RetroPalette.link)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                RetroCapsuleLabel(
                    text: file.statusSummary,
                    accent: file.isConflicted ? RetroPalette.danger : RetroPalette.chromeTeal
                )
            }

            HStack(spacing: 8) {
                Button("Open") {
                    appState.openGitChangedFile(file)
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                Button("Stage") {
                    appState.stageGitChangedFile(file)
                }
                .buttonStyle(RetroActionButtonStyle(tone: .primary))

                Button("Unstage") {
                    appState.unstageGitChangedFile(file)
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))
            }
        }
        .padding(10)
        .retroPanel(
            fill: chromeStyle == .studio ? RetroPalette.studioPanelMuted : RetroPalette.panelFillMuted,
            accent: file.isConflicted ? RetroPalette.danger : RetroPalette.chromeTeal
        )
    }

    private func emptySidebarMessage(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .regular))
            .foregroundStyle(RetroPalette.link)
            .fixedSize(horizontal: false, vertical: true)
            .padding(10)
            .retroPanel(
                fill: chromeStyle == .studio ? RetroPalette.studioPanelMuted : RetroPalette.panelFillMuted,
                accent: RetroPalette.chromeBlue
            )
    }

    private func sidebarSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RetroSectionHeader(title: title, accent: RetroPalette.chromeBlue)
            content()
        }
    }
}

private struct DocumentSidebarRow: View {
    @Environment(\.retroChromeStyle) private var chromeStyle
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
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RetroPalette.ink)
                        .lineLimit(1)

                    if document.isDirty {
                        RetroCapsuleLabel(text: "edit", accent: RetroPalette.warning)
                    }
                }

                Text(document.pathDescription)
                    .font(.system(size: 11, weight: .regular))
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
            fill: isSelected
                ? (chromeStyle == .studio ? RetroPalette.studioPanel : RetroPalette.panelFill)
                : (chromeStyle == .studio ? RetroPalette.studioPanelMuted : RetroPalette.panelFillMuted),
            accent: isSelected ? RetroPalette.chromeBlue : RetroPalette.chromeTeal
        )
        .overlay(alignment: .leading) {
            Rectangle()
                .fill(isSelected ? (chromeStyle == .studio ? RetroPalette.chromeBlue.opacity(0.75) : RetroPalette.chromeGold.opacity(0.75)) : Color.clear)
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
        appState.breadcrumbTrail(for: document, cursorLine: currentLine)
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

            editorWorkbenchArea

            if !isFocusMode {
                RetroRule()
                StatusBarView(
                    appState: appState,
                    document: document,
                    metrics: metrics,
                    settings: appState.settings,
                    insights: appState.workbenchInsights(for: document),
                    pluginStatusItems: pluginStatusItems
                )
            }
        }
        .padding(isFocusMode ? 0 : 10)
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

                Button {
                    appState.toggleSidebar()
                } label: {
                    Label(appState.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar", systemImage: "sidebar.left")
                }

                Button {
                    appState.toggleBottomPanel()
                } label: {
                    Label(appState.isBottomPanelVisible ? "Hide Panel" : "Show Panel", systemImage: "rectangle.bottomthird.inset.filled")
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(document.displayName)
                        .font(.system(size: 16, weight: .semibold))
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

                        if let structuredBadge {
                            headerBadge(structuredBadge.text, color: structuredBadge.color)
                        }
                    }

                    Text(document.pathDescription)
                        .font(.system(size: 11, weight: .regular))
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
                        ForEach(WorkbenchPreset.allCases) { preset in
                            Button(preset.displayName) {
                                appState.applyWorkbenchPreset(preset)
                            }
                        }

                        if appState.canRestoreCustomWorkbenchAppearance {
                            Divider()
                            Button("Restore Custom Layout") {
                                appState.restoreCustomWorkbenchAppearance()
                            }
                        }
                    } label: {
                        headerControl(
                            appState.activeWorkbenchPresetLabel,
                            systemImage: "line.3.horizontal.decrease.circle"
                        )
                    }
                    .menuStyle(.borderlessButton)

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

                        Button(appState.isSidebarVisible ? "Hide Sidebar" : "Show Sidebar") {
                            appState.toggleSidebar()
                        }

                        Button(appState.isBottomPanelVisible ? "Hide Panel" : "Show Panel") {
                            appState.toggleBottomPanel()
                        }

                        Menu("Workbench Preset") {
                            ForEach(WorkbenchPreset.allCases) { preset in
                                Button(preset.displayName) {
                                    appState.applyWorkbenchPreset(preset)
                                }
                            }

                            if appState.canRestoreCustomWorkbenchAppearance {
                                Divider()
                                Button("Restore Custom Layout") {
                                    appState.restoreCustomWorkbenchAppearance()
                                }
                            }
                        }

                        Button("Workbench + Advanced...") {
                            appState.showAppearancePreferences()
                        }

                        Divider()

                        Menu("Workbench Style") {
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
        .padding(.vertical, 9)
        .retroPanel(fill: appState.settings.chromeStyle == .studio ? RetroPalette.studioPanel : RetroPalette.railFill, accent: RetroPalette.chromeBlue)
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
                    outline: appState.outline(for: document),
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

    private var editorWorkbenchArea: some View {
        VSplitView {
            workspaceArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if appState.isBottomPanelVisible {
                WorkbenchBottomPanelView(appState: appState)
                    .frame(minHeight: 200, idealHeight: 260, maxHeight: 360)
                    .background(backgroundColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .font(.system(size: 12, weight: .medium))
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
        VStack(spacing: 18) {
            BrandMarkView(size: 76)

            VStack(spacing: 8) {
                Text("ForgeText")
                    .font(.system(size: 31, weight: .black, design: .monospaced))
                    .tracking(1.1)
                    .foregroundStyle(RetroPalette.ink)

                Text("A native editor for text, code, logs, configs, Git, and AI-assisted workflows.")
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

                heroAction("Clone Repo", subtitle: "Clone a repository locally", systemImage: "square.and.arrow.down.on.square", tone: .primary) {
                    appState.showCloneRepositoryPanel()
                }

                heroAction("Quick Open", subtitle: "Jump through indexed workspace files and symbols", systemImage: "doc.text.magnifyingglass", tone: .secondary) {
                    appState.showQuickOpenPanel()
                }

                heroAction("Open Remote", subtitle: "Load a file from an SSH-style location", systemImage: "network", tone: .secondary) {
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

private struct WorkbenchQuickOverlay: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack(alignment: .top) {
            Color.black.opacity(0.16)
                .ignoresSafeArea()
                .onTapGesture {
                    appState.showingCommandPalette = false
                    appState.showingQuickOpen = false
                }

            Group {
                if appState.showingCommandPalette {
                    CommandPaletteView(appState: appState)
                } else if appState.showingQuickOpen {
                    QuickOpenView(appState: appState)
                }
            }
            .padding(.top, 64)
        }
        .transition(.opacity)
    }
}

private struct WorkbenchBottomPanelView: View {
    @Environment(\.retroChromeStyle) private var chromeStyle
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                ForEach(WorkbenchBottomPanel.allCases) { panel in
                    Button {
                        appState.showBottomPanel(panel)
                    } label: {
                        Label(panel.title, systemImage: panel.symbolName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(appState.activeBottomPanel == panel ? RetroPalette.ink : RetroPalette.mutedInk)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(appState.activeBottomPanel == panel ? RetroPalette.studioField : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer(minLength: 0)

                panelHeaderActions

                Button {
                    appState.hideBottomPanel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                }
                .buttonStyle(RetroIconButtonStyle(accent: RetroPalette.chromeBlue))
                .accessibilityLabel("Hide panel")
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(chromeStyle == .studio ? RetroPalette.studioPanelMuted : RetroPalette.railFill)

            RetroRule()

            activePanelContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(chromeStyle == .studio ? RetroPalette.studioPanel : RetroPalette.panelFillMuted)
        }
        .retroPanel(fill: chromeStyle == .studio ? RetroPalette.studioPanel : RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)
    }

    @ViewBuilder
    private var panelHeaderActions: some View {
        switch appState.activeBottomPanel {
        case .search:
            Button("Run Search") {
                appState.runProjectSearch()
            }
            .buttonStyle(RetroActionButtonStyle(tone: .secondary))
        case .sourceControl:
            Button("Open Full Git") {
                appState.showGitWorkbenchPanel()
            }
            .buttonStyle(RetroActionButtonStyle(tone: .secondary))
        case .terminal:
            Button("Run") {
                appState.runEmbeddedTerminalCommand()
            }
            .buttonStyle(RetroActionButtonStyle(tone: .secondary))
        case .problems:
            Button("Refresh Git") {
                appState.refreshGitStatus()
            }
            .buttonStyle(RetroActionButtonStyle(tone: .secondary))
        case .tests:
            Button("Run Tests") {
                appState.runSelectedTestTask()
            }
            .buttonStyle(RetroActionButtonStyle(tone: .secondary))
        case .assistant:
            Button("Open Full AI") {
                appState.showAIWorkbenchPanel()
            }
            .buttonStyle(RetroActionButtonStyle(tone: .secondary))
        }
    }

    @ViewBuilder
    private var activePanelContent: some View {
        switch appState.activeBottomPanel {
        case .search:
            DockedSearchPanel(appState: appState)
        case .sourceControl:
            DockedSourceControlPanel(appState: appState)
        case .terminal:
            DockedTerminalPanel(appState: appState)
        case .problems:
            DockedProblemsPanel(appState: appState)
        case .tests:
            DockedTestsPanel(appState: appState)
        case .assistant:
            DockedAIPanel(appState: appState)
        }
    }
}

private struct DockedSearchPanel: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField("Search files in the current workspace", text: $appState.projectSearchState.query)
                    .textFieldStyle(.plain)
                    .retroTextField()
                    .onSubmit {
                        appState.runProjectSearch()
                    }

                Button("Choose Folder") {
                    appState.chooseWorkspaceRoot()
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))
            }

            HStack(spacing: 14) {
                Toggle("Case Sensitive", isOn: $appState.projectSearchState.isCaseSensitive)
                Toggle("Regex", isOn: $appState.projectSearchState.usesRegularExpression)
                Toggle("Include Hidden", isOn: $appState.projectSearchState.includeHiddenFiles)

                Spacer(minLength: 0)

                Text(appState.projectSearchState.summary)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(RetroPalette.link)
            }
            .toggleStyle(.checkbox)

            if appState.projectSearchState.hits.isEmpty {
                ContentUnavailableView(
                    "No Search Results Yet",
                    systemImage: "magnifyingglass",
                    description: Text("Run a workspace search to review matching lines here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.projectSearchState.hits) { hit in
                            Button {
                                appState.openProjectSearchHit(hit)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(hit.fileURL.lastPathComponent)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(RetroPalette.ink)
                                        Spacer(minLength: 0)
                                        Text("Ln \(hit.lineNumber)")
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(RetroPalette.link)
                                    }

                                    Text(hit.fileURL.path(percentEncoded: false))
                                        .font(.system(size: 10, weight: .regular))
                                        .foregroundStyle(RetroPalette.mutedInk)
                                        .lineLimit(1)

                                    Text(hit.lineText)
                                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                                        .foregroundStyle(RetroPalette.ink)
                                        .lineLimit(2)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .retroPanel(fill: RetroPalette.studioPanelMuted, accent: RetroPalette.chromeBlue)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(12)
    }
}

private struct DockedSourceControlPanel: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HSplitView {
            VStack(alignment: .leading, spacing: 10) {
                if let summary = appState.gitRepositorySummary {
                    HStack(spacing: 8) {
                        RetroCapsuleLabel(text: summary.branchName, accent: RetroPalette.chromeBlue)
                        RetroCapsuleLabel(text: "\(summary.modifiedCount) modified", accent: RetroPalette.warning)
                        RetroCapsuleLabel(text: "\(summary.stagedCount) staged", accent: RetroPalette.success)
                    }
                } else {
                    Text("Open a Git-backed workspace to use source control.")
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(RetroPalette.link)
                }

                ScrollView {
                    LazyVStack(spacing: 6) {
                        if appState.gitPanelState.changedFiles.isEmpty {
                            Text("No pending changes in the current repository.")
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(RetroPalette.link)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.top, 6)
                        } else {
                            ForEach(appState.gitPanelState.changedFiles) { file in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(file.displayName)
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundStyle(RetroPalette.ink)
                                        Spacer(minLength: 0)
                                        Text(file.statusSummary)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(file.isConflicted ? RetroPalette.danger : RetroPalette.link)
                                    }

                                    Text(file.relativePath)
                                        .font(.system(size: 10, weight: .regular))
                                        .foregroundStyle(RetroPalette.mutedInk)
                                        .lineLimit(1)

                                    HStack(spacing: 8) {
                                        Button("Open") {
                                            appState.openGitChangedFile(file)
                                        }
                                        .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                                        Button("Stage") {
                                            appState.stageGitChangedFile(file)
                                        }
                                        .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                                        Button("Unstage") {
                                            appState.unstageGitChangedFile(file)
                                        }
                                        .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                                    }
                                }
                                .padding(8)
                                .retroPanel(fill: RetroPalette.studioPanelMuted, accent: file.isConflicted ? RetroPalette.danger : RetroPalette.chromeBlue)
                            }
                        }
                    }
                }
            }
            .padding(12)
            .frame(minWidth: 320)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button("Fetch") {
                        appState.fetchGitRepository()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                    Button("Pull") {
                        appState.pullGitRepository()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                    Button("Push") {
                        appState.pushGitRepository()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                    if !appState.availableGitBranches.isEmpty {
                        Menu("Branches") {
                            ForEach(appState.availableGitBranches, id: \.self) { branch in
                                Button(branch) {
                                    appState.switchGitBranch(branch)
                                }
                            }
                        }
                    }
                }

                TextEditor(text: Binding(
                    get: { appState.gitPanelState.commitMessage },
                    set: { appState.gitPanelState.commitMessage = $0 }
                ))
                .font(.system(size: 12, design: .monospaced))
                .frame(minHeight: 88)
                .padding(8)
                .retroInsetPanel(fill: RetroPalette.studioField, accent: RetroPalette.chromeBlue)

                HStack(spacing: 8) {
                    Button("Commit Staged Changes") {
                        appState.commitGitChanges()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .accent))

                    Button("AI Draft Message") {
                        appState.runAIQuickAction(.draftCommitMessage)
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                }

                if let message = appState.gitPanelState.lastOperationMessage {
                    Text(message)
                        .font(.system(size: 11, weight: .regular))
                        .foregroundStyle(RetroPalette.link)
                }

                Spacer(minLength: 0)
            }
            .padding(12)
        }
    }
}

private struct DockedTerminalPanel: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                TextField("Run a command in the current workspace", text: $appState.terminalPanelState.commandText)
                    .textFieldStyle(.plain)
                    .retroTextField()
                    .onSubmit {
                        appState.runEmbeddedTerminalCommand()
                    }

                Button("Run") {
                    appState.runEmbeddedTerminalCommand()
                }
                .buttonStyle(RetroActionButtonStyle(tone: .accent))
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(EmbeddedTerminalService.suggestedCommands, id: \.self) { command in
                        Button(command) {
                            appState.terminalPanelState.commandText = command
                        }
                        .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                    }
                }
            }

            ScrollView {
                Text(appState.terminalPanelState.lastRun?.output ?? "Run a command to capture output here.")
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(RetroPalette.ink)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .retroInsetPanel(fill: RetroPalette.studioField, accent: RetroPalette.chromeBlue)
        }
        .padding(12)
    }
}

private struct DockedProblemsPanel: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(appState.problemsPanelState.sourceDescription)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(RetroPalette.link)

            if appState.problemsPanelState.records.isEmpty {
                ContentUnavailableView(
                    "No Problems",
                    systemImage: "checkmark.circle",
                    description: Text("Problems from builds, tests, and terminal runs will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(appState.problemsPanelState.records) { record in
                            Button {
                                appState.openProblem(record)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(record.message)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(RetroPalette.ink)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    if let filePath = record.filePath {
                                        Text(filePath)
                                            .font(.system(size: 10, weight: .regular))
                                            .foregroundStyle(RetroPalette.mutedInk)
                                            .lineLimit(1)
                                    }
                                }
                                .padding(8)
                                .retroPanel(fill: RetroPalette.studioPanelMuted, accent: record.severity == .error ? RetroPalette.danger : RetroPalette.warning)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(12)
    }
}

private struct DockedTestsPanel: View {
    @ObservedObject var appState: AppState

    private var selectedTask: EditorPluginTask? {
        guard let selectedTaskID = appState.testExplorerState.selectedTaskID else {
            return appState.availableTestTasks.first
        }

        return appState.availableTestTasks.first(where: { $0.id == selectedTaskID }) ?? appState.availableTestTasks.first
    }

    var body: some View {
        HSplitView {
            ScrollView {
                LazyVStack(spacing: 6) {
                    ForEach(appState.availableTestTasks) { task in
                        Button {
                            appState.testExplorerState.selectedTaskID = task.id
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(RetroPalette.ink)
                                Text(task.commandDescription)
                                    .font(.system(size: 10, weight: .regular))
                                    .foregroundStyle(RetroPalette.link)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .retroPanel(
                                fill: appState.testExplorerState.selectedTaskID == task.id ? RetroPalette.studioField : RetroPalette.studioPanelMuted,
                                accent: appState.testExplorerState.selectedTaskID == task.id ? RetroPalette.chromeBlue : RetroPalette.studioBorder
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(minWidth: 260)
            .padding(12)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button("Run Selected") {
                        appState.runSelectedTestTask()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .accent))

                    Button("Run Coverage") {
                        appState.runSelectedCoverageTask()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                    .disabled(selectedTask?.supportsCoverage != true)
                }

                ScrollView {
                    Text(appState.testExplorerState.lastRun?.output ?? "Run a detected test task to inspect results here.")
                        .font(.system(size: 11, weight: .regular, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .retroInsetPanel(fill: RetroPalette.studioField, accent: RetroPalette.chromeBlue)
            }
            .padding(12)
        }
    }
}

private struct DockedAIPanel: View {
    @ObservedObject var appState: AppState

    var body: some View {
        HSplitView {
            ScrollView {
                LazyVStack(spacing: 6) {
                    if appState.aiWorkbenchState.sessions.isEmpty {
                        Text("Create a chat to keep prompts and responses docked with the editor.")
                            .font(.system(size: 11, weight: .regular))
                            .foregroundStyle(RetroPalette.link)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(appState.aiWorkbenchState.sessions) { session in
                            Button {
                                appState.selectAISession(session.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(session.title.isEmpty ? "Untitled Chat" : session.title)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(RetroPalette.ink)
                                    Text("\(session.messages.count) messages")
                                        .font(.system(size: 10, weight: .regular))
                                        .foregroundStyle(RetroPalette.link)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                                .retroPanel(
                                    fill: appState.aiWorkbenchState.selectedSessionID == session.id ? RetroPalette.studioField : RetroPalette.studioPanelMuted,
                                    accent: appState.aiWorkbenchState.selectedSessionID == session.id ? RetroPalette.chromeBlue : RetroPalette.studioBorder
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(minWidth: 220)
            .padding(12)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Button("New Chat") {
                        appState.createAISession()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                    ForEach(Array(AIQuickAction.allCases.prefix(3))) { action in
                        Button(action.displayName) {
                            appState.runAIQuickAction(action)
                        }
                        .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                    }
                }

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(appState.selectedAISession?.messages ?? []) { message in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(message.role == .assistant ? message.providerName : "You")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(RetroPalette.link)
                                Text(message.content)
                                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                                    .foregroundStyle(RetroPalette.ink)
                                    .textSelection(.enabled)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .retroPanel(fill: message.role == .assistant ? RetroPalette.studioPanelMuted : RetroPalette.studioField, accent: message.role == .assistant ? RetroPalette.chromeBlue : RetroPalette.studioBorder)
                        }

                        if let response = appState.aiWorkbenchState.lastResponseText,
                           appState.selectedAISession?.messages.last?.content != response {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(appState.selectedAIProvider?.name ?? "AI")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(RetroPalette.link)
                                Text(response)
                                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                                    .foregroundStyle(RetroPalette.ink)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .retroPanel(fill: RetroPalette.studioPanelMuted, accent: RetroPalette.chromeBlue)
                        }
                    }
                }

                TextEditor(text: $appState.aiWorkbenchState.draftPrompt)
                    .font(.system(size: 12, design: .monospaced))
                    .frame(minHeight: 72, maxHeight: 96)
                    .padding(8)
                    .retroInsetPanel(fill: RetroPalette.studioField, accent: RetroPalette.chromeBlue)

                HStack(spacing: 8) {
                    Button(appState.aiWorkbenchState.isSending ? "Sending..." : "Send") {
                        appState.sendAIPrompt()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .accent))
                    .disabled(appState.aiWorkbenchState.isSending)

                    if let statusMessage = appState.aiWorkbenchState.statusMessage {
                        Text(statusMessage)
                            .font(.system(size: 10, weight: .regular))
                            .foregroundStyle(RetroPalette.link)
                            .lineLimit(1)
                    }
                }
            }
            .padding(12)
        }
    }
}
