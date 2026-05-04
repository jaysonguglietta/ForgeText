import SwiftUI

struct WorkspacePlatformView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Label("Workspace Center", systemImage: "square.3.layers.3d")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)

                    Spacer(minLength: 0)

                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .primary))
                }
                .padding(16)
                .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)

                RetroRule()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        workspaceSection
                        trustSection
                        profilesSection
                        registriesSection
                        syncSection
                    }
                    .padding(16)
                }
            }
            .padding(14)
        }
        .frame(minWidth: 980, minHeight: 720)
    }

    private var workspaceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Workspace Roots", accent: RetroPalette.chromeCyan)

            if let workspaceFilePath = appState.workspacePlatformState.workspaceFilePath {
                Text("Workspace file: \(workspaceFilePath)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
                    .textSelection(.enabled)
            } else {
                Text("No `.forgetext-workspace` file is attached yet. You can still use multiple roots and save the setup later.")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
            }

            if appState.workspaceRootURLs.isEmpty {
                Text("No workspace roots are active.")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
            } else {
                ForEach(appState.workspaceRootURLs, id: \.path) { rootURL in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(rootURL.lastPathComponent)
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .foregroundStyle(RetroPalette.ink)

                                if appState.activeWorkspaceURL?.path == rootURL.path {
                                    RetroCapsuleLabel(text: "ACTIVE", accent: RetroPalette.chromeGold)
                                }
                            }

                            Text(rootURL.path(percentEncoded: false))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(RetroPalette.link)
                                .textSelection(.enabled)
                        }

                        Spacer(minLength: 0)

                        VStack(spacing: 6) {
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
                    .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeBlue)
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
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.visited)
            }
        }
        .padding(14)
        .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeCyan)
    }

    private var trustSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Workspace Trust", accent: RetroPalette.chromeGold)

            HStack(spacing: 8) {
                RetroCapsuleLabel(text: appState.workspaceTrustMode.displayName.uppercased(), accent: appState.workspaceTrustMode == .trusted ? RetroPalette.success : RetroPalette.warning)
                Text(appState.workspaceTrustMode.summary)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
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
        }
        .padding(14)
        .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeGold)
    }

    private var profilesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Profiles", accent: RetroPalette.chromeTeal)

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
                Text("No saved profiles yet.")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
            } else {
                ForEach(appState.availableWorkspaceProfiles) { profile in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(profile.name)
                                .font(.system(size: 12, weight: .black, design: .monospaced))
                                .foregroundStyle(RetroPalette.ink)

                            Text("Theme \(profile.snapshot.theme.displayName) • Font \(Int(profile.snapshot.fontSize)) • Plugins \(profile.snapshot.enabledPluginIDs.count)")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(RetroPalette.link)
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
                    .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeTeal)
                }
            }
        }
        .padding(14)
        .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeTeal)
    }

    private var syncSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Sync + Runtime", accent: RetroPalette.chromePink)

            HStack(spacing: 10) {
                RetroCapsuleLabel(text: appState.isPortableModeEnabled ? "PORTABLE MODE" : "STANDARD MODE", accent: appState.isPortableModeEnabled ? RetroPalette.chromeCyan : RetroPalette.chromeBlue)
                Text(appState.isPortableModeEnabled ? "State is being stored in the portable ForgeText data directory." : "State is being stored in Application Support with protected local persistence for sensitive editor state.")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button("Export Sync Bundle") {
                    appState.exportSyncBundle()
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                Button("Import Sync Bundle") {
                    appState.importSyncBundle()
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                if let refreshedAt = appState.workspacePlatformState.lastRegistryRefreshAt {
                    Text("Registry refreshed \(refreshedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                        .foregroundStyle(RetroPalette.visited)
                }
            }
        }
        .padding(14)
        .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromePink)
    }

    private var registriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionHeader("Plugin Registries", accent: RetroPalette.chromeBlue)

            Text("ForgeText ships with a curated catalog, and you can add extra registry JSON feeds from a local file or HTTPS URL.")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(RetroPalette.link)
                .fixedSize(horizontal: false, vertical: true)

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

                Button("Refresh Catalog") {
                    appState.refreshPluginRegistry()
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))
            }

            if appState.settings.pluginRegistries.isEmpty {
                Text("No custom registries configured.")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
            } else {
                ForEach(appState.settings.pluginRegistries) { registry in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 8) {
                                Text(registry.name)
                                    .font(.system(size: 12, weight: .black, design: .monospaced))
                                    .foregroundStyle(RetroPalette.ink)

                                RetroCapsuleLabel(
                                    text: registry.isEnabled ? "ENABLED" : "DISABLED",
                                    accent: registry.isEnabled ? RetroPalette.success : RetroPalette.warning
                                )
                            }

                            Text(registry.source)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(RetroPalette.link)
                                .textSelection(.enabled)
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
                    .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeBlue)
                }
            }
        }
        .padding(14)
        .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)
    }

    private func sectionHeader(_ title: String, accent: Color) -> some View {
        HStack(spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(RetroPalette.ink)

            Rectangle()
                .fill(accent)
                .frame(height: 2)
        }
    }
}
