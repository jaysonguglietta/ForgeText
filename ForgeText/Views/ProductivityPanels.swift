import SwiftUI

struct QuickOpenView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState
    @State private var query = ""
    @State private var mode: CommandPaletteMode = .files

    private var matchingFiles: [WorkspaceIndexEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Array(appState.workspaceIndexSummary.entries.prefix(120))
        }

        return appState.workspaceIndexSummary.entries.filter {
            [$0.displayName, $0.relativePath, $0.language.displayName]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(trimmed)
        }
    }

    private var matchingSymbols: [WorkspaceSymbolEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return Array(appState.workspaceIndexSummary.symbols.prefix(120))
        }

        return appState.workspaceIndexSummary.symbols.filter {
            [$0.title, $0.relativePath, $0.detail ?? ""]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(trimmed)
        }
    }

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(alignment: .leading, spacing: 14) {
                ProductivityHeader(
                    title: "Quick Open",
                    systemImage: "doc.text.magnifyingglass",
                    subtitle: appState.workspaceIndexSummary.statusMessage ?? "Jump around the workspace without touching the mouse."
                ) {
                    Button("Reindex") {
                        appState.refreshWorkspaceIndex()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .primary))
                }

                HStack(spacing: 10) {
                    Picker("Mode", selection: $mode) {
                        Text("Files").tag(CommandPaletteMode.files)
                        Text("Symbols").tag(CommandPaletteMode.symbols)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)

                    TextField(mode == .files ? "@ file name or path" : "# symbol or function", text: $query)
                        .textFieldStyle(.plain)
                        .retroTextField()
                }

                if appState.workspaceIndexSummary.isIndexing {
                    ProgressView("Indexing workspace...")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroPalette.link)
                }

                ScrollView {
                    LazyVStack(spacing: 8) {
                        if mode == .files {
                            if matchingFiles.isEmpty {
                                emptyMessage("No indexed files match that search.")
                            } else {
                                ForEach(Array(matchingFiles.prefix(120))) { entry in
                                    Button {
                                        appState.openIndexedFile(entry.url)
                                        dismiss()
                                    } label: {
                                        indexFileRow(entry)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        } else {
                            if matchingSymbols.isEmpty {
                                emptyMessage("No symbols match that search.")
                            } else {
                                ForEach(Array(matchingSymbols.prefix(120))) { symbol in
                                    Button {
                                        appState.openIndexedSymbol(symbol)
                                        dismiss()
                                    } label: {
                                        symbolRow(symbol)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(12)
                }
                .retroInsetPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)
            }
            .padding(18)
            .frame(minWidth: 760, minHeight: 560)
            .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)
            .padding(18)
        }
    }

    private func indexFileRow(_ entry: WorkspaceIndexEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.language.symbolName)
                .frame(width: 22)
                .foregroundStyle(RetroPalette.chromeBlue)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(RetroPalette.ink)
                Text(entry.subtitle)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            HStack(spacing: 6) {
                if entry.todoCount > 0 {
                    RetroCapsuleLabel(text: "todo \(entry.todoCount)", accent: RetroPalette.warning)
                }
                if entry.warningCount > 0 {
                    RetroCapsuleLabel(text: "check", accent: RetroPalette.danger)
                }
                RetroCapsuleLabel(text: "\(entry.lineCount) lines", accent: RetroPalette.chromeTeal)
            }
        }
        .padding(10)
        .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromeBlue)
    }

    private func symbolRow(_ symbol: WorkspaceSymbolEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol.language.symbolName)
                .frame(width: 22)
                .foregroundStyle(RetroPalette.chromePink)

            VStack(alignment: .leading, spacing: 4) {
                Text(symbol.title)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(RetroPalette.ink)
                Text(symbol.subtitle)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
            }

            Spacer(minLength: 0)
            RetroCapsuleLabel(text: "line \(symbol.lineNumber)", accent: RetroPalette.chromeGold)
        }
        .padding(10)
        .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)
    }
}

