import SwiftUI

struct QuickOpenView: View {
    @Environment(\.retroChromeStyle) private var chromeStyle
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label("Quick Open", systemImage: "doc.text.magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RetroPalette.ink)

                Spacer(minLength: 0)

                Text(appState.workspaceIndexSummary.statusMessage ?? "Jump around the workspace without touching the mouse.")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(RetroPalette.link)
                    .lineLimit(1)

                Button("Close") {
                    dismissOverlay()
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))
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

                Button("Reindex") {
                    appState.refreshWorkspaceIndex()
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))
            }

            if appState.workspaceIndexSummary.isIndexing {
                ProgressView("Indexing workspace...")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
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
                                    dismissOverlay()
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
                                    dismissOverlay()
                                } label: {
                                    symbolRow(symbol)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(10)
            }
            .retroInsetPanel(fill: chromeStyle == .studio ? RetroPalette.studioPanelMuted : RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)
        }
        .padding(14)
        .frame(minWidth: 720, idealWidth: 760, minHeight: 400)
        .background(chromeStyle == .studio ? RetroPalette.studioCanvasMuted : RetroPalette.pageCream)
        .retroPanel(fill: chromeStyle == .studio ? RetroPalette.studioPanel : RetroPalette.panelFill, accent: RetroPalette.chromePink)
        .padding(14)
    }

    private func indexFileRow(_ entry: WorkspaceIndexEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.language.symbolName)
                .frame(width: 22)
                .foregroundStyle(RetroPalette.chromeBlue)

            VStack(alignment: .leading, spacing: 4) {
                Text(entry.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RetroPalette.ink)
                Text(entry.subtitle)
                    .font(.system(size: 11, weight: .regular))
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
        .retroPanel(fill: chromeStyle == .studio ? RetroPalette.studioPanelMuted : RetroPalette.panelFill, accent: RetroPalette.chromeBlue)
    }

    private func symbolRow(_ symbol: WorkspaceSymbolEntry) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: symbol.language.symbolName)
                .frame(width: 22)
                .foregroundStyle(RetroPalette.chromePink)

            VStack(alignment: .leading, spacing: 4) {
                Text(symbol.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(RetroPalette.ink)
                Text(symbol.subtitle)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(RetroPalette.link)
            }

            Spacer(minLength: 0)
            RetroCapsuleLabel(text: "line \(symbol.lineNumber)", accent: RetroPalette.chromeGold)
        }
        .padding(10)
        .retroPanel(fill: chromeStyle == .studio ? RetroPalette.studioPanelMuted : RetroPalette.panelFill, accent: RetroPalette.chromePink)
    }

    private func dismissOverlay() {
        appState.showingQuickOpen = false
        appState.showingCommandPalette = false
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

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let snapshot {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                                statCard("Open Docs", "\(snapshot.openDocumentCount)", "Dirty \(snapshot.dirtyDocumentCount)")
                                statCard("Index Files", "\(snapshot.indexedFileCount)", "Symbols \(snapshot.indexedSymbolCount)")
                                statCard("Roots", "\(snapshot.workspaceRootCount)", "Workspace")
                                statCard("Plugins", "\(snapshot.enabledPluginCount)", "Enabled")
                                statCard("Tasks", "\(snapshot.taskCount)", "Detected")
                                statCard("Memory", String(format: "%.1f GB", snapshot.physicalMemoryGB), "System")
                                statCard("Runtime", snapshot.runtimeModeLabel, snapshot.safeModeEnabled ? "Safe Mode" : "Normal Session")
                            }

                            if snapshot.metrics.isEmpty {
                                emptyMessage("Open a larger file, switch views, or refresh Git insights to populate live timing probes.")
                            } else {
                                VStack(alignment: .leading, spacing: 8) {
                                    RetroSectionHeader(title: "Timing Probes", systemImage: "waveform.path.ecg", accent: RetroPalette.chromeTeal)

                                    ForEach(snapshot.metrics, id: \.kind) { metric in
                                        metricRow(metric)
                                    }
                                }
                                .padding(12)
                                .retroInsetPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeTeal)
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
                    .padding(.vertical, 2)
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

    private func metricRow(_ metric: PerformanceMetricSnapshot) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(metric.kind.displayName)
                        .font(.system(size: 13, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)
                    RetroCapsuleLabel(text: "\(metric.sampleCount) sample\(metric.sampleCount == 1 ? "" : "s")", accent: RetroPalette.chromeBlue)
                }

                Text(metric.lastDetail ?? "No detail captured")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)

                if let payload = metric.lastPayload {
                    Text(payload)
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(RetroPalette.mutedInk)
                }
            }

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 4) {
                Text("Last \(formatMilliseconds(metric.lastDurationMS))")
                Text("Avg \(formatMilliseconds(metric.averageDurationMS))")
                Text("P95 \(formatMilliseconds(metric.p95DurationMS))")
                Text("Max \(formatMilliseconds(metric.maxDurationMS))")
                Text(metric.isWithinBudget ? "Within budget" : "Over budget")
                    .foregroundStyle(metric.isWithinBudget ? RetroPalette.success : RetroPalette.warning)
            }
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(RetroPalette.ink)
        }
        .padding(10)
        .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromeTeal)
    }

    private func formatMilliseconds(_ value: Double) -> String {
        String(format: "%.1f ms", value)
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

private enum GitHubWorkflowMode: String, CaseIterable, Identifiable {
    case pullRequests = "Pull Requests"
    case issues = "Issues"
    case create = "Create PR"
    case release = "Draft Release"
    var id: String { rawValue }
}

struct GitHubWorkflowView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState
    @State private var mode: GitHubWorkflowMode = .pullRequests
    @State private var selectedPullRequestNumber: Int?
    @State private var selectedIssueNumber: Int?
    @State private var commentDraft = ""
    @State private var showingCommentConfirmation = false
    @State private var showingPRConfirmation = false
    @State private var showingReleaseConfirmation = false
    @State private var prTitle = ""
    @State private var prBody = ""
    @State private var prBase = "main"
    @State private var prHead = ""
    @State private var prIsDraft = true
    @State private var releaseTag = ""
    @State private var releaseTitle = ""
    @State private var releaseNotes = ""
    @State private var releaseTarget = ""

    private var selectedPullRequest: GitHubPullRequestSummary? {
        appState.githubWorkflowState.pullRequests.first { $0.number == selectedPullRequestNumber }
    }

    private var selectedIssue: GitHubIssueSummary? {
        appState.githubWorkflowState.issues.first { $0.number == selectedIssueNumber }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.triangle.branch")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 38, height: 38)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))
                VStack(alignment: .leading, spacing: 2) {
                    Text("GitHub Team Workflow").font(.system(size: 19, weight: .semibold))
                    Text(appState.githubWorkflowState.statusMessage ?? "PRs, issues, checks, review threads, and releases use your existing gh authentication.")
                        .font(.system(size: 11)).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer()
                Picker("Workflow", selection: $mode) {
                    ForEach(GitHubWorkflowMode.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .frame(width: 430)
                Button("Refresh") { refreshCurrentMode() }
                    .buttonStyle(.bordered)
                    .disabled(appState.githubWorkflowState.repositoryURL == nil)
                Menu("More") {
                    Button("Open Repository") { appState.openGitHubRepositoryPage() }
                    Button("Open Compare") { appState.openGitHubComparePage() }
                    Divider()
                    Button("Git Workbench") { appState.showGitWorkbenchPanel() }
                }
                Button("Close") { dismiss() }.buttonStyle(.borderedProminent)
            }
            .padding(16)
            .background(.bar)
            Divider()

            if mode == .create {
                createPullRequestForm
            } else if mode == .release {
                draftReleaseForm
            } else {
                HSplitView {
                    navigationPane.frame(minWidth: 360)
                    detailPane.padding(18).frame(minWidth: 480)
                }
            }
        }
        .frame(minWidth: 980, minHeight: 650)
        .onAppear { appState.refreshGitHubWorkflow() }
        .onChange(of: selectedPullRequestNumber) { _, _ in
            if let selectedPullRequest { appState.refreshGitHubReviewContext(for: selectedPullRequest) }
        }
        .confirmationDialog("Post comment to PR #\(selectedPullRequest?.number ?? 0)?", isPresented: $showingCommentConfirmation) {
            Button("Post Comment") {
                guard let selectedPullRequest else { return }
                appState.postGitHubPullRequestComment(commentDraft, pullRequest: selectedPullRequest)
                commentDraft = ""
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This sends the comment through the authenticated GitHub CLI.") }
        .confirmationDialog("Create this pull request?", isPresented: $showingPRConfirmation) {
            Button(prIsDraft ? "Create Draft PR" : "Create Pull Request") {
                appState.createGitHubPullRequest(
                    title: prTitle, body: prBody, baseBranch: prBase,
                    headBranch: prHead.isEmpty ? nil : prHead, isDraft: prIsDraft
                )
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("The branch and description will be sent to GitHub using gh.") }
        .confirmationDialog("Create draft release \(releaseTag)?", isPresented: $showingReleaseConfirmation) {
            Button("Create Draft Release") {
                appState.draftGitHubRelease(
                    tag: releaseTag, title: releaseTitle, notes: releaseNotes,
                    target: releaseTarget.isEmpty ? nil : releaseTarget
                )
            }
            Button("Cancel", role: .cancel) {}
        } message: { Text("The release remains a draft until it is published on GitHub.") }
    }

    @ViewBuilder private var navigationPane: some View {
        VStack(spacing: 0) {
            HStack {
                Label(appState.githubWorkflowState.branchName ?? "No branch", systemImage: "arrow.triangle.branch")
                Spacer()
                Text("\(appState.githubWorkflowState.changedFileCount) local changes").foregroundStyle(.secondary)
            }
            .font(.system(size: 11, weight: .medium)).padding(12)
            Divider()
            if mode == .issues {
                if appState.githubWorkflowState.issues.isEmpty {
                    ContentUnavailableView("No issues loaded", systemImage: "smallcircle.filled.circle", description: Text("Select Refresh to load open issues."))
                } else {
                    List(appState.githubWorkflowState.issues, selection: $selectedIssueNumber) { issue in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("#\(issue.number) \(issue.title)").font(.system(size: 12, weight: .semibold)).lineLimit(2)
                            Text(issue.labels.joined(separator: " • ")).font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                        .tag(issue.number).padding(.vertical, 4)
                    }
                    .listStyle(.inset)
                }
            } else if appState.githubWorkflowState.pullRequests.isEmpty {
                ContentUnavailableView("No pull requests loaded", systemImage: "arrow.triangle.branch", description: Text("Select Refresh to load open pull requests."))
            } else {
                List(appState.githubWorkflowState.pullRequests, selection: $selectedPullRequestNumber) { pullRequest in
                    VStack(alignment: .leading, spacing: 4) {
                        Text("#\(pullRequest.number) \(pullRequest.title)").font(.system(size: 12, weight: .semibold)).lineLimit(2)
                        Text("\(pullRequest.headBranch) into \(pullRequest.baseBranch) • @\(pullRequest.authorLogin)")
                            .font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                    }
                    .tag(pullRequest.number).padding(.vertical, 4)
                }
                .listStyle(.inset)
            }
        }
    }

    @ViewBuilder private var detailPane: some View {
        if mode == .issues, let issue = selectedIssue {
            VStack(alignment: .leading, spacing: 14) {
                Text("#\(issue.number) \(issue.title)").font(.system(size: 17, weight: .semibold))
                Text(issue.labels.isEmpty ? "No labels" : issue.labels.joined(separator: ", ")).foregroundStyle(.secondary)
                Text(issue.assignees.isEmpty ? "Unassigned" : "Assigned to \(issue.assignees.joined(separator: ", "))")
                Button("Open Issue on GitHub") { NSWorkspace.shared.open(issue.url) }.buttonStyle(.borderedProminent)
                Spacer()
            }
        } else if let pullRequest = selectedPullRequest {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("#\(pullRequest.number) \(pullRequest.title)").font(.system(size: 17, weight: .semibold))
                            Text("\(pullRequest.headBranch) into \(pullRequest.baseBranch)").font(.system(size: 11, design: .monospaced)).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Open on GitHub") { appState.openGitHubPullRequest(pullRequest) }.buttonStyle(.bordered)
                    }
                    reviewContext
                    Text("Repository comment").font(.system(size: 12, weight: .semibold))
                    TextEditor(text: $commentDraft).frame(minHeight: 110)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.secondary.opacity(0.25)))
                    HStack {
                        Spacer()
                        Button("Post Comment") { showingCommentConfirmation = true }.buttonStyle(.borderedProminent)
                            .disabled(commentDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        } else {
            ContentUnavailableView("Select an item", systemImage: "text.bubble")
        }
    }

    private var reviewContext: some View {
        VStack(alignment: .leading, spacing: 12) {
            GroupBox("Checks") {
                if appState.githubWorkflowState.checks.isEmpty {
                    Text("No checks reported.").foregroundStyle(.secondary)
                } else {
                    ForEach(appState.githubWorkflowState.checks) { check in
                        HStack {
                            Image(systemName: check.conclusion == "SUCCESS" ? "checkmark.circle.fill" : "circle.dotted")
                            Text(check.name)
                            Spacer()
                            Text(check.conclusion ?? check.state).font(.system(size: 10)).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            GroupBox("Review Threads") {
                if appState.githubWorkflowState.reviewThreads.isEmpty {
                    Text("No inline review comments reported.").foregroundStyle(.secondary)
                } else {
                    ForEach(appState.githubWorkflowState.reviewThreads.prefix(100)) { thread in
                        VStack(alignment: .leading, spacing: 3) {
                            Text("\(thread.path)\(thread.line.map { ":\($0)" } ?? "") • @\(thread.author)")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                            Text(thread.body).font(.system(size: 11)).textSelection(.enabled)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    private var createPullRequestForm: some View {
        Form {
            Section("Pull Request") {
                TextField("Title", text: $prTitle)
                HStack { TextField("Base branch", text: $prBase); TextField("Head branch (current if blank)", text: $prHead) }
                Toggle("Create as draft", isOn: $prIsDraft)
                TextEditor(text: $prBody).frame(minHeight: 220).accessibilityLabel("Pull request description")
                HStack { Spacer(); Button("Review and Create") { showingPRConfirmation = true }.buttonStyle(.borderedProminent).disabled(prTitle.isEmpty || prBase.isEmpty) }
            }
        }
        .formStyle(.grouped).padding(18)
    }

    private var draftReleaseForm: some View {
        Form {
            Section("Draft Release") {
                HStack { TextField("Tag", text: $releaseTag); TextField("Target branch or SHA (optional)", text: $releaseTarget) }
                TextField("Release title", text: $releaseTitle)
                TextEditor(text: $releaseNotes).frame(minHeight: 240).accessibilityLabel("Release notes")
                HStack { Spacer(); Button("Review Draft Release") { showingReleaseConfirmation = true }.buttonStyle(.borderedProminent).disabled(releaseTag.isEmpty || releaseTitle.isEmpty) }
            }
        }
        .formStyle(.grouped).padding(18)
    }

    private func refreshCurrentMode() {
        switch mode {
        case .pullRequests: appState.refreshGitHubPullRequests()
        case .issues: appState.refreshGitHubIssues()
        case .create, .release: appState.refreshGitHubWorkflow()
        }
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
            ("Tune Interface", "Pick a workbench style, density, and editor theme.", true, appState.showThemeLabPanel),
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 13) {
                Image(systemName: "checklist")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.tint)
                    .frame(width: 38, height: 38)
                    .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Set Up ForgeText")
                        .font(.system(size: 19, weight: .semibold))
                    Text("Choose a comfortable layout, then connect only the tools you need.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button("Close") {
                    appState.completeFirstRunExperienceIfNeeded()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 16)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    presetChooserCard

                    VStack(alignment: .leading, spacing: 5) {
                        Text("Optional setup")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Editing works immediately. These steps enable workspace and engineering features.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            setupRow(index: index + 1, title: step.0, detail: step.1, isComplete: step.2, action: step.3)
                            if index < steps.count - 1 {
                                Divider().padding(.leading, 48)
                            }
                        }
                    }
                    .background(.background, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.18)))
                }
                .padding(22)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(minWidth: 720, idealWidth: 780, minHeight: 560, idealHeight: 680)
        .onAppear {
            appState.refreshAIContextState()
            appState.refreshReleaseReadiness()
        }
        .onDisappear {
            appState.completeFirstRunExperienceIfNeeded()
        }
    }

    private var presetChooserCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Starting layout")
                    .font(.system(size: 15, weight: .semibold))
                Text("Quiet UI is recommended for daily editing. You can change this later without losing custom settings.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Picker("Starting layout", selection: Binding(
                get: { appState.selectedWorkbenchPreset ?? .quiet },
                set: { appState.applyWorkbenchPreset($0, markFirstRunComplete: true) }
            )) {
                ForEach(WorkbenchPreset.allCases) { preset in
                    Text(preset.displayName).tag(preset)
                }
            }
            .labelsHidden()
            .pickerStyle(.segmented)

            Text((appState.selectedWorkbenchPreset ?? .quiet).summary)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.18)))
    }

    private func setupRow(index: Int, title: String, detail: String, isComplete: Bool, action: @escaping () -> Void) -> some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "\(index).circle")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(isComplete ? Color.green : Color.secondary)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)

            Button(isComplete ? "Open" : "Start") {
                action()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
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
                    subtitle: "Tune the workbench style, density, layout, and editor theme for real production work."
                ) {
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .primary))
                }

                VStack(alignment: .leading, spacing: 12) {
                    RetroSectionHeader(title: "Workbench", systemImage: "switch.2", accent: RetroPalette.chromeTeal)
                    HStack(spacing: 10) {
                        ForEach(WorkbenchPreset.allCases) { preset in
                            Button(preset.displayName) {
                                appState.applyWorkbenchPreset(preset)
                            }
                            .buttonStyle(RetroActionButtonStyle(
                                tone: appState.selectedWorkbenchPreset == preset ? .accent : .secondary
                            ))
                        }
                    }

                    if appState.canRestoreCustomWorkbenchAppearance {
                        Button("Restore Custom Layout") {
                            appState.restoreCustomWorkbenchAppearance()
                        }
                        .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                    }

                    Text(appState.activeWorkbenchPresetSummary)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(RetroPalette.link)

                    RetroSectionHeader(title: "Chrome", systemImage: "rectangle.3.group", accent: RetroPalette.chromeBlue)
                    Picker("Workbench Style", selection: Binding(
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
