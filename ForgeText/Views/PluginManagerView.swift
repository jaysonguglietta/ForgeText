import SwiftUI

struct PluginManagerView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filteredPlugins: [EditorPlugin] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return appState.installedPlugins
        }

        return appState.installedPlugins.filter { plugin in
            let candidate = [
                plugin.manifest.name,
                plugin.manifest.summary,
                plugin.manifest.category.displayName,
                plugin.manifest.capabilities.map(\.displayName).joined(separator: " "),
            ]
            .joined(separator: " ")

            return candidate.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    private var filteredRegistryEntries: [PluginRegistryEntry] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return appState.availableRegistryPlugins
        }

        return appState.availableRegistryPlugins.filter { entry in
            let candidate = [
                entry.name,
                entry.summary,
                entry.author,
                entry.category.displayName,
            ]
            .joined(separator: " ")

            return candidate.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Label("Plugin Manager", systemImage: "puzzlepiece.extension")
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

                VStack(alignment: .leading, spacing: 12) {
                    Text("Built-in IDE plugins let ForgeText grow without turning the editor shell into a pile of one-off controls.")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(RetroPalette.link)

                    TextField("Search plugins", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeBlue)
                }
                .padding(16)
                .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)

                RetroRule()

                ScrollView {
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Installed Plugins")
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .foregroundStyle(RetroPalette.ink)

                            if filteredPlugins.isEmpty {
                                Text("No installed plugins matched that search.")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(RetroPalette.link)
                                    .padding(.vertical, 12)
                            } else {
                                ForEach(filteredPlugins) { plugin in
                                    pluginCard(plugin)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Registry Catalog")
                                .font(.system(size: 13, weight: .black, design: .monospaced))
                                .foregroundStyle(RetroPalette.ink)

                            if filteredRegistryEntries.isEmpty {
                                Text("No registry plugins matched that search.")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(RetroPalette.link)
                                    .padding(.vertical, 12)
                            } else {
                                ForEach(filteredRegistryEntries) { entry in
                                    registryCard(entry)
                                }
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .padding(14)
        }
        .frame(minWidth: 820, minHeight: 600)
    }

    private func pluginCard(_ plugin: EditorPlugin) -> some View {
        let manifest = plugin.manifest

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(manifest.name)
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundStyle(RetroPalette.ink)

                        RetroCapsuleLabel(text: manifest.category.displayName, accent: RetroPalette.chromeCyan)
                        RetroCapsuleLabel(text: "v\(manifest.version)", accent: RetroPalette.chromeGold)
                    }

                    Text(manifest.summary)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(RetroPalette.link)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Author: \(manifest.author)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(RetroPalette.visited)

                    if let sourceDescription = manifest.sourceDescription, !sourceDescription.isEmpty {
                        Text("Source: \(sourceDescription)")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(RetroPalette.link)
                            .lineLimit(2)
                    }
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 8) {
                    Toggle(
                        isOn: Binding(
                            get: { appState.isPluginEnabled(plugin.id) },
                            set: { _ in appState.togglePluginEnabled(plugin.id) }
                        )
                    ) {
                        Text(appState.isPluginEnabled(plugin.id) ? "Enabled" : "Disabled")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(RetroPalette.ink)
                    }
                    .toggleStyle(.switch)

                    Text(manifest.isBuiltIn ? "Built In" : "External")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroPalette.link)

                    if !manifest.isBuiltIn {
                        Button("Remove") {
                            appState.uninstallPlugin(plugin)
                        }
                        .buttonStyle(RetroActionButtonStyle(tone: .danger))
                    }
                }
            }

            HStack(spacing: 8) {
                ForEach(manifest.capabilities) { capability in
                    RetroCapsuleLabel(text: capability.displayName, accent: RetroPalette.chromeTeal)
                }
            }

            HStack(spacing: 12) {
                infoStat(title: "Commands", value: "\(plugin.commands.count)")
                infoStat(title: "Snippets", value: "\(plugin.snippets.count)")
                infoStat(title: "Tasks", value: "\(plugin.tasks.count)")
            }
        }
        .padding(14)
        .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)
    }

    private func registryCard(_ entry: PluginRegistryEntry) -> some View {
        let isInstalled = appState.installedPlugins.contains(where: { $0.id == entry.id })

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(entry.name)
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundStyle(RetroPalette.ink)

                        RetroCapsuleLabel(text: entry.category.displayName, accent: RetroPalette.chromeCyan)
                        RetroCapsuleLabel(text: "v\(entry.version)", accent: RetroPalette.chromeGold)
                    }

                    Text(entry.summary)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(RetroPalette.link)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Author: \(entry.author)")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(RetroPalette.visited)
                }

                Spacer(minLength: 0)

                VStack(alignment: .trailing, spacing: 8) {
                    Text(isInstalled ? "Installed" : "Available")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroPalette.link)

                    Button(isInstalled ? "Installed" : "Install") {
                        if !isInstalled {
                            appState.installRegistryPlugin(entry)
                        }
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: isInstalled ? .secondary : .primary))
                    .disabled(isInstalled)
                }
            }

            HStack(spacing: 8) {
                ForEach(entry.capabilities) { capability in
                    RetroCapsuleLabel(text: capability.displayName, accent: RetroPalette.chromeTeal)
                }
            }

            HStack(spacing: 12) {
                infoStat(title: "Snippets", value: "\(entry.snippets.count)")
                infoStat(title: "Tasks", value: "\(entry.tasks.count)")
            }
        }
        .padding(14)
        .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromeBlue)
    }

    private func infoStat(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(RetroPalette.link)

            Text(value)
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(RetroPalette.ink)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeBlue)
    }
}
