import SwiftUI

private enum AdvancedPreferenceSection: String, CaseIterable, Identifiable {
    case experience
    case performance
    case files
    case ai
    case security
    case recovery

    var id: String { rawValue }

    var title: String {
        switch self {
        case .experience:
            return "Experience"
        case .performance:
            return "Performance"
        case .files:
            return "Files"
        case .ai:
            return "AI"
        case .security:
            return "Security"
        case .recovery:
            return "Recovery"
        }
    }

    var subtitle: String {
        switch self {
        case .experience:
            return "Workbench layout, style, density, and daily-driver presets."
        case .performance:
            return "Latency, indexing, diagnostics, and large-workspace controls."
        case .files:
            return "Open behavior, autosave, session restore, and file defaults."
        case .ai:
            return "Provider privacy, review-before-send, and local-model safeguards."
        case .security:
            return "Plugins, registries, remote access, and enterprise-aware limits."
        case .recovery:
            return "Safe Mode, support workflows, and onboarding readiness."
        }
    }

    var symbolName: String {
        switch self {
        case .experience:
            return "rectangle.3.group"
        case .performance:
            return "speedometer"
        case .files:
            return "doc.text"
        case .ai:
            return "brain.head.profile"
        case .security:
            return "shield.lefthalf.filled"
        case .recovery:
            return "cross.case"
        }
    }
}