struct ActivityCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(alignment: .leading, spacing: 14) {
                ProductivityHeader(
                    title: "Activity Center",
                    systemImage: "list.bullet.rectangle.portrait",
                    subtitle: "A calm mission log for indexing, files, diagnostics, release checks, and Git work."
                ) {
                    Button("Reindex") {
                        appState.refreshWorkspaceIndex()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                    Button("Export Diagnostics") {
                        appState.exportDiagnosticBundle()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .primary))
                }

                HStack(spacing: 10) {
                    statCard("Files", "\(appState.workspaceIndexSummary.entries.count)", "Indexed")
                    statCard("Symbols", "\(appState.workspaceIndexSummary.symbols.count)", "Workspace")
                    statCard("TODOs", "\(appState.workspaceIndexSummary.todoCount)", "Markers")
                    statCard("Checks", "\(appState.workspaceIndexSummary.warningCount)", "Warnings")
                }

                ScrollView {
                    LazyVStack(spacing: 8) {
                        if appState.activityRecords.isEmpty {
                            emptyMessage("Activity will appear here as you open files, index workspaces, run checks, and export bundles.")
                        } else {
                            ForEach(appState.activityRecords) { record in
                                activityRow(record)
                            }
                        }
                    }
                    .padding(12)
                }
                .retroInsetPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)
            }
            .padding(18)
            .frame(minWidth: 820, minHeight: 560)
            .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)
            .padding(18)
        }
    }

    private func activityRow(_ record: ActivityRecord) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: record.status.symbolName)
                .foregroundStyle(accent(for: record.status))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(record.title)
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)
                    RetroCapsuleLabel(text: record.status.displayName, accent: accent(for: record.status))
                    Spacer(minLength: 0)
                    Text(record.createdAt.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroPalette.visited)
                }

                Text(record.detail)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
                    .lineLimit(3)
            }
        }
        .padding(10)
        .retroPanel(fill: RetroPalette.panelFill, accent: accent(for: record.status))
    }
}

struct ReleaseReadinessView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(alignment: .leading, spacing: 14) {
                ProductivityHeader(
                    title: "Release Readiness",
                    systemImage: "shippingbox",
                    subtitle: "A pre-flight checklist for local builds, public DMGs, Sparkle updates, and documentation."
                ) {
                    Button("Refresh") {
                        appState.refreshReleaseReadiness()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                    Button("Export Diagnostics") {
                        appState.exportDiagnosticBundle()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .primary))
                }

                HStack(spacing: 10) {
                    statCard("Pass", "\(appState.releaseReadinessState.passCount)", "Checks")
                    statCard("Warnings", "\(appState.releaseReadinessState.warningCount)", "Review")
                    statCard("Blockers", "\(appState.releaseReadinessState.failureCount)", "Fix First")
                }

                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(appState.releaseReadinessState.items) { item in
                            readinessRow(item)
                        }
                    }
                    .padding(12)
                }
                .retroInsetPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)
            }
            .padding(18)
            .frame(minWidth: 760, minHeight: 520)
            .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)
            .padding(18)
        }
        .onAppear {
            appState.refreshReleaseReadiness()
        }
    }

    private func readinessRow(_ item: ReleaseReadinessItem) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: item.symbolName)
                .foregroundStyle(accent(for: item.tone))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.title)
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)
                    RetroCapsuleLabel(text: item.tone.rawValue, accent: accent(for: item.tone))
                }

                Text(item.detail)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .retroPanel(fill: RetroPalette.panelFill, accent: accent(for: item.tone))
    }
}

struct PerformanceHUDView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState

    private var snapshot: PerformanceSnapshot? {
        appState.performanceSnapshot
    }

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(alignment: .leading, spacing: 14) {
                ProductivityHeader(
                    title: "Performance HUD",
                    systemImage: "speedometer",
                    subtitle: "A lightweight local pulse check for the editor shell and active workspace."
                ) {
                    Button("Refresh") {
                        appState.refreshPerformanceSnapshot()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .primary))
                }

                if let snapshot {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                        statCard("Open Docs", "\(snapshot.openDocumentCount)", "Dirty \(snapshot.dirtyDocumentCount)")
                        statCard("Index Files", "\(snapshot.indexedFileCount)", "Symbols \(snapshot.indexedSymbolCount)")
                        statCard("Roots", "\(snapshot.workspaceRootCount)", "Workspace")
                        statCard("Plugins", "\(snapshot.enabledPluginCount)", "Enabled")
                        statCard("Tasks", "\(snapshot.taskCount)", "Detected")
                        statCard("Memory", String(format: "%.1f GB", snapshot.physicalMemoryGB), "System")
                    }

                    Text("Captured \(snapshot.capturedAt.formatted(date: .abbreviated, time: .standard)). System uptime \(formatDuration(snapshot.uptime)).")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(RetroPalette.link)
                        .padding(12)
                        .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeBlue)
                } else {
                    emptyMessage("No performance snapshot yet.")
                }
            }
            .padding(18)
            .frame(minWidth: 620, minHeight: 420)
            .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)
            .padding(18)
        }
        .onAppear {
            appState.refreshPerformanceSnapshot()
        }
    }
}

