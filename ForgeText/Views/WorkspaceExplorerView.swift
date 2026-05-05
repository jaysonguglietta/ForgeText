import SwiftUI

struct WorkspaceExplorerView: View {
    @Environment(\.retroChromeStyle) private var chromeStyle
    @ObservedObject var appState: AppState

    private var filteredNodes: [WorkspaceExplorerNode] {
        WorkspaceExplorerService.filteredNodes(
            appState.workspaceExplorerState.nodes,
            matching: appState.workspaceExplorerState.filterQuery
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Explorer")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(RetroPalette.ink)
                Spacer(minLength: 0)

                Toggle(
                    "Hidden",
                    isOn: Binding(
                        get: { appState.settings.showHiddenFilesInExplorer },
                        set: { newValue in
                            appState.settings.showHiddenFilesInExplorer = newValue
                            AppSettingsStore.save(appState.settings)
                            appState.refreshWorkspaceExplorer()
                        }
                    )
                )
                .toggleStyle(.switch)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(RetroPalette.link)

                Button("Reload") {
                    appState.refreshWorkspaceExplorer()
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))
            }

            if appState.workspaceRootURLs.count > 1 {
                Text("\(appState.workspaceRootURLs.count) roots active • \(appState.activeWorkspaceURL?.lastPathComponent ?? "none") selected")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
                    .lineLimit(2)
            } else if let rootURL = appState.activeWorkspaceURL {
                Text(rootURL.path(percentEncoded: false))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
                    .lineLimit(2)
            } else {
                Text("Choose a workspace folder to browse files.")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
            }

            TextField("Filter files", text: $appState.workspaceExplorerState.filterQuery)
                .textFieldStyle(.plain)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .retroTextField()

            if filteredNodes.isEmpty {
                Button {
                    appState.chooseWorkspaceRoot()
                } label: {
                    Text(appState.activeWorkspaceURL == nil ? "Choose Workspace Folder" : "No files matched the explorer filter")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        OutlineGroup(filteredNodes, children: \.childrenOrNil) { node in
                            WorkspaceExplorerRow(appState: appState, node: node)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(minHeight: 280, maxHeight: 520)
                .retroInsetPanel(fill: chromeStyle == .studio ? RetroPalette.studioField : RetroPalette.fieldFill, accent: RetroPalette.chromeBlue)
            }
        }
        .padding(12)
        .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)
    }
}

private struct WorkspaceExplorerRow: View {
    @Environment(\.retroChromeStyle) private var chromeStyle
    @ObservedObject var appState: AppState
    let node: WorkspaceExplorerNode

    var body: some View {
        HStack(spacing: 8) {
            Button {
                appState.openWorkspaceExplorerNode(node)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: node.isDirectory ? "folder" : "doc.text")
                        .foregroundStyle(node.isDirectory ? RetroPalette.chromeGold : RetroPalette.link)
                        .frame(width: 16)

                    Text(node.name)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)
                        .lineLimit(1)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button {
                appState.toggleWorkspaceFavorite(node.url)
            } label: {
                Image(systemName: node.isFavorite ? "star.fill" : "star")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(node.isFavorite ? RetroPalette.chromePink : RetroPalette.visited)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: chromeStyle == .studio ? 6 : 0, style: .continuous)
                .fill(node.isFavorite ? RetroPalette.chromePink.opacity(chromeStyle == .studio ? 0.08 : 0.0) : Color.clear)
        )
    }
}
