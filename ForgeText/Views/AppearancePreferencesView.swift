import SwiftUI

struct AppearancePreferencesView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            RetroBackdropView()

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header

                    preferenceSection("Appearance", systemImage: "paintbrush.pointed") {
                        Picker("Workbench style", selection: chromeStyleBinding) {
                            ForEach(AppChromeStyle.allCases) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(appState.settings.chromeStyle.summary)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(RetroPalette.link)

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

                    preferenceSection("Focus + Layout", systemImage: "viewfinder") {
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

                    preferenceSection("Advanced Runtime", systemImage: "speedometer") {
                        Picker("Runtime mode", selection: performanceModeBinding) {
                            ForEach(RuntimePerformanceMode.allCases) { mode in
                                Text(mode.displayName).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Text(appState.performanceModeSummary)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(RetroPalette.link)

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

                    preferenceSection("File Handling", systemImage: "doc.text") {
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

                    preferenceSection("AI Privacy", systemImage: "brain.head.profile") {
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

                    preferenceSection("Plugin + Remote Safety", systemImage: "shield.lefthalf.filled") {
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

                    preferenceSection("Safe Mode", systemImage: "lock.shield") {
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
                            subtitle: "Permit remote file open, search, and SSH-backed workflows while Safe Mode is active.",
                            isOn: safeModeRemoteBinding
                        )
                    }

                    preferenceSection("Onboarding Checklist", systemImage: "checklist") {
                        checklistRow("Choose a daily-driver appearance", isDone: appState.settings.chromeStyle == .studio || appState.settings.chromeStyle == .retroPro || appState.settings.chromeStyle == .minimalPro)
                        checklistRow("Pick an editor theme", isDone: true)
                        checklistRow("Open or clone a workspace", isDone: !appState.workspaceRootURLs.isEmpty)
                        checklistRow("Configure AI providers", isDone: appState.settings.aiProviders.contains(where: \.isEnabled))
                        checklistRow("Enable trusted plugins", isDone: !appState.enabledPlugins.isEmpty)
                        checklistRow("Updater feed configured", isDone: true)
                    }

                    preferenceSection("Shortcut Browser", systemImage: "keyboard") {
                        Text("Use Command Palette for most actions. A full rebinding engine can sit behind this browser later without changing the workflow.")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(RetroPalette.link)

                        Button("Open Keyboard Shortcuts") {
                            appState.showingKeyboardShortcuts = true
                        }
                        .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                    }
                }
                .padding(18)
            }
            .frame(minWidth: 620, idealWidth: 720, minHeight: 560)
            .padding(18)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            BrandMarkView(size: 34)

            VStack(alignment: .leading, spacing: 5) {
                Text("Workbench + Advanced")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(RetroPalette.ink)

                Text("Tune ForgeText for long editing sessions, heavier repositories, safer AI, and more controlled workspace behavior.")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
            }

            Spacer(minLength: 0)

            Button("Done") {
                dismiss()
            }
            .buttonStyle(RetroActionButtonStyle(tone: .secondary))
        }
        .padding(14)
        .retroPanel(fill: RetroPalette.railFill, accent: RetroPalette.chromeBlue)
    }

    private func preferenceSection<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            RetroSectionHeader(title: title, systemImage: systemImage, accent: RetroPalette.chromeBlue)
            content()
        }
        .padding(12)
        .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)
    }

    private func settingToggle(title: String, subtitle: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(RetroPalette.ink)

                Text(subtitle)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
            }
        }
        .toggleStyle(.switch)
    }

    private func checklistRow(_ title: String, isDone: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: isDone ? "checkmark.square.fill" : "square")
                .foregroundStyle(isDone ? RetroPalette.success : RetroPalette.visited)

            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
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