struct AIContextCenterView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(alignment: .leading, spacing: 14) {
                ProductivityHeader(
                    title: "AI Context Center",
                    systemImage: "brain.head.profile",
                    subtitle: appState.aiContextState.statusMessage ?? "Review workspace instructions before model calls."
                ) {
                    Button("Refresh") {
                        appState.refreshAIContextState()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                    Button("AI Workbench") {
                        appState.showAIWorkbenchPanel()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .primary))
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        RetroSectionHeader(title: "Rule Files", systemImage: "text.badge.checkmark", accent: RetroPalette.chromeBlue)
                        if appState.aiContextState.ruleFiles.isEmpty {
                            emptyMessage("No rule files found. ForgeText checks .forgetext/rules.md, AGENTS.md, CLAUDE.md, GEMINI.md, CODEX.md, and similar files.")
                        } else {
                            ForEach(appState.aiContextState.ruleFiles) { file in
                                filePreview(title: file.title, subtitle: file.url.path, text: file.text) {
                                    NSWorkspace.shared.open(file.url)
                                }
                            }
                        }

                        RetroSectionHeader(title: "Prompt Files", systemImage: "sparkles", accent: RetroPalette.chromePink)
                        if appState.aiContextState.promptFiles.isEmpty {
                            emptyMessage("Reusable prompts can live in .forgetext/prompts/*.md.")
                        } else {
                            ForEach(appState.aiContextState.promptFiles) { prompt in
                                filePreview(title: prompt.title, subtitle: prompt.relativePath, text: prompt.text) {
                                    NSWorkspace.shared.open(prompt.url)
                                }
                            }
                        }
                    }
                    .padding(12)
                }
                .retroInsetPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)
            }
            .padding(18)
            .frame(minWidth: 820, minHeight: 600)
            .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)
            .padding(18)
        }
        .onAppear {
            appState.refreshAIContextState()
        }
    }
}

struct GitHubWorkflowView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(alignment: .leading, spacing: 14) {
                ProductivityHeader(
                    title: "GitHub Workflow",
                    systemImage: "arrow.triangle.branch",
                    subtitle: appState.githubWorkflowState.statusMessage ?? "Connect local Git work to GitHub repository and PR flow."
                ) {
                    Button("Refresh") {
                        appState.refreshGitHubWorkflow()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                    Button("Git Workbench") {
                        appState.showGitWorkbenchPanel()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .primary))
                }

                HStack(spacing: 10) {
                    statCard("Branch", appState.githubWorkflowState.branchName ?? "none", "Current")
                    statCard("Changes", "\(appState.githubWorkflowState.changedFileCount)", "Working Tree")
                }

