import SwiftUI

struct EngineeringWorkbenchView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState
    @State private var testFilter = ""
    @State private var investigationNotes: [UUID: String] = [:]
    @State private var showingDevContainerConfirmation = false

    private var selectedSection: Binding<EngineeringWorkbenchSection> {
        Binding(
            get: { appState.engineeringWorkbenchState.selectedSection },
            set: { appState.engineeringWorkbenchState.selectedSection = $0 }
        )
    }

    var body: some View {
        NavigationSplitView {
            List(selection: selectedSection) {
                Section("Workspace") {
                    navigationRow(.overview)
                    navigationRow(.intelligence)
                    navigationRow(.review)
                    navigationRow(.tests)
                }

                Section("Operations") {
                    navigationRow(.remote)
                    navigationRow(.investigations)
                    navigationRow(.data)
                    navigationRow(.aiChanges)
                }

                Section("Organization") {
                    navigationRow(.enterprise)
                    navigationRow(.profiles)
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 210, ideal: 230, max: 270)
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(appState.workspaceTrustMode == .trusted ? "Trusted Workspace" : "Restricted Workspace")
                        .font(.system(size: 11, weight: .semibold))
                    Text(appState.activeWorkspaceURL?.lastPathComponent ?? "No folder open")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(.bar)
            }
        } detail: {
            VStack(spacing: 0) {
                header
                Divider()
                ScrollView {
                    sectionContent
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .padding(24)
                }
                .background(WorkbenchColors.canvas)
            }
        }
        .frame(minWidth: 980, idealWidth: 1160, minHeight: 680, idealHeight: 760)
        .onAppear {
            appState.refreshEngineeringWorkbench()
        }
        .confirmationDialog(
            "Start Development Container?",
            isPresented: $showingDevContainerConfirmation,
            titleVisibility: .visible
        ) {
            Button("Start Container") { appState.startDevContainer() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The repository's devcontainer configuration may build images, download packages, mount files, and run lifecycle commands. Continue only if you trust this workspace.")
        }
    }

    private func navigationRow(_ section: EngineeringWorkbenchSection) -> some View {
        Label(section.title, systemImage: section.symbolName)
            .tag(section)
            .accessibilityLabel(section.title)
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: appState.engineeringWorkbenchState.selectedSection.symbolName)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(WorkbenchColors.accent)
                .frame(width: 36, height: 36)
                .background(WorkbenchColors.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 9))

            VStack(alignment: .leading, spacing: 2) {
                Text(appState.engineeringWorkbenchState.selectedSection.title)
                    .font(.system(size: 18, weight: .semibold))
                Text(appState.engineeringWorkbenchState.statusMessage ?? "Focused engineering workflows without crowding the editor.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Menu {
                ForEach(EnterpriseOperationalMode.allCases) { mode in
                    Button {
                        appState.applyOperationalMode(mode)
                    } label: {
                        Label(mode.title, systemImage: mode.systemImage)
                    }
                }
            } label: {
                Label(appState.engineeringWorkbenchState.operationalMode.title, systemImage: appState.engineeringWorkbenchState.operationalMode.systemImage)
            }
            .menuStyle(.borderlessButton)
            .help("Switch workflow without changing saved appearance settings")

            if appState.engineeringWorkbenchState.isRefreshing {
                ProgressView()
                    .controlSize(.small)
            }

            Button {
                appState.refreshEngineeringWorkbench()
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.bordered)

            Button("Close") {
                dismiss()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .background(WorkbenchColors.surface)
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch appState.engineeringWorkbenchState.selectedSection {
        case .overview:
            overviewSection
        case .intelligence:
            intelligenceSection
        case .review:
            reviewSection
        case .tests:
            testsSection
        case .remote:
            remoteSection
        case .investigations:
            investigationsSection
        case .data:
            dataSection
        case .aiChanges:
            aiChangesSection
        case .enterprise:
            enterpriseSection
        case .profiles:
            profilesSection
        }
    }

    private var overviewSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 0) {
                summaryMetric(value: "\(appState.engineeringWorkbenchState.health.score)", label: "Health")
                Divider().frame(height: 34)
                summaryMetric(value: "\(appState.workspaceIndexSummary.entries.count)", label: "Files")
                Divider().frame(height: 34)
                summaryMetric(value: "\(appState.engineeringWorkbenchState.discoveredTests.count)", label: "Tests")
                Divider().frame(height: 34)
                summaryMetric(value: "\(appState.gitPanelState.changedFiles.count)", label: "Changes")
            }
            .padding(.vertical, 9)
            .background(WorkbenchColors.surface, in: RoundedRectangle(cornerRadius: 9))
            .overlay(RoundedRectangle(cornerRadius: 9).stroke(WorkbenchColors.border))

            sectionHeading("Current signals", detail: "Only actionable workspace state is shown here.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 12) {
                ForEach(appState.engineeringWorkbenchState.health.findings) { finding in
                    Button {
                        appState.engineeringWorkbenchState.selectedSection = finding.section
                    } label: {
                        healthCard(finding)
                    }
                    .buttonStyle(.plain)
                }
            }

        }
    }

    private var intelligenceSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            sectionHeading("Definitions and references", detail: "Uses the workspace index now and reports installed language-server adapters for richer capabilities.")

            HStack(spacing: 10) {
                TextField("Symbol name or use the current editor selection", text: Binding(
                    get: { appState.engineeringWorkbenchState.navigationSymbol },
                    set: { appState.engineeringWorkbenchState.navigationSymbol = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .onSubmit { appState.findLanguageSymbol() }

                Button("Find") {
                    appState.findLanguageSymbol()
                }
                .buttonStyle(.borderedProminent)
            }

            HStack(spacing: 8) {
                Button("Definition") { appState.requestLanguageLocations(references: false) }
                    .buttonStyle(.bordered)
                Button("References") { appState.requestLanguageLocations(references: true) }
                    .buttonStyle(.bordered)
                Button("Completion") { appState.requestLanguageCompletions() }
                    .buttonStyle(.bordered)
                Button("Code Actions") { appState.requestLanguageCodeActions() }
                    .buttonStyle(.bordered)
                Spacer()
                TextField("Rename symbol", text: Binding(
                    get: { appState.engineeringWorkbenchState.languageRenameDraft },
                    set: { appState.engineeringWorkbenchState.languageRenameDraft = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
                .accessibilityLabel("New symbol name")
                Button("Preview Rename") { appState.previewLanguageRename() }
                    .buttonStyle(.borderedProminent)
            }

            if !appState.engineeringWorkbenchState.languageCompletions.isEmpty {
                semanticResultsCard(title: "Completions") {
                    ForEach(appState.engineeringWorkbenchState.languageCompletions.prefix(80)) { completion in
                        Button {
                            appState.insertLanguageCompletion(completion)
                        } label: {
                            HStack {
                                Text(completion.label).font(.system(size: 11, weight: .semibold, design: .monospaced))
                                if let detail = completion.detail {
                                    Text(detail).font(.system(size: 10)).foregroundStyle(.secondary).lineLimit(1)
                                }
                                Spacer()
                                Text("Insert").font(.system(size: 10)).foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !appState.engineeringWorkbenchState.languageLocations.isEmpty {
                semanticResultsCard(title: "Semantic Locations") {
                    ForEach(appState.engineeringWorkbenchState.languageLocations.prefix(200)) { location in
                        Button {
                            appState.openLanguageLocation(location)
                        } label: {
                            HStack {
                                Text(URL(string: location.documentURI)?.lastPathComponent ?? location.documentURI)
                                Spacer()
                                Text("Ln \(location.range.start.line + 1):\(location.range.start.character + 1)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !appState.engineeringWorkbenchState.languageCodeActions.isEmpty {
                semanticResultsCard(title: "Code Actions") {
                    ForEach(appState.engineeringWorkbenchState.languageCodeActions) { action in
                        Button {
                            appState.previewLanguageCodeAction(action)
                        } label: {
                            HStack {
                                Image(systemName: action.isPreferred ? "star.fill" : "wrench.and.screwdriver")
                                Text(action.title)
                                Spacer()
                                Text(action.edits.isEmpty ? "Command blocked" : "Review edits")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !appState.engineeringWorkbenchState.languageRenameEdits.isEmpty {
                HStack {
                    Label(
                        "\(appState.engineeringWorkbenchState.languageRenameEdits.count) reviewed workspace edits are ready",
                        systemImage: "checklist"
                    )
                    .font(.system(size: 11, weight: .semibold))
                    Spacer()
                    Button("Discard") { appState.engineeringWorkbenchState.languageRenameEdits = [] }
                        .buttonStyle(.bordered)
                    Button("Apply to Open Documents") { appState.applyLanguageRenamePreview() }
                        .buttonStyle(.borderedProminent)
                }
                .padding(12)
                .workbenchCard()
            }

            if !appState.engineeringWorkbenchState.languageDiagnostics.isEmpty {
                semanticResultsCard(title: "Server Diagnostics") {
                    ForEach(appState.engineeringWorkbenchState.languageDiagnostics.prefix(200)) { diagnostic in
                        HStack(alignment: .top) {
                            Image(systemName: diagnostic.severity == 1 ? "xmark.octagon.fill" : "exclamationmark.triangle.fill")
                                .foregroundStyle(diagnostic.severity == 1 ? .red : .orange)
                            Text(diagnostic.message).font(.system(size: 11)).textSelection(.enabled)
                            Spacer()
                            Text("Ln \(diagnostic.range.start.line + 1)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            if !appState.engineeringWorkbenchState.navigationHits.isEmpty {
                VStack(spacing: 0) {
                    ForEach(appState.engineeringWorkbenchState.navigationHits.prefix(300)) { hit in
                        Button {
                            appState.openLanguageNavigationHit(hit)
                        } label: {
                            HStack(alignment: .top, spacing: 12) {
                                Image(systemName: hit.kind == .definition ? "scope" : "text.magnifyingglass")
                                    .foregroundStyle(hit.kind == .definition ? WorkbenchColors.accent : .secondary)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(hit.relativePath):\(hit.lineNumber)")
                                        .font(.system(size: 12, weight: .semibold))
                                    Text(hit.preview)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                Spacer()
                                Text(hit.kind.rawValue.capitalized)
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(11)
                        }
                        .buttonStyle(.plain)
                        Divider()
                    }
                }
                .workbenchCard()
            }

            sectionHeading("Language-server adapters", detail: "Servers execute only in trusted workspaces and resolve from trusted toolchain locations.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 12) {
                ForEach(appState.engineeringWorkbenchState.languageServers) { server in
                    let session = appState.engineeringWorkbenchState.languageSessions.first { $0.serverID == server.id }
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text(server.displayName)
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            statusBadge(server.availability == .ready ? "Ready" : server.availability.rawValue.capitalized, tone: server.availability == .ready ? .healthy : .informational)
                        }
                        Text(server.languages.map(\.displayName).joined(separator: ", "))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text(server.capabilities.joined(separator: " • "))
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                        if let version = server.version {
                            Text(version)
                                .font(.system(size: 10, design: .monospaced))
                                .lineLimit(1)
                        }
                        if let session {
                            Text(session.lastError ?? session.negotiatedCapabilities.prefix(6).joined(separator: " • "))
                                .font(.system(size: 10))
                                .foregroundStyle(session.state == .failed ? .red : .secondary)
                                .lineLimit(2)
                        }
                        HStack {
                            Spacer()
                            if session?.state == .running || session?.state == .starting {
                                Button(session?.state == .starting ? "Starting..." : "Stop") {
                                    appState.stopLanguageServer(server)
                                }
                                .buttonStyle(.bordered)
                                .disabled(session?.state == .starting)
                            } else {
                                Button("Start Session") {
                                    appState.startLanguageServer(server)
                                }
                                .buttonStyle(.borderedProminent)
                                .disabled(server.availability != .ready)
                            }
                        }
                    }
                    .padding(14)
                    .workbenchCard()
                }
            }

            sectionHeading("Debug adapters", detail: "Adapters run only on explicit request. Probe performs a bounded DAP initialize/disconnect handshake without launching user code.")
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 12) {
                ForEach(appState.engineeringWorkbenchState.debugAdapters) { adapter in
                    let probe = appState.engineeringWorkbenchState.debugAdapterProbes.first { $0.adapterID == adapter.id }
                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text(adapter.displayName)
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            statusBadge(
                                probe == nil ? adapter.availability.rawValue.capitalized : "Handshake verified",
                                tone: probe == nil ? .informational : .healthy
                            )
                        }
                        Text(adapter.languages.map(\.displayName).joined(separator: ", "))
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        if let probe {
                            Text("Configuration completion: \(probe.supportsConfigurationDoneRequest ? "yes" : "no") • Function breakpoints: \(probe.supportsFunctionBreakpoints ? "yes" : "no")")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        HStack {
                            Spacer()
                            Button("Verify Adapter") { appState.probeDebugAdapter(adapter) }
                                .buttonStyle(.bordered)
                                .disabled(adapter.availability != .ready)
                        }
                    }
                    .padding(14)
                    .workbenchCard()
                }
            }
        }
    }

    private func semanticResultsCard<Content: View>(
        title: String,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        DisclosureGroup(title) {
            VStack(alignment: .leading, spacing: 4) {
                content()
            }
            .padding(.top, 8)
        }
        .font(.system(size: 12, weight: .semibold))
        .padding(12)
        .workbenchCard()
    }

    private var reviewSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                sectionHeading("Working tree", detail: "Review before staging. Advanced branch and remote actions remain in Git Workbench.")
                Spacer()
                Button("Refresh Git") { appState.refreshGitWorkbench() }
                    .buttonStyle(.bordered)
                Button("Git Workbench") { appState.showGitWorkbenchPanel() }
                    .buttonStyle(.bordered)
            }

            if let summary = appState.gitRepositorySummary {
                HStack(spacing: 10) {
                    statusBadge(summary.branchName, tone: .informational)
                    statusBadge("\(summary.modifiedCount) modified", tone: summary.modifiedCount > 0 ? .attention : .healthy)
                    statusBadge("\(summary.stagedCount) staged", tone: .healthy)
                    if summary.conflictedCount > 0 {
                        statusBadge("\(summary.conflictedCount) conflicts", tone: .blocked)
                    }
                }
            }

            if appState.gitPanelState.changedFiles.isEmpty {
                emptyState("No working-tree changes", detail: "This repository is clean, or the active folder is not a Git repository.", systemImage: "checkmark.circle")
            } else {
                VStack(spacing: 0) {
                    ForEach(appState.gitPanelState.changedFiles) { file in
                        HStack(spacing: 12) {
                            Image(systemName: file.isConflicted ? "exclamationmark.triangle" : "doc.text")
                                .foregroundStyle(file.isConflicted ? .red : WorkbenchColors.accent)
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(file.displayName)
                                    .font(.system(size: 13, weight: .semibold))
                                Text(file.relativePath)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            statusBadge(file.statusSummary, tone: file.isConflicted ? .blocked : .informational)
                            Button("Review Hunks") { appState.loadGitHunkReview(file) }
                                .buttonStyle(.bordered)
                            Button {
                                appState.reviewGitFile(file)
                            } label: {
                                Image(systemName: "rectangle.split.2x1")
                            }
                            .buttonStyle(.bordered)
                            .help("Compare with Git HEAD")
                            if file.indexStatus == " " || file.indexStatus == "?" {
                                Button("Stage") { appState.stageGitChangedFile(file) }
                                    .buttonStyle(.borderedProminent)
                            } else {
                                Button("Unstage") { appState.unstageGitChangedFile(file) }
                                    .buttonStyle(.bordered)
                            }
                        }
                        .padding(12)
                        Divider()
                    }
                }
                .workbenchCard()
            }

            if let changeSet = appState.engineeringWorkbenchState.gitReviewChangeSet {
                sectionHeading("Hunk review", detail: "Only checked hunks are staged. The working file is not rewritten.")
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(changeSet.title)
                                .font(.system(size: 13, weight: .semibold))
                            Text("\(changeSet.approvedHunkCount) of \(changeSet.hunkCount) hunks selected")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Stage Selected") { appState.stageApprovedGitHunks() }
                            .buttonStyle(.borderedProminent)
                            .disabled(changeSet.approvedHunkCount == 0)
                    }

                    ForEach(changeSet.files) { file in
                        ForEach(file.hunks) { hunk in
                            Toggle(isOn: Binding(
                                get: { hunk.isApproved },
                                set: { appState.setGitReviewHunkApproval(hunk.id, approved: $0) }
                            )) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(hunk.header)
                                        .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    Text(hunk.body)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(10)
                                        .textSelection(.enabled)
                                }
                            }
                            .toggleStyle(.checkbox)
                            .padding(10)
                            .background(WorkbenchColors.canvas, in: RoundedRectangle(cornerRadius: 7))
                        }
                    }
                }
                .padding(14)
                .workbenchCard()
            }

            if appState.engineeringWorkbenchState.selectedReviewFileID != nil {
                DisclosureGroup("File history (\(appState.engineeringWorkbenchState.gitFileHistory.count))") {
                    VStack(spacing: 0) {
                        ForEach(appState.engineeringWorkbenchState.gitFileHistory) { entry in
                            HStack(spacing: 10) {
                                Text(entry.shortCommitHash)
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(WorkbenchColors.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.summary)
                                        .font(.system(size: 11, weight: .medium))
                                    Text("\(entry.author) • \(entry.relativeDate)")
                                        .font(.system(size: 9))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 7)
                            Divider()
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(13)
                .workbenchCard()

                DisclosureGroup("Repository worktrees (\(appState.engineeringWorkbenchState.gitWorktrees.count))") {
                    VStack(spacing: 0) {
                        ForEach(appState.engineeringWorkbenchState.gitWorktrees) { worktree in
                            HStack(spacing: 10) {
                                Image(systemName: worktree.isLocked ? "lock.fill" : "arrow.triangle.branch")
                                    .foregroundStyle(worktree.isLocked ? .orange : WorkbenchColors.accent)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(worktree.displayName)
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(worktree.path)
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                statusBadge(worktree.branchLabel, tone: .informational)
                            }
                            .padding(.vertical, 7)
                            Divider()
                        }
                    }
                    .padding(.top, 8)
                }
                .padding(13)
                .workbenchCard()
            }
        }
    }

    private var testsSection: some View {
        let filteredTests = appState.engineeringWorkbenchState.discoveredTests.filter { test in
            testFilter.isEmpty || [test.name, test.relativePath, test.framework.displayName]
                .joined(separator: " ")
                .localizedCaseInsensitiveContains(testFilter)
        }

        return VStack(alignment: .leading, spacing: 18) {
            HStack {
                sectionHeading("Discovered tests", detail: "XCTest, Pytest, and JavaScript tests are discovered without running repository code.")
                Spacer()
                Button("Run Task Suite") { appState.showTestExplorerPanel() }
                    .buttonStyle(.bordered)
            }

            TextField("Filter tests", text: $testFilter)
                .textFieldStyle(.roundedBorder)

            if filteredTests.isEmpty {
                emptyState("No tests discovered", detail: "Open or reindex a workspace containing recognized test files.", systemImage: "checkmark.circle")
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(filteredTests.prefix(500)) { test in
                        let result = appState.engineeringWorkbenchState.testResults.first { $0.testID == test.id }
                        HStack(spacing: 12) {
                            Image(systemName: testIcon(result?.status))
                                .foregroundStyle(testColor(result?.status))
                                .frame(width: 22)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(test.name)
                                    .font(.system(size: 13, weight: .semibold))
                                Text("\(test.framework.displayName) • \(test.relativePath):\(test.lineNumber)")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if let result {
                                Text(String(format: "%.2fs", result.duration))
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            Button("Open") {
                                appState.openIndexedSymbol(fileURL: URL(fileURLWithPath: test.filePath), lineNumber: test.lineNumber)
                                dismiss()
                            }
                            .buttonStyle(.bordered)
                            Button("Run") { appState.runDiscoveredTest(test) }
                                .buttonStyle(.borderedProminent)
                        }
                        .padding(11)
                        .workbenchCard()
                    }
                }
            }

            sectionHeading("Coverage", detail: "ForgeText reads bounded LCOV reports without executing a coverage tool during refresh.")
            if appState.engineeringWorkbenchState.coverageFiles.isEmpty {
                emptyState("No LCOV report found", detail: "Run a coverage task to generate coverage/lcov.info, then refresh.", systemImage: "chart.bar.doc.horizontal")
            } else {
                ForEach(appState.engineeringWorkbenchState.coverageFiles.prefix(100)) { file in
                    HStack {
                        Text(file.relativePath)
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(1)
                        Spacer()
                        ProgressView(value: file.percentage, total: 100)
                            .frame(width: 160)
                        Text(String(format: "%.1f%%", file.percentage))
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .frame(width: 54, alignment: .trailing)
                    }
                    .padding(10)
                    .workbenchCard()
                }
            }
        }
    }

    private var remoteSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeading("Development container", detail: "Detect and start a trusted devcontainer environment explicitly; repository lifecycle commands never run during discovery.")
            if let configuration = appState.engineeringWorkbenchState.devContainerConfiguration {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "shippingbox")
                        .foregroundStyle(WorkbenchColors.accent)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(configuration.name)
                            .font(.system(size: 13, weight: .semibold))
                        Text(configuration.configurationPath)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text(appState.engineeringWorkbenchState.devContainerRunState.message)
                            .font(.system(size: 10))
                            .foregroundStyle(appState.engineeringWorkbenchState.devContainerRunState.phase == .failed ? .red : .secondary)
                            .lineLimit(3)
                        if configuration.declaresLifecycleCommands {
                            Text("This configuration declares lifecycle commands.")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                    statusBadge(appState.engineeringWorkbenchState.devContainerRunState.phase.rawValue.capitalized, tone: appState.engineeringWorkbenchState.devContainerRunState.phase == .running ? .healthy : .informational)
                    Button("Open Config") { NSWorkspace.shared.open(URL(fileURLWithPath: configuration.configurationPath)) }
                        .buttonStyle(.bordered)
                    Button("Start") { showingDevContainerConfirmation = true }
                        .buttonStyle(.borderedProminent)
                        .disabled(configuration.cliPath == nil || appState.engineeringWorkbenchState.devContainerRunState.phase == .starting)
                }
                .padding(14)
                .workbenchCard()
            } else {
                emptyState("No development container", detail: "Add .devcontainer/devcontainer.json to make the environment reproducible.", systemImage: "shippingbox")
            }

            HStack {
                sectionHeading("Saved remote workspaces", detail: "Reconnect to known hosts without turning the main editor into a remote dashboard.")
                Spacer()
                Button("Remote Tools") { appState.openRemotePanel() }
                    .buttonStyle(.bordered)
                Button("Save Current") { appState.saveRemoteWorkspaceSession() }
                    .buttonStyle(.borderedProminent)
            }

            if appState.engineeringWorkbenchState.remoteSessions.isEmpty {
                emptyState("No saved remote workspaces", detail: "Open a remote location, set its search root, then save it here.", systemImage: "network")
            } else {
                ForEach(appState.engineeringWorkbenchState.remoteSessions) { session in
                    HStack(spacing: 12) {
                        Image(systemName: session.state == .connected ? "network.badge.shield.half.filled" : "network")
                            .foregroundStyle(session.state == .connected ? .green : WorkbenchColors.accent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(session.name)
                                .font(.system(size: 13, weight: .semibold))
                            Text("\(session.connection):\(session.rootPath)")
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            if let error = session.lastError {
                                Text(error)
                                    .font(.system(size: 10))
                                    .foregroundStyle(.red)
                            }
                        }
                        Spacer()
                        statusBadge(session.isReadOnly ? "Read only" : "Editable", tone: session.isReadOnly ? .informational : .attention)
                        statusBadge(session.state.rawValue.capitalized, tone: session.state == .connected ? .healthy : .informational)
                        Button(session.state == .connected ? "Reconnect" : "Connect") {
                            appState.connectRemoteWorkspaceSession(session.id)
                        }
                        .buttonStyle(.borderedProminent)
                        Button(role: .destructive) {
                            appState.removeRemoteWorkspaceSession(session.id)
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(13)
                    .workbenchCard()
                }
            }
        }
    }

    private var investigationsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeading("Capture the current investigation", detail: "Preserve files, remotes, search context, branch state, and notes as a protected local record.")
            HStack(spacing: 10) {
                TextField("Investigation name", text: Binding(
                    get: { appState.engineeringWorkbenchState.investigationDraftName },
                    set: { appState.engineeringWorkbenchState.investigationDraftName = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                Button("Capture Current State") { appState.captureInvestigationSession() }
                    .buttonStyle(.borderedProminent)
            }

            if appState.engineeringWorkbenchState.investigations.isEmpty {
                emptyState("No saved investigations", detail: "Capture a troubleshooting or incident context to resume it later.", systemImage: "scope")
            } else {
                ForEach(appState.engineeringWorkbenchState.investigations) { session in
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(session.name)
                                    .font(.system(size: 14, weight: .semibold))
                                Text("\(session.openFilePaths.count + session.openRemoteSpecs.count) files • \(session.capturedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Restore") { appState.restoreInvestigationSession(session.id) }
                                .buttonStyle(.borderedProminent)
                            Button(role: .destructive) { appState.deleteInvestigationSession(session.id) } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.bordered)
                        }

                        TextEditor(text: Binding(
                            get: { investigationNotes[session.id] ?? session.notes },
                            set: { investigationNotes[session.id] = String($0.prefix(100_000)) }
                        ))
                        .font(.system(size: 11))
                        .frame(minHeight: 70)
                        .overlay(RoundedRectangle(cornerRadius: 7).stroke(WorkbenchColors.border))

                        HStack {
                            Text(session.gitBranch.map { "Captured on \($0)" } ?? "No Git branch captured")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Save Notes") {
                                appState.updateInvestigationNotes(session.id, notes: investigationNotes[session.id] ?? session.notes)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(14)
                    .workbenchCard()
                }
            }
        }
    }

    private var dataSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            sectionHeading("Operations data", detail: "Structured tools remain optional lenses; raw text is always the source of truth.")

            if let document = appState.selectedDocument {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: document.availableStructuredPresentationMode?.symbolName ?? "doc.text")
                            .foregroundStyle(WorkbenchColors.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(document.displayName)
                                .font(.system(size: 14, weight: .semibold))
                            Text(document.availableStructuredPresentationMode?.displayName ?? "Raw text document")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if document.availableStructuredPresentationMode != nil {
                            Button("Open Structured View") {
                                appState.showStructuredView()
                                dismiss()
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        Button("Raw Text") {
                            appState.showRawTextView()
                            dismiss()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(14)
                .workbenchCard()
            } else {
                emptyState("No active document", detail: "Open a CSV, JSON, log, configuration, archive, or HTTP request file.", systemImage: "tablecells")
            }

        }
    }

    private var aiChangesSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                sectionHeading("Controlled AI changes", detail: "AI output remains inert until individual hunks are approved and Git validates the patch.")
                Spacer()
                Button("Open AI Workbench") { appState.showAIWorkbenchPanel() }
                    .buttonStyle(.bordered)
                Button("Create from Latest Response") { appState.createAIChangeSetFromLatestResponse() }
                    .buttonStyle(.borderedProminent)
            }

            if appState.engineeringWorkbenchState.aiChangeSets.isEmpty {
                emptyState("No AI change sets", detail: "Ask a configured provider for a unified diff, then create a review record here.", systemImage: "wand.and.stars")
            } else {
                ForEach(appState.engineeringWorkbenchState.aiChangeSets) { changeSet in
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(changeSet.title)
                                    .font(.system(size: 14, weight: .semibold))
                                Text("\(changeSet.files.count) files • \(changeSet.approvedHunkCount) of \(changeSet.hunkCount) hunks approved")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            statusBadge(changeSet.status.rawValue.capitalized, tone: changeSet.status == .applied ? .healthy : .informational)
                            if changeSet.status == .applied {
                                Button("Revert") { appState.revertAIChangeSet(changeSet.id) }
                                    .buttonStyle(.bordered)
                            } else {
                                Button("Apply Approved") { appState.applyAIChangeSet(changeSet.id) }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(changeSet.approvedHunkCount == 0)
                            }
                            Button(role: .destructive) { appState.deleteAIChangeSet(changeSet.id) } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.bordered)
                        }

                        ForEach(changeSet.files) { file in
                            VStack(alignment: .leading, spacing: 7) {
                                Text(file.newPath)
                                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                ForEach(file.hunks) { hunk in
                                    Toggle(isOn: Binding(
                                        get: { hunk.isApproved },
                                        set: { appState.setAIChangeHunkApproval(changeSetID: changeSet.id, hunkID: hunk.id, approved: $0) }
                                    )) {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(hunk.header)
                                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                            Text(hunk.body)
                                                .font(.system(size: 9, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(5)
                                        }
                                    }
                                    .toggleStyle(.checkbox)
                                    .padding(9)
                                    .background(WorkbenchColors.canvas, in: RoundedRectangle(cornerRadius: 7))
                                }
                            }
                        }
                    }
                    .padding(14)
                    .workbenchCard()
                }
            }
        }
    }

    private var enterpriseSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                sectionHeading("Fleet readiness", detail: "Local policy, plugin provenance, release gates, and protected storage in one supportable view.")
                Spacer()
                Button("Reload Policy") { appState.reloadManagedPolicy(); appState.refreshEngineeringWorkbench() }
                    .buttonStyle(.bordered)
                Button("Export Diagnostics") { appState.exportDiagnosticBundle() }
                    .buttonStyle(.borderedProminent)
                Button("Export Audit") { appState.exportEnterpriseAuditLog() }
                    .buttonStyle(.bordered)
            }

            ForEach(appState.engineeringWorkbenchState.enterpriseChecks) { check in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: healthIcon(check.tone))
                        .foregroundStyle(healthColor(check.tone))
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(check.title)
                            .font(.system(size: 13, weight: .semibold))
                        Text(check.detail)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    statusBadge(check.tone.rawValue.capitalized, tone: check.tone)
                }
                .padding(13)
                .workbenchCard()
            }

            sectionHeading("Effective capability policy", detail: "This is the resolved local decision after managed policy, workspace trust, and Safe Mode precedence.")
            ForEach(appState.engineeringWorkbenchState.effectivePolicyDecisions) { decision in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: decision.isAllowed ? "checkmark.circle" : "lock.circle")
                        .foregroundStyle(decision.isAllowed ? .green : .orange)
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(decision.capability)
                            .font(.system(size: 12, weight: .semibold))
                        Text(decision.reason)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                        Text(decision.source)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    statusBadge(decision.isAllowed ? "Allowed" : "Blocked", tone: decision.isAllowed ? .healthy : .blocked)
                }
                .padding(11)
                .workbenchCard()
            }

            sectionHeading("Plugin execution boundary", detail: "External plugin manifests remain declarative; executable tasks stay behind trust, signature, allowlist, and bounded-process checks.")
            ForEach(appState.engineeringWorkbenchState.pluginGovernanceFindings) { finding in
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: healthIcon(finding.tone))
                        .foregroundStyle(healthColor(finding.tone))
                        .frame(width: 24)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(finding.pluginName)
                            .font(.system(size: 12, weight: .semibold))
                        Text(finding.detail)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .padding(11)
                .workbenchCard()
            }

            sectionHeading("Effective policy", detail: "Forced MDM ManagedPolicyJSON takes precedence, followed by validated local policy files.")
            VStack(alignment: .leading, spacing: 8) {
                ForEach(appState.managedPolicySummaryLines, id: \.self) { line in
                    Label(line, systemImage: "checkmark.shield")
                        .font(.system(size: 11))
                }
            }
            .padding(14)
            .workbenchCard()
        }
    }

    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                sectionHeading("Shareable profile packs", detail: "Package editor settings, approved plugin selections, privacy controls, and layout for a role or workspace.")
                Spacer()
                Button("Import Pack") { appState.importProfilePack() }
                    .buttonStyle(.bordered)
            }

            HStack(spacing: 10) {
                TextField("Profile pack name", text: Binding(
                    get: { appState.engineeringWorkbenchState.profilePackDraftName },
                    set: { appState.engineeringWorkbenchState.profilePackDraftName = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                Button("Save Current Settings") {
                    let name = appState.engineeringWorkbenchState.profilePackDraftName.trimmingCharacters(in: .whitespacesAndNewlines)
                    appState.saveCurrentWorkspaceProfile(named: name)
                    appState.engineeringWorkbenchState.profilePackDraftName = ""
                }
                .buttonStyle(.borderedProminent)
            }

            if appState.settings.profiles.isEmpty {
                emptyState("No profile packs", detail: "Create one from the current workbench, runtime, AI, and plugin settings.", systemImage: "person.crop.rectangle.stack")
            } else {
                ForEach(appState.settings.profiles) { profile in
                    HStack(spacing: 12) {
                        Image(systemName: "person.crop.rectangle.stack")
                            .foregroundStyle(WorkbenchColors.accent)
                            .frame(width: 24)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(profile.name)
                                .font(.system(size: 13, weight: .semibold))
                            Text("Updated \(profile.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Apply") { appState.applyWorkspaceProfile(profile) }
                            .buttonStyle(.borderedProminent)
                        Button("Export") { appState.exportProfilePack(profile) }
                            .buttonStyle(.bordered)
                        Button(role: .destructive) { appState.deleteWorkspaceProfile(profile) } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding(13)
                    .workbenchCard()
                }
            }
        }
    }

    private func sectionHeading(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
            Text(detail)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }

    private func summaryMetric(value: String, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundStyle(WorkbenchColors.accent)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func healthCard(_ finding: WorkspaceHealthFinding) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: finding.systemImage)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(healthColor(finding.tone))
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 4) {
                Text(finding.title)
                    .font(.system(size: 13, weight: .semibold))
                Text(finding.detail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .workbenchCard()
    }

    private func emptyState(_ title: String, detail: String, systemImage: String) -> some View {
        ContentUnavailableView(title, systemImage: systemImage, description: Text(detail))
            .frame(maxWidth: .infinity, minHeight: 180)
            .workbenchCard()
    }

    private func statusBadge(_ text: String, tone: WorkbenchHealthTone) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(healthColor(tone))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(healthColor(tone).opacity(0.10), in: Capsule())
    }

    private func healthIcon(_ tone: WorkbenchHealthTone) -> String {
        switch tone {
        case .healthy: return "checkmark.circle.fill"
        case .attention: return "exclamationmark.triangle.fill"
        case .blocked: return "xmark.octagon.fill"
        case .informational: return "info.circle.fill"
        }
    }

    private func healthColor(_ tone: WorkbenchHealthTone) -> Color {
        switch tone {
        case .healthy: return .green
        case .attention: return .orange
        case .blocked: return .red
        case .informational: return WorkbenchColors.accent
        }
    }

    private func testIcon(_ status: DiscoveredTestStatus?) -> String {
        switch status {
        case .passed: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .running: return "clock.arrow.circlepath"
        case .notRun, nil: return "circle"
        }
    }

    private func testColor(_ status: DiscoveredTestStatus?) -> Color {
        switch status {
        case .passed: return .green
        case .failed: return .red
        case .running: return .orange
        case .notRun, nil: return .secondary
        }
    }
}

private enum WorkbenchColors {
    static let accent = Color(red: 0.08, green: 0.42, blue: 0.48)
    static let canvas = Color(nsColor: .windowBackgroundColor)
    static let surface = Color(nsColor: .controlBackgroundColor)
    static let border = Color(nsColor: .separatorColor)
}

private extension View {
    func workbenchCard() -> some View {
        background(WorkbenchColors.surface, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(WorkbenchColors.border.opacity(0.8), lineWidth: 1)
            )
    }
}
