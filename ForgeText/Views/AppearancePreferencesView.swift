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
                            title: "Outline in inspector",
                            subtitle: "Include document headings and symbols in the inspector drawer.",
                            isOn: outlineBinding
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
                Text("Appearance + Setup")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(RetroPalette.ink)

                Text("Tune ForgeText for long editing sessions with a calmer, more modern workbench.")
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
}
