import SwiftUI

private enum WorkspaceCenterSection: String, CaseIterable, Identifiable {
    case overview
    case trustAndPolicy
    case profilesAndSync
    case catalogs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .overview:
            return "Overview"
        case .trustAndPolicy:
            return "Trust + Policy"
        case .profilesAndSync:
            return "Profiles + Sync"
        case .catalogs:
            return "Catalogs"
        }
    }
}

struct WorkspacePlatformView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: WorkspaceCenterSection = .overview

    private let operationColumns = [
        GridItem(.flexible(minimum: 220), spacing: 10),
        GridItem(.flexible(minimum: 220), spacing: 10)
    ]

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(spacing: 12) {
                WorkbenchPageHeader(
                    title: "Workspace Center",
                    subtitle: "Manage roots, trust, sessions, registries, and managed controls from one operator surface.",
                    badgeText: appState.managedPolicyState.isManaged ? "Managed" : nil,
                    accent: RetroPalette.chromePink
                ) {
                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                }

                Picker("Workspace Center Section", selection: $selectedSection) {
                    ForEach(WorkspaceCenterSection.allCases) { section in
                        Text(section.title).tag(section)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 2)

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        selectedSectionContent
                    }
                    .padding(.vertical, 2)
                }
            }
            .padding(18)
        }
        .frame(minWidth: 980, minHeight: 720)
    }

    @ViewBuilder
    private var selectedSectionContent: some View {
        switch selectedSection {
        case .overview:
            overviewContent
        case .trustAndPolicy:
            trustAndPolicyContent
        case .profilesAndSync:
            profilesAndSyncContent
        case .catalogs:
            catalogsContent
        }
    }

    private var overviewContent: some View {
        Group {
            WorkbenchSectionCard(
                title: "Workspace Roots",
                subtitle: "Keep the active project, workspace file, and save/open flow together so the current editing context is obvious.",
                systemImage: "folder.badge.gearshape",
                accent: RetroPalette.chromeCyan
            ) {
                if let workspaceFilePath = appState.workspacePlatformState.workspaceFilePath {
                    WorkbenchInfoCallout(
                        title: "Attached workspace file",
                        message: workspaceFilePath,
                        accent: RetroPalette.chromeCyan
                    )
                } else {
                    WorkbenchInfoCallout(
                        title: "No workspace file yet",
                        message: "You can work with multiple roots immediately and save the setup into a .forgetext-workspace file later.",
                        accent: RetroPalette.chromeGold
                    )
                }

                if appState.workspaceRootURLs.isEmpty {
                    emptyStateCard("No workspace roots are active yet.")
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(appState.workspaceRootURLs, id: \.path) { rootURL in
                            workspaceRootRow(rootURL)
                        }
                    }
                }

                HStack(spacing: 10) {
                    Button("Choose Root") {
                        appState.chooseWorkspaceRoot()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                    Button("Add Root") {
                        appState.addWorkspaceRoot()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                    Button("Open Workspace File") {
                        appState.openWorkspaceFilePanel()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                    Button("Save Workspace File") {
                        appState.saveWorkspaceFile()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .primary))
                    .disabled(appState.workspaceRootURLs.isEmpty)
                }

                if let statusMessage = appState.workspacePlatformState.lastStatusMessage {
                    Text(statusMessage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(RetroPalette.mutedInk)
                }
            }

            WorkbenchSectionCard(
                title: "Access And Workflow Status",
                subtitle: "See what the current workspace allows before you jump into AI, remote work, tasks, or terminal commands.",
                systemImage: "checklist.checked",
                accent: RetroPalette.chromeGold
            ) {
                VStack(alignment: .leading, spacing: 10) {
                    accessStatusRow(
                        title: "Workspace trust",
                        status: appState.workspaceTrustMode.displayName,
                        detail: appState.workspaceTrustMode.summary,
                        accent: appState.workspaceTrustMode == .trusted ? RetroPalette.success : RetroPalette.warning
                    )
                    accessStatusRow(
                        title: "AI workbench",
                        status: appState.aiGlobalRestrictionReason == nil ? "Available" : "Restricted",
                        detail: appState.aiGlobalRestrictionReason ?? "Configured providers can be used from the current trusted workspace.",
                        accent: appState.aiGlobalRestrictionReason == nil ? RetroPalette.success : RetroPalette.warning
                    )
                    accessStatusRow(
                        title: "Remote file access",
                        status: appState.remoteFileAccessRestrictionReason == nil ? "Available" : "Restricted",
                        detail: appState.remoteFileAccessRestrictionReason ?? "Remote file open/search flows are available from this installation.",
                        accent: appState.remoteFileAccessRestrictionReason == nil ? RetroPalette.success : RetroPalette.warning
                    )
                    accessStatusRow(
                        title: "Embedded terminal",
                        status: appState.terminalRestrictionReason == nil ? "Available" : "Restricted",
                        detail: appState.terminalRestrictionReason ?? "Terminal commands can run inside the current workspace.",
                        accent: appState.terminalRestrictionReason == nil ? RetroPalette.success : RetroPalette.warning
                    )
                    accessStatusRow(
                        title: "Workspace tasks",
                        status: appState.taskExecutionRestrictionReason == nil ? "Available" : "Restricted",
                        detail: appState.taskExecutionRestrictionReason ?? "Detected build, test, and lint commands are available from Task Runner.",
                        accent: appState.taskExecutionRestrictionReason == nil ? RetroPalette.success : RetroPalette.warning
                    )
                }
            }

            WorkbenchSectionCard(
                title: "Workspace Actions",
                subtitle: "Common setup and operating flows are grouped here so the workspace pane acts like a control surface, not a miscellaneous dashboard.",
                systemImage: "bolt.horizontal.circle",
                accent: RetroPalette.chromeBlue
            ) {
                LazyVGrid(columns: operationColumns, alignment: .leading, spacing: 10) {
                    actionTile(
                        title: "Workspace Sessions",
                        subtitle: "Save and reopen groups of files, remotes, and workbench state.",
                        symbolName: "square.stack.3d.up",
                        accent: RetroPalette.chromeCyan,
                        action: appState.showWorkspaceSessionsPanel
                    )
                    actionTile(
                        title: "Clone Repository",
                        subtitle: "Create a new local workspace from a Git repository.",
                        symbolName: "square.and.arrow.down.on.square",
                        accent: RetroPalette.chromeTeal,
                        action: appState.showCloneRepositoryPanel
                    )
                    actionTile(
                        title: "Open Remote File",
                        subtitle: "Connect to an SSH-style remote path and inspect or edit a single file.",
                        symbolName: "network",
                        accent: RetroPalette.chromePink,
                        action: appState.openRemotePanel,
                        restriction: appState.remoteFileAccessRestrictionReason
                    )
                    actionTile(
                        title: "AI Workbench",
                        subtitle: "Use local or cloud models with workspace-aware prompts and review controls.",
                        symbolName: "sparkles.rectangle.stack",
                        accent: RetroPalette.chromeGold,
                        action: appState.showAIWorkbenchPanel,
                        restriction: appState.aiGlobalRestrictionReason
                    )
                    actionTile(
                        title: "Task Runner",
                        subtitle: "Run detected build, test, and lint flows from the current workspace.",
                        symbolName: "play.square.stack",
                        accent: RetroPalette.chromeBlue,
                        action: appState.showTaskRunnerPanel,
                        restriction: appState.taskExecutionRestrictionReason
                    )
                    actionTile(
                        title: "Embedded Terminal",
                        subtitle: "Open a docked terminal for direct command execution.",
                        symbolName: "terminal",
                        accent: RetroPalette.chromeTeal,
                        action: appState.showTerminalConsolePanel,
                        restriction: appState.terminalRestrictionReason
                    )
                }
            }
        }
    }

    private var trustAndPolicyContent: some View {
        Group {
            WorkbenchSectionCard(
                title: "Workspace Trust",
                subtitle: "Restricted mode is where ForgeText becomes safer by default. Trust only the folders that should be allowed to run stronger workflows.",
                systemImage: "shield.lefthalf.filled",
                accent: RetroPalette.chromeGold
            ) {
                HStack(spacing: 8) {
                    RetroCapsuleLabel(
                        text: appState.workspaceTrustMode.displayName,
                        accent: appState.workspaceTrustMode == .trusted ? RetroPalette.success : RetroPalette.warning
                    )

                    Text(appState.workspaceTrustMode.summary)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(RetroPalette.mutedInk)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: 10) {
                    Button("Trust Workspace") {
                        appState.trustCurrentWorkspace()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .primary))
                    .disabled(appState.workspaceRootURLs.isEmpty || appState.workspaceTrustMode == .trusted)

                    Button("Restrict Workspace") {
                        appState.restrictCurrentWorkspace()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                    .disabled(appState.workspaceRootURLs.isEmpty || appState.workspaceTrustMode == .restricted)
                }

                WorkbenchInfoCallout(
                    title: "What restricted mode changes",
                    message: "ForgeText can still open and edit files, but it becomes much stricter about AI sends, remote operations, external plugins, and executable workspace tasks.",
                    accent: RetroPalette.chromeGold
                )
            }

            WorkbenchSectionCard(
                title: "Managed Policy",
                subtitle: "Enterprise policy should be visible and explain why an action is blocked. This view keeps the current source, load health, and active rules together.",
                systemImage: "building.2",
                accent: RetroPalette.chromePink
            ) {
                HStack(spacing: 10) {
                    RetroCapsuleLabel(
                        text: appState.managedPolicyState.isManaged ? "Managed" : "Unmanaged",
                        accent: appState.managedPolicyState.isManaged ? RetroPalette.chromePink : RetroPalette.chromeBlue
                    )

                    Text(appState.managedPolicyState.sourcePath ?? appState.managedPolicySuggestedPath)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(RetroPalette.mutedInk)
                        .textSelection(.enabled)
                }

                if let loadError = appState.managedPolicyState.loadError {
                    WorkbenchInfoCallout(
                        title: "Policy load issue",
                        message: loadError,
                        accent: RetroPalette.danger
                    )
                }

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(appState.managedPolicySummaryLines.enumerated()), id: \.offset) { item in
                        Text("• \(item.element)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(RetroPalette.mutedInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Button("Reload Policy") {
                    appState.reloadManagedPolicy()
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))
            }
        }
    }

    private var profilesAndSyncContent: some View {
        Group {
            WorkbenchSectionCard(
                title: "Workspace Profiles",
                subtitle: "Save repeatable layout, plugin, and advanced-control setups for different roles such as infra, review, writing, or incident response.",
                systemImage: "person.crop.rectangle.stack",
                accent: RetroPalette.chromeTeal
            ) {
                TextField(
                    "Ops, Writing, Infra, Minimal...",
                    text: Binding(
                        get: { appState.workspacePlatformState.profileDraftName },
                        set: { appState.workspacePlatformState.profileDraftName = $0 }
                    )
                )
                .textFieldStyle(.plain)
                .retroTextField()

                HStack(spacing: 10) {
                    Button("Save Current Profile") {
                        appState.saveCurrentWorkspaceProfile(named: appState.workspacePlatformState.profileDraftName)
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .primary))

                    if let selectedProfileID = appState.workspacePlatformState.selectedProfileID,
                       let selectedProfile = appState.availableWorkspaceProfiles.first(where: { $0.id == selectedProfileID }) {
                        RetroCapsuleLabel(text: "Selected: \(selectedProfile.name)", accent: RetroPalette.chromeCyan)
                    }
                }

                if appState.availableWorkspaceProfiles.isEmpty {
                    emptyStateCard("No saved profiles yet.")
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(appState.availableWorkspaceProfiles) { profile in
                            HStack(alignment: .top, spacing: 10) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(profile.name)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(RetroPalette.ink)

                                    Text("Theme \(profile.snapshot.theme.displayName) • Font \(Int(profile.snapshot.fontSize)) • Plugins \(profile.snapshot.enabledPluginIDs.count)")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(RetroPalette.mutedInk)
                                }

                                Spacer(minLength: 0)

                                Button("Apply") {
                                    appState.applyWorkspaceProfile(profile)
                                }
                                .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                                Button("Delete") {
                                    appState.deleteWorkspaceProfile(profile)
                                }
                                .buttonStyle(RetroActionButtonStyle(tone: .danger))
                            }
                            .padding(12)
                            .retroInsetPanel(fill: RetroPalette.studioField, accent: RetroPalette.chromeTeal)
                        }
                    }
                }
            }

            WorkbenchSectionCard(
                title: "Sync And Runtime Storage",
                subtitle: "Keep migration and support flows explicit. ForgeText separates safe preference transfer from local-only trust and sensitive runtime state.",
                systemImage: "arrow.triangle.2.circlepath.circle",
                accent: RetroPalette.chromePink
            ) {
                accessStatusRow(
                    title: "Runtime storage",
                    status: appState.isPortableModeEnabled ? "Portable Mode" : "Application Support",
                    detail: appState.isPortableModeEnabled
                        ? "State is being stored in the portable ForgeText data directory."
                        : "State is stored in Application Support with protected local persistence for sensitive editor state.",
                    accent: appState.isPortableModeEnabled ? RetroPalette.chromeCyan : RetroPalette.chromeBlue
                )

                HStack(spacing: 10) {
                    Button("Export Sync Bundle") {
                        appState.exportSyncBundle()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                    Button("Import Sync Bundle") {
                        appState.importSyncBundle()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                }

                if let refreshedAt = appState.workspacePlatformState.lastRegistryRefreshAt {
                    Text("Registry refreshed \(refreshedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(RetroPalette.mutedInk)
                }
            }
        }
    }

    private var catalogsContent: some View {
        WorkbenchSectionCard(
            title: "Plugin Catalogs",
            subtitle: "Keep registry sources and their policy state together so extension sourcing feels explicit and enterprise-friendly.",
            systemImage: "puzzlepiece.extension",
            accent: RetroPalette.chromeBlue
        ) {
            TextField(
                "Registry name",
                text: Binding(
                    get: { appState.workspacePlatformState.registryDraftName },
                    set: { appState.workspacePlatformState.registryDraftName = $0 }
                )
            )
            .textFieldStyle(.plain)
            .retroTextField()

            TextField(
                "https://example.com/registry.json or /path/to/registry.json",
                text: Binding(
                    get: { appState.workspacePlatformState.registryDraftSource },
                    set: { appState.workspacePlatformState.registryDraftSource = $0 }
                )
            )
            .textFieldStyle(.plain)
            .retroTextField()

            HStack(spacing: 10) {
                Button("Add Registry") {
                    appState.addPluginRegistry(
                        named: appState.workspacePlatformState.registryDraftName,
                        source: appState.workspacePlatformState.registryDraftSource
                    )
                }
                .buttonStyle(RetroActionButtonStyle(tone: .primary))
                .disabled(!appState.canAddManagedPluginRegistry)

                Button("Refresh Catalog") {
                    appState.refreshPluginRegistry()
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))
            }

            if appState.settings.pluginRegistries.isEmpty {
                emptyStateCard("No custom registries configured.")
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(appState.settings.pluginRegistries) { registry in
                        HStack(alignment: .top, spacing: 10) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(registry.name)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(RetroPalette.ink)

                                    RetroCapsuleLabel(
                                        text: registry.isEnabled ? "Enabled" : "Disabled",
                                        accent: registry.isEnabled ? RetroPalette.success : RetroPalette.warning
                                    )
                                }

                                Text(registry.source)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(RetroPalette.mutedInk)
                                    .textSelection(.enabled)

                                if let restrictionReason = EnterprisePolicyService.registrySourceRestrictionReason(registry.source, policy: appState.activeManagedPolicy) {
                                    Text(restrictionReason)
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(RetroPalette.warning)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }

                            Spacer(minLength: 0)

                            VStack(spacing: 6) {
                                Toggle(
                                    "",
                                    isOn: Binding(
                                        get: { registry.isEnabled },
                                        set: { appState.setPluginRegistryEnabled(registry, isEnabled: $0) }
                                    )
                                )
                                .labelsHidden()
                                .toggleStyle(.switch)

                                Button("Remove") {
                                    appState.removePluginRegistry(registry)
                                }
                                .buttonStyle(RetroActionButtonStyle(tone: .danger))
                            }
                        }
                        .padding(12)
                        .retroInsetPanel(fill: RetroPalette.studioField, accent: RetroPalette.chromeBlue)
                    }
                }
            }
        }
    }

    private func workspaceRootRow(_ rootURL: URL) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(rootURL.lastPathComponent)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(RetroPalette.ink)

                    if appState.activeWorkspaceURL?.path == rootURL.path {
                        RetroCapsuleLabel(text: "Active", accent: RetroPalette.chromeGold)
                    }
                }

                Text(rootURL.path(percentEncoded: false))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(RetroPalette.mutedInk)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Button("Use") {
                    appState.setActiveWorkspaceRoot(path: rootURL.path)
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                Button("Remove") {
                    appState.removeWorkspaceRoot(path: rootURL.path)
                }
                .buttonStyle(RetroActionButtonStyle(tone: .danger))
            }
        }
        .padding(12)
        .retroInsetPanel(fill: RetroPalette.studioField, accent: RetroPalette.chromeBlue)
    }

    private func accessStatusRow(title: String, status: String, detail: String, accent: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RetroPalette.ink)

                Text(detail)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(RetroPalette.mutedInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)

            RetroCapsuleLabel(text: status, accent: accent)
        }
        .padding(12)
        .retroInsetPanel(fill: RetroPalette.studioField, accent: accent)
    }

    private func actionTile(
        title: String,
        subtitle: String,
        symbolName: String,
        accent: Color,
        action: @escaping () -> Void,
        restriction: String? = nil
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: symbolName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accent)

                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(RetroPalette.ink)
                }

                Text(restriction ?? subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(restriction == nil ? RetroPalette.mutedInk : RetroPalette.warning)
                    .fixedSize(horizontal: false, vertical: true)

                if restriction != nil {
                    RetroCapsuleLabel(text: "Restricted", accent: RetroPalette.warning)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .retroInsetPanel(fill: RetroPalette.studioField, accent: accent)
        }
        .buttonStyle(.plain)
        .disabled(restriction != nil)
    }

    private func emptyStateCard(_ message: String) -> some View {
        Text(message)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(RetroPalette.mutedInk)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .retroInsetPanel(fill: RetroPalette.studioField, accent: RetroPalette.studioDivider)
    }
}