                VStack(alignment: .leading, spacing: 10) {
                    workflowCard(
                        title: "Repository",
                        detail: appState.githubWorkflowState.repositoryURL?.absoluteString ?? "No GitHub remote detected.",
                        systemImage: "globe"
                    )

                    workflowCard(
                        title: "Pull Request Compare",
                        detail: appState.githubWorkflowState.compareURL?.absoluteString ?? "Create or switch to a branch first.",
                        systemImage: "arrow.left.arrow.right"
                    )

                    HStack(spacing: 10) {
                        Button("Open Repository") {
                            appState.openGitHubRepositoryPage()
                        }
                        .buttonStyle(RetroActionButtonStyle(tone: .accent))
                        .disabled(appState.githubWorkflowState.repositoryURL == nil)

                        Button("Open Compare") {
                            appState.openGitHubComparePage()
                        }
                        .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                        .disabled(appState.githubWorkflowState.compareURL == nil)

                        Button("Refresh Git Status") {
                            appState.refreshGitStatus()
                            appState.refreshGitHubWorkflow()
                        }
                        .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                    }
                }
                .padding(12)
                .retroInsetPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)
            }
            .padding(18)
            .frame(minWidth: 720, minHeight: 480)
            .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)
            .padding(18)
        }
        .onAppear {
            appState.refreshGitHubWorkflow()
        }
    }

    private func workflowCard(title: String, detail: String, systemImage: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(RetroPalette.chromeBlue)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(RetroPalette.ink)
                Text(detail)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromeBlue)
    }
}

struct FirstRunSetupView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState

    private var steps: [(String, String, Bool, () -> Void)] {
        [
            ("Choose Workspace", "Open a folder so indexing, Git, tasks, and AI context can work.", !appState.workspaceRootURLs.isEmpty, appState.showWorkspacePlatformPanel),
            ("Index Workspace", "Build the quick-open file and symbol index.", !appState.workspaceIndexSummary.entries.isEmpty, appState.refreshWorkspaceIndex),
            ("Configure AI", "Review AI providers, rule files, and reusable prompts.", appState.selectedAIProvider != nil || !appState.aiContextState.ruleFiles.isEmpty, appState.showAIContextCenterPanel),
            ("Enable Plugins", "Review IDE plugins, tasks, snippets, and diagnostics.", !appState.enabledPlugins.isEmpty, appState.showPluginManagerPanel),
            ("Check Updates", "Confirm Sparkle, appcast, docs, and DMG readiness.", appState.releaseReadinessState.failureCount == 0, appState.showReleaseReadinessPanel),
            ("Tune Interface", "Pick the 90s chrome level, density, and editor theme.", true, appState.showThemeLabPanel),
        ]
    }

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(alignment: .leading, spacing: 14) {
                ProductivityHeader(
                    title: "First-Run Setup",
                    systemImage: "checklist",
                    subtitle: "The friendly onboarding cassette: workspace, Git, AI, plugins, updates, and the vibe."
                ) {
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .primary))
                }

                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            setupRow(index: index + 1, title: step.0, detail: step.1, isComplete: step.2, action: step.3)
                        }
                    }
                    .padding(12)
                }
                .retroInsetPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)
            }
            .padding(18)
            .frame(minWidth: 760, minHeight: 520)
            .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)
            .padding(18)
        }
        .onAppear {
            appState.refreshAIContextState()
            appState.refreshReleaseReadiness()
        }
    }

    private func setupRow(index: Int, title: String, detail: String, isComplete: Bool, action: @escaping () -> Void) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(index)")
                .font(.system(size: 13, weight: .black, design: .monospaced))
                .foregroundStyle(RetroPalette.ink)
                .frame(width: 24, height: 24)
                .retroInsetPanel(fill: RetroPalette.fieldFill, accent: isComplete ? RetroPalette.success : RetroPalette.chromeGold)

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Text(title)
                        .font(.system(size: 14, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)
                    RetroCapsuleLabel(text: isComplete ? "ready" : "todo", accent: isComplete ? RetroPalette.success : RetroPalette.warning)
                }
                Text(detail)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
            }

            Spacer(minLength: 0)

            Button(isComplete ? "Open" : "Start") {
                action()
            }
            .buttonStyle(RetroActionButtonStyle(tone: isComplete ? .secondary : .accent))
        }
        .padding(12)
        .retroPanel(fill: RetroPalette.panelFill, accent: isComplete ? RetroPalette.success : RetroPalette.chromeGold)
    }
}