struct AppearancePreferencesView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var selectedSection: AdvancedPreferenceSection = .experience

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(spacing: 12) {
                WorkbenchPageHeader(
                    title: "Workbench + Advanced",
                    subtitle: "Tune ForgeText for long editing sessions, heavier repositories, safer AI, and more controlled workspace behavior.",
                    badgeText: appState.managedPolicyState.isManaged ? "Managed" : nil,
                    accent: RetroPalette.chromeBlue
                ) {
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                }

                HStack(spacing: 14) {
                    settingsRail
                    settingsContent
                }
            }
            .padding(18)
        }
        .frame(minWidth: 980, idealWidth: 1060, minHeight: 700)
    }

    private var settingsRail: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sections")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(RetroPalette.mutedInk)

            ForEach(AdvancedPreferenceSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: section.symbolName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(selectedSection == section ? RetroPalette.studioAccent : RetroPalette.mutedInk)
                            .frame(width: 16, height: 18)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(section.title)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(RetroPalette.ink)

                            Text(section.subtitle)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(RetroPalette.mutedInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .retroPanel(
                        fill: selectedSection == section ? RetroPalette.studioPanel : RetroPalette.studioPanelMuted,
                        accent: selectedSection == section ? RetroPalette.studioAccent : RetroPalette.studioBorder
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            WorkbenchInfoCallout(
                title: "Managed installs",
                message: appState.managedPolicyState.isManaged
                    ? "Some local controls may be narrowed by the current managed policy. ForgeText keeps those reasons visible instead of silently ignoring your settings."
                    : "Local controls apply directly unless a managed policy file is later installed on this Mac.",
                accent: appState.managedPolicyState.isManaged ? RetroPalette.chromePink : RetroPalette.chromeBlue
            )
        }
        .frame(width: 260, alignment: .topLeading)
    }

    private var settingsContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                switch selectedSection {
                case .experience:
                    experienceContent
                case .performance:
                    performanceContent
                case .files:
                    fileHandlingContent
                case .ai:
                    aiPrivacyContent
                case .security:
                    securityContent
                case .recovery:
                    recoveryContent
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var experienceContent: some View {
        Group {
            WorkbenchSectionCard(
                title: "Appearance",
                subtitle: "Choose the daily-driver shell, density, and editor theme. Studio should stay the calmest default for enterprise use.",
                systemImage: "paintbrush.pointed",
                accent: RetroPalette.chromeBlue
            ) {
                Picker("Workbench style", selection: chromeStyleBinding) {
                    ForEach(AppChromeStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                Text(appState.settings.chromeStyle.summary)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(RetroPalette.mutedInk)

                Picker("Density", selection: densityBinding) {
                    ForEach(InterfaceDensity.allCases) { density in
                        Text(density.displayName).tag(density)
                    }
                }
                .pickerStyle(.segmented)

                Picker("Editor theme", selection: themeBinding) {
                    ForEach(EditorTheme.allCases) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
            }

            WorkbenchSectionCard(
                title: "Layout And Presets",
                subtitle: "Presets should feel like reliable workbench profiles, not throwaway view toggles.",
                systemImage: "viewfinder",
                accent: RetroPalette.chromeCyan
            ) {
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
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(RetroPalette.mutedInk)

                settingToggle(
                    title: "Focus mode",
                    subtitle: "Hide the sidebar, tab strip, header, inspector, and status bar for quiet editing.",
                    isOn: focusModeBinding
                )

                settingToggle(
                    title: "Right inspector drawer",
                    subtitle: "Show outline, current-line issues, Git blame, and document metadata in one side panel.",
                    isOn: inspectorBinding
                )

                settingToggle(
                    title: "Breadcrumbs",
                    subtitle: "Show the current section path above the editor.",
                    isOn: breadcrumbsBinding
                )

                settingToggle(
                    title: "Primary sidebar",
                    subtitle: "Keep the explorer and workbench navigation visible on the left.",
                    isOn: sidebarBinding
                )

                settingToggle(
                    title: "Bottom panel",
                    subtitle: "Dock search, terminal, problems, tests, source control, and AI in a VS Code-style panel.",
                    isOn: bottomPanelBinding
                )

                settingToggle(
                    title: "Outline in inspector",
                    subtitle: "Include document headings and symbols in the inspector drawer.",
                    isOn: outlineBinding
                )
            }
        }
    }

    private var performanceContent: some View {
        WorkbenchSectionCard(
            title: "Runtime Performance",
            subtitle: "Keep the hot editing path light. This is where large-workspace behavior, indexing, and live insight refresh should be made explicit.",
            systemImage: "speedometer",
            accent: RetroPalette.chromeTeal
        ) {
            Picker("Runtime mode", selection: performanceModeBinding) {
                ForEach(RuntimePerformanceMode.allCases) { mode in
                    Text(mode.displayName).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            Text(appState.performanceModeSummary)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(RetroPalette.mutedInk)

            settingToggle(
                title: "Auto-enter Performance Mode for heavy files",
                subtitle: "Shift into a lighter runtime automatically for large files and heavier workspaces.",
                isOn: autoPerformanceBinding
            )

            settingToggle(
                title: "Live diagnostics",
                subtitle: "Keep parser and secret-warning diagnostics fresh while editing.",
                isOn: liveDiagnosticsBinding
            )

            settingToggle(
                title: "Document insights",
                subtitle: "Keep outline, breadcrumb, JSON, CSV, and log insight summaries updated in the background.",
                isOn: documentInsightsBinding
            )

            settingToggle(
                title: "Workspace symbol indexing",
                subtitle: "Include symbols in Quick Open and command palette indexing.",
                isOn: workspaceSymbolsBinding
            )

            settingToggle(
                title: "Large repository mode",
                subtitle: "Keep Git refresh more manual and avoid expensive live repository hints in big projects.",
                isOn: largeRepositoryModeBinding
            )
        }
    }

    private var fileHandlingContent: some View {
        WorkbenchSectionCard(
            title: "File Handling",
            subtitle: "Default to predictable file-open behavior, raw-first editing, and tunable autosave/session recovery instead of hidden heuristics.",
            systemImage: "doc.text",
            accent: RetroPalette.chromeBlue
        ) {
            settingToggle(
                title: "Always start in raw view",
                subtitle: "Open structured formats in the editor first and let table, JSON, log, or HTTP views stay opt-in.",
                isOn: rawViewBinding
            )

            settingToggle(
                title: "Restore previous session on launch",
                subtitle: "Reopen the last workspace, tabs, and remote files when ForgeText starts.",
                isOn: restoreSessionBinding
            )

            settingToggle(
                title: "Autosave to disk",
                subtitle: "Write changes back to disk automatically for local and remote files when possible.",
                isOn: autosaveToDiskBinding
            )

            Picker("Default line ending for new files", selection: defaultLineEndingBinding) {
                ForEach(LineEnding.allCases, id: \.rawValue) { lineEnding in
                    Text(lineEnding.label).tag(lineEnding)
                }
            }
            .pickerStyle(.segmented)

            Stepper(
                "Autosave delay: \(autosaveDelayText)",
                value: autosaveDelayMillisecondsBinding,
                in: 250...10_000,
                step: 250
            )

            Stepper(
                "External change polling: \(externalPollingText)",
                value: externalPollingSecondsBinding,
                in: 1.0...30.0,
                step: 0.5
            )
        }
    }

    private var aiPrivacyContent: some View {
        WorkbenchSectionCard(
            title: "AI Privacy Controls",
            subtitle: "Treat AI as a governed egress path. The local defaults should make it easy to stay on-device or review exactly what leaves the editor.",
            systemImage: "brain.head.profile",
            accent: RetroPalette.chromeGold
        ) {
            if let restriction = appState.aiGlobalRestrictionReason {
                WorkbenchInfoCallout(
                    title: "AI is currently narrowed",
                    message: restriction,
                    accent: RetroPalette.warning
                )
            }

            settingToggle(
                title: "Local models only",
                subtitle: "Only allow Ollama or OpenAI-compatible local endpoints such as LM Studio.",
                isOn: localModelsOnlyBinding
            )

            settingToggle(
                title: "Review before send",
                subtitle: "Show the final prepared system and user prompt before any AI request leaves the editor.",
                isOn: requireAIReviewBinding
            )

            settingToggle(
                title: "Redact likely secrets before send",
                subtitle: "Mask tokens, private keys, bearer headers, and common secret assignments in AI context.",
                isOn: redactAIContextBinding
            )

            Stepper(
                "Max AI context size: \(maxAIContextText)",
                value: maxAIContextBinding,
                in: 1_500...120_000,
                step: 500
            )
        }
    }

    private var securityContent: some View {
        Group {
            WorkbenchSectionCard(
                title: "Plugin And Registry Safety",
                subtitle: "Keep external execution paths explicit. These local controls are especially useful when a team is not yet using a full managed policy.",
                systemImage: "puzzlepiece.extension",
                accent: RetroPalette.chromePink
            ) {
                settingToggle(
                    title: "Allow workspace plugins",
                    subtitle: "Let projects contribute local plugins from .forgetext/plugins.",
                    isOn: allowWorkspacePluginsBinding
                )

                settingToggle(
                    title: "Allow task-capable plugins",
                    subtitle: "Permit plugins and workspace automation that expose executable tasks.",
                    isOn: allowTaskPluginsBinding
                )

                settingToggle(
                    title: "Allow custom registries",
                    subtitle: "Let this Mac add and use non-default plugin registry sources.",
                    isOn: allowCustomRegistriesBinding
                )
            }

            WorkbenchSectionCard(
                title: "Remote Access Safety",
                subtitle: "Separate remote inspection from remote mutation. These defaults keep production-host workflows calmer and safer.",
                systemImage: "network",
                accent: RetroPalette.chromeTeal
            ) {
                if let restriction = appState.remoteFileAccessRestrictionReason {
                    WorkbenchInfoCallout(
                        title: "Remote access is currently narrowed",
                        message: restriction,
                        accent: RetroPalette.warning
                    )
                }

                settingToggle(
                    title: "Open remote files read-only by default",
                    subtitle: "Useful for production hosts where inspection is safer than immediate mutation.",
                    isOn: remoteReadOnlyBinding
                )

                settingToggle(
                    title: "Allow remote commands",
                    subtitle: "Permit running shell commands on connected remote hosts.",
                    isOn: allowRemoteCommandsBinding
                )

                settingToggle(
                    title: "Allow remote agent install",
                    subtitle: "Permit deploying the ForgeText helper agent to remote hosts.",
                    isOn: allowRemoteAgentInstallBinding
                )
            }
        }
    }

    private var recoveryContent: some View {
        Group {
            WorkbenchSectionCard(
                title: "Safe Mode",
                subtitle: "Safe Mode is the recovery posture: smaller trust surface, fewer moving parts, and a better support/debugging starting point.",
                systemImage: "lock.shield",
                accent: RetroPalette.chromeGold
            ) {
                settingToggle(
                    title: "Safe Mode",
                    subtitle: "Start and run ForgeText with a much smaller trust surface for support and recovery work.",
                    isOn: safeModeEnabledBinding
                )

                settingToggle(
                    title: "Restore previous session in Safe Mode",
                    subtitle: "Let Safe Mode reopen the last workspace and tabs instead of starting clean.",
                    isOn: safeModeRestoreSessionBinding
                )

                settingToggle(
                    title: "Allow external plugins in Safe Mode",
                    subtitle: "Keep workspace or user-installed plugins available even while Safe Mode is active.",
                    isOn: safeModeExternalPluginsBinding
                )

                settingToggle(
                    title: "Allow AI in Safe Mode",
                    subtitle: "Permit AI workbench and prompt sends even while the app is in Safe Mode.",
                    isOn: safeModeAIBinding
                )

                settingToggle(
                    title: "Allow remote connections in Safe Mode",
                    subtitle: "Permit remote file open, search, and SSH-backed workflows while the app is in Safe Mode.",
                    isOn: safeModeRemoteBinding
                )
            }

            WorkbenchSectionCard(
                title: "Readiness And Support",
                subtitle: "This keeps first-run expectations and support-oriented shortcuts in one predictable place instead of hiding them behind separate one-off panels.",
                systemImage: "checklist",
                accent: RetroPalette.chromeBlue
            ) {
                checklistRow("Choose a daily-driver appearance", isDone: appState.settings.chromeStyle == .studio || appState.settings.chromeStyle == .retroPro || appState.settings.chromeStyle == .minimalPro)
                checklistRow("Pick an editor theme", isDone: true)
                checklistRow("Open or clone a workspace", isDone: !appState.workspaceRootURLs.isEmpty)
                checklistRow("Configure AI providers", isDone: appState.settings.aiProviders.contains(where: \.isEnabled))
                checklistRow("Enable trusted plugins", isDone: !appState.enabledPlugins.isEmpty)
                checklistRow("Updater feed configured", isDone: true)

                RetroRule()

                Text("Use Command Palette for most actions. A full rebinding engine can sit behind this browser later without changing the workflow.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(RetroPalette.mutedInk)

                Button("Open Keyboard Shortcuts") {
                    appState.showingKeyboardShortcuts = true
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))
            }
        }
    }

    private func settingToggle(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RetroPalette.ink)

                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(RetroPalette.mutedInk)
            }
        }
        .toggleStyle(.switch)
    }

    private func checklistRow(_ title: String, isDone: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isDone ? "checkmark.square.fill" : "square")
                .foregroundStyle(isDone ? RetroPalette.success : RetroPalette.visited)

            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(RetroPalette.ink)

            Spacer(minLength: 0)
        }
    }

    private var chromeStyleBinding: Binding<AppChromeStyle> {
        Binding(
            get: { appState.settings.chromeStyle },
            set: { appState.setChromeStyle($0) }
        )
    }

    private var densityBinding: Binding<InterfaceDensity> {
        Binding(
            get: { appState.settings.interfaceDensity },
            set: { appState.setInterfaceDensity($0) }
        )
    }

    private var themeBinding: Binding<EditorTheme> {
        Binding(
            get: { appState.settings.theme },
            set: { appState.setTheme($0) }
        )
    }

    private var focusModeBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.focusModeEnabled },
            set: { newValue in
                if appState.settings.focusModeEnabled != newValue {
                    appState.toggleFocusMode()
                }
            }
        )
    }

    private var inspectorBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.showsInspector },
            set: { newValue in
                if appState.settings.showsInspector != newValue {
                    appState.toggleInspectorPanel()
                }
            }
        )
    }

    private var breadcrumbsBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.showsBreadcrumbs },
            set: { newValue in
                if appState.settings.showsBreadcrumbs != newValue {
                    appState.toggleBreadcrumbs()
                }
            }
        )
    }

    private var outlineBinding: Binding<Bool> {
        Binding(
            get: { appState.settings.showsOutline },
            set: { newValue in
                if appState.settings.showsOutline != newValue {
                    appState.toggleOutlinePanel()
                }
            }
        )
    }

    private var sidebarBinding: Binding<Bool> {
        Binding(
            get: { appState.isSidebarVisible },
            set: { newValue in
                if appState.isSidebarVisible != newValue {
                    appState.toggleSidebar()
                }
            }
        )
    }

    private var bottomPanelBinding: Binding<Bool> {
        Binding(
            get: { appState.isBottomPanelVisible },
            set: { newValue in
                if appState.isBottomPanelVisible != newValue {
                    appState.toggleBottomPanel()
                }
            }
        )
    }

    private var performanceModeBinding: Binding<RuntimePerformanceMode> {
        advancedBinding(
            get: { appState.settings.advanced.performance.mode },
            set: { appState.settings.advanced.performance.mode = $0 },
            message: { "Runtime mode set to \($0.displayName)." }
        )
    }

    private var autoPerformanceBinding: Binding<Bool> {
        advancedBinding(
            get: { appState.settings.advanced.performance.autoEnableForLargeFiles },
            set: { appState.settings.advanced.performance.autoEnableForLargeFiles = $0 },
            message: { $0 ? "ForgeText will auto-enter Performance Mode for heavier files." : "Automatic Performance Mode is off." }
        )
    }

    private var liveDiagnosticsBinding: Binding<Bool> {
        advancedBinding(
            get: { appState.settings.advanced.performance.liveDiagnosticsEnabled },
            set: { appState.settings.advanced.performance.liveDiagnosticsEnabled = $0 },
            message: { $0 ? "Live diagnostics are enabled." : "Live diagnostics are paused." }
        )
    }

    private var documentInsightsBinding: Binding<Bool> {
        advancedBinding(
            get: { appState.settings.advanced.performance.documentInsightsEnabled },
            set: { appState.settings.advanced.performance.documentInsightsEnabled = $0 },
            message: { $0 ? "Document insights will refresh in the background." : "Document insight refresh is paused." }
        )
    }

    private var workspaceSymbolsBinding: Binding<Bool> {
        advancedBinding(
            get: { appState.settings.advanced.performance.indexWorkspaceSymbols },
            set: { appState.settings.advanced.performance.indexWorkspaceSymbols = $0 },
            message: { $0 ? "Workspace symbol indexing is enabled." : "Workspace symbol indexing is paused." }
        )
    }

    private var largeRepositoryModeBinding: Binding<Bool> {
        advancedBinding(
            get: { appState.settings.advanced.git.largeRepositoryMode },
            set: { appState.settings.advanced.git.largeRepositoryMode = $0 },
            message: { $0 ? "Large repository mode is on." : "Large repository mode is off." }
        )
    }

    private var rawViewBinding: Binding<Bool> {
        advancedBinding(
            get: { appState.settings.advanced.fileHandling.alwaysOpenInRawView },
            set: { appState.settings.advanced.fileHandling.alwaysOpenInRawView = $0 },
            message: { $0 ? "Structured files will open in raw view first." : "Structured formats can open in their richer views." }
        )
    }

    private var restoreSessionBinding: Binding<Bool> {
        advancedBinding(
            get: { appState.settings.advanced.fileHandling.restorePreviousSessionOnLaunch },
            set: { appState.settings.advanced.fileHandling.restorePreviousSessionOnLaunch = $0 },
            message: { $0 ? "ForgeText will restore the previous session on launch." : "ForgeText will start with a fresh session on launch." }
        )
    }

    private var autosaveToDiskBinding: Binding<Bool> {
        simpleSettingsBinding(
            get: { appState.settings.autosaveToDisk },
            set: { appState.settings.autosaveToDisk = $0 }
        )
    }

    private var defaultLineEndingBinding: Binding<LineEnding> {
        advancedBinding(
            get: { appState.settings.advanced.fileHandling.defaultLineEnding },
            set: { appState.settings.advanced.fileHandling.defaultLineEnding = $0 },
            message: { "New files will default to \($0.label) line endings." }
        )
    }

    private var autosaveDelayMillisecondsBinding: Binding<Int> {
        advancedBinding(
            get: { appState.settings.advanced.fileHandling.autosaveDelayMilliseconds },
            set: { appState.settings.advanced.fileHandling.autosaveDelayMilliseconds = $0 },
            message: { "Autosave delay set to \($0) ms." }
        )
    }

    private var externalPollingSecondsBinding: Binding<Double> {
        advancedBinding(
            get: { appState.settings.advanced.fileHandling.externalChangePollingIntervalSeconds },
            set: { appState.settings.advanced.fileHandling.externalChangePollingIntervalSeconds = $0 },
            message: { "External change polling set to \(String(format: "%.1f", $0)) seconds." }
        )
    }

    private var localModelsOnlyBinding: Binding<Bool> {
        advancedBinding(
            get: { appState.settings.advanced.ai.localModelsOnly },
            set: { appState.settings.advanced.ai.localModelsOnly = $0 },
            message: { $0 ? "AI is limited to local model endpoints only." : "Cloud AI providers are allowed." }
        )
    }

    private var requireAIReviewBinding: Binding<Bool> {
        advancedBinding(
            get: { appState.settings.advanced.ai.requireReviewBeforeSend },
            set: { appState.settings.advanced.ai.requireReviewBeforeSend = $0 },
            message: { $0 ? "AI requests now require a final review before send." : "AI review before send is off." }
        )
    }

    private var redactAIContextBinding: Binding<Bool> {
        advancedBinding(
            get: { appState.settings.advanced.ai.redactSensitiveContext },
            set: { appState.settings.advanced.ai.redactSensitiveContext = $0 },
            message: { $0 ? "ForgeText will redact likely secrets from AI context." : "Secret redaction before AI send is off." }
        )
    }

    private var maxAIContextBinding: Binding<Int> {
        advancedBinding(
            get: { appState.settings.advanced.ai.maxContextCharacters },
            set: { appState.settings.advanced.ai.maxContextCharacters = $0 },
            message: { "AI context budget set to \($0.formatted()) characters." }
        )
    }

    private var allowWorkspacePluginsBinding: Binding<Bool> {
        advancedBinding(
            get: { appState.settings.advanced.plugins.allowWorkspacePlugins },
            set: { appState.settings.advanced.plugins.allowWorkspacePlugins = $0 },
            message: { $0 ? "Workspace plugins are allowed." : "Workspace plugins are blocked." }
        )
    }

    private var allowTaskPluginsBinding: Binding<Bool> {
        advancedBinding(
            get: { appState.settings.advanced.plugins.allowTaskCapablePlugins },
            set: { appState.settings.advanced.plugins.allowTaskCapablePlugins = $0 },
            message: { $0 ? "Task-capable plugins are allowed." : "Task-capable plugins are blocked." }
        )
    }

    private var allowCustomRegistriesBinding: Binding<Bool> {
        advancedBinding(
            get: { appState.settings.advanced.plugins.allowCustomRegistries },
            set: { appState.settings.advanced.plugins.allowCustomRegistries = $0 },
            message: { $0 ? "Custom plugin registries are allowed." : "Custom plugin registries are blocked." }
        )
    }

    private var remoteReadOnlyBinding: Binding<Bool> {
        advancedBinding(
            get: { appState.settings.advanced.remote.openFilesReadOnly },
            set: { appState.settings.advanced.remote.openFilesReadOnly = $0 },
            message: { $0 ? "Remote files will open read-only by default." : "Remote files can open editable by default." }
        )
    }

    private var allowRemoteCommandsBinding: Binding<Bool> {
        advancedBinding(
            get: { appState.settings.advanced.remote.allowRemoteCommands },
            set: { appState.settings.advanced.remote.allowRemoteCommands = $0 },
            message: { $0 ? "Remote commands are allowed." : "Remote commands are blocked." }
        )
    }

    private var allowRemoteAgentInstallBinding: Binding<Bool> {
        advancedBinding(
            get: { appState.settings.advanced.remote.allowRemoteAgentInstall },
            set: { appState.settings.advanced.remote.allowRemoteAgentInstall = $0 },
            message: { $0 ? "Remote agent installation is allowed." : "Remote agent installation is blocked." }
        )
    }

    private var safeModeEnabledBinding: Binding<Bool> {
        advancedBinding(
            get: { appState.settings.advanced.safeMode.isEnabled },
            set: { appState.settings.advanced.safeMode.isEnabled = $0 },
            message: { $0 ? "Safe Mode is enabled." : "Safe Mode is disabled." }
        )
    }

    private var safeModeRestoreSessionBinding: Binding<Bool> {
        advancedBinding(
            get: { appState.settings.advanced.safeMode.restoresPreviousSession },
            set: { appState.settings.advanced.safeMode.restoresPreviousSession = $0 },
            message: { $0 ? "Safe Mode will restore the previous session." : "Safe Mode will start with a clean session." }
        )
    }

    private var safeModeExternalPluginsBinding: Binding<Bool> {
        advancedBinding(
            get: { appState.settings.advanced.safeMode.allowsExternalPlugins },
            set: { appState.settings.advanced.safeMode.allowsExternalPlugins = $0 },
            message: { $0 ? "Safe Mode can keep external plugins enabled." : "Safe Mode will block external plugins." }
        )
    }

    private var safeModeAIBinding: Binding<Bool> {
        advancedBinding(
            get: { appState.settings.advanced.safeMode.allowsAI },
            set: { appState.settings.advanced.safeMode.allowsAI = $0 },
            message: { $0 ? "Safe Mode allows AI actions." : "Safe Mode blocks AI actions." }
        )
    }

    private var safeModeRemoteBinding: Binding<Bool> {
        advancedBinding(
            get: { appState.settings.advanced.safeMode.allowsRemoteConnections },
            set: { appState.settings.advanced.safeMode.allowsRemoteConnections = $0 },
            message: { $0 ? "Safe Mode allows remote connections." : "Safe Mode blocks remote connections." }
        )
    }

    private var autosaveDelayText: String {
        "\(appState.settings.advanced.fileHandling.autosaveDelayMilliseconds) ms"
    }

    private var externalPollingText: String {
        "\(String(format: "%.1f", appState.settings.advanced.fileHandling.externalChangePollingIntervalSeconds)) s"
    }

    private var maxAIContextText: String {
        "\(appState.settings.advanced.ai.maxContextCharacters.formatted()) chars"
    }

    private func simpleSettingsBinding<Value>(
        get: @escaping () -> Value,
        set: @escaping (Value) -> Void
    ) -> Binding<Value> {
        Binding(
            get: { get() },
            set: { newValue in
                set(newValue)
                AppSettingsStore.save(appState.settings)
            }
        )
    }

    private func advancedBinding<Value>(
        get: @escaping () -> Value,
        set: @escaping (Value) -> Void,
        message: @escaping (Value) -> String
    ) -> Binding<Value> {
        Binding(
            get: { get() },
            set: { newValue in
                set(newValue)
                appState.applyAdvancedSettingsChanges(message: message(newValue))
            }
        )
    }
}