struct ThemeLabView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(alignment: .leading, spacing: 14) {
                ProductivityHeader(
                    title: "Theme Lab",
                    systemImage: "paintpalette",
                    subtitle: "Keep the late-90s soul, but dial the volume for real production work."
                ) {
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .primary))
                }

                VStack(alignment: .leading, spacing: 12) {
                    RetroSectionHeader(title: "Chrome", systemImage: "rectangle.3.group", accent: RetroPalette.chromeBlue)
                    Picker("Retro Intensity", selection: Binding(
                        get: { appState.settings.chromeStyle },
                        set: { appState.setChromeStyle($0) }
                    )) {
                        ForEach(AppChromeStyle.allCases) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .pickerStyle(.segmented)

                    Picker("Density", selection: Binding(
                        get: { appState.settings.interfaceDensity },
                        set: { appState.setInterfaceDensity($0) }
                    )) {
                        ForEach(InterfaceDensity.allCases) { density in
                            Text(density.displayName).tag(density)
                        }
                    }
                    .pickerStyle(.segmented)

                    RetroSectionHeader(title: "Editor", systemImage: "doc.text", accent: RetroPalette.chromePink)
                    Picker("Theme", selection: Binding(
                        get: { appState.settings.theme },
                        set: { appState.setTheme($0) }
                    )) {
                        ForEach(EditorTheme.allCases) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)

                    Toggle("Focus Mode", isOn: Binding(
                        get: { appState.settings.focusModeEnabled },
                        set: { _ in appState.toggleFocusMode() }
                    ))
                    .toggleStyle(.switch)

                    Toggle("Inspector Panel", isOn: Binding(
                        get: { appState.settings.showsInspector },
                        set: { _ in appState.toggleInspectorPanel() }
                    ))
                    .toggleStyle(.switch)
                }
                .padding(14)
                .retroInsetPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)
            }
            .padding(18)
            .frame(minWidth: 620, minHeight: 470)
            .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)
            .padding(18)
        }
    }
}

private struct ProductivityHeader<Actions: View>: View {
    let title: String
    let systemImage: String
    let subtitle: String
    @ViewBuilder let actions: () -> Actions

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 22, weight: .black, design: .monospaced))
                .foregroundStyle(RetroPalette.ink)

            VStack(alignment: .leading, spacing: 4) {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                actions()
            }
        }
        .padding(14)
        .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)
    }
}

@MainActor
private func emptyMessage(_ message: String) -> some View {
    Text(message)
        .font(.system(size: 12, weight: .medium, design: .monospaced))
        .foregroundStyle(RetroPalette.link)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeBlue)
}

@MainActor
private func statCard(_ title: String, _ value: String, _ subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 5) {
        Text(title.uppercased())
            .font(.system(size: 10, weight: .black, design: .monospaced))
            .foregroundStyle(RetroPalette.link)
        Text(value)
            .font(.system(size: 18, weight: .black, design: .monospaced))
            .foregroundStyle(RetroPalette.ink)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
        Text(subtitle)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(RetroPalette.visited)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromeBlue)
}

@MainActor
private func filePreview(title: String, subtitle: String, text: String, openAction: @MainActor @escaping () -> Void) -> some View {
    VStack(alignment: .leading, spacing: 8) {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .black, design: .monospaced))
                    .foregroundStyle(RetroPalette.ink)
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
            Button("Open") {
                openAction()
            }
            .buttonStyle(RetroActionButtonStyle(tone: .secondary))
        }

        Text(String(text.prefix(600)))
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(RetroPalette.mutedInk)
            .lineLimit(8)
            .textSelection(.enabled)
            .padding(10)
            .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeTeal)
    }
    .padding(12)
    .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)
}

@MainActor
private func accent(for status: ActivityStatus) -> Color {
    switch status {
    case .info:
        return RetroPalette.chromeBlue
    case .running:
        return RetroPalette.chromeGold
    case .success:
        return RetroPalette.success
    case .warning:
        return RetroPalette.warning
    case .failure:
        return RetroPalette.danger
    }
}

@MainActor
private func accent(for tone: ReadinessTone) -> Color {
    switch tone {
    case .pass:
        return RetroPalette.success
    case .warning:
        return RetroPalette.warning
    case .fail:
        return RetroPalette.danger
    case .info:
        return RetroPalette.chromeBlue
    }
}

@MainActor
private func formatDuration(_ value: TimeInterval) -> String {
    let hours = Int(value / 3_600)
    let minutes = Int(value.truncatingRemainder(dividingBy: 3_600) / 60)
    return "\(hours)h \(minutes)m"
}
