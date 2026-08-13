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
        Group {
            if chromeStyle == .studio {
                explorerContent
                    .padding(.horizontal, 4)
                    .padding(.vertical, 6)
            } else {
                explorerContent
                    .padding(12)
                    .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)
            }
        }
    }

    private var explorerContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Explorer")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(RetroPalette.ink)
                Spacer(minLength: 0)

                Menu {
                    Toggle("Show Hidden Files", isOn: Binding(
                        get: { appState.settings.showHiddenFilesInExplorer },
                        set: { newValue in
                            appState.settings.showHiddenFilesInExplorer = newValue
                            AppSettingsStore.save(appState.settings)
                            appState.refreshWorkspaceExplorer()
                        }
                    ))
                    Button("Reload Files", systemImage: "arrow.clockwise") {
                        appState.refreshWorkspaceExplorer()
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .frame(width: 24, height: 24)
                }
                .menuStyle(.borderlessButton)
                .accessibilityLabel("Explorer options")
            }

            if appState.workspaceRootURLs.count > 1 {
                Text("\(appState.workspaceRootURLs.count) roots active • \(appState.activeWorkspaceURL?.lastPathComponent ?? "none") selected")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(RetroPalette.link)
                    .lineLimit(2)
            } else if let rootURL = appState.activeWorkspaceURL {
                Text(rootURL.path(percentEncoded: false))
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(RetroPalette.link)
                    .lineLimit(2)
            } else {
                Text("Choose a workspace folder to browse files.")
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(RetroPalette.link)
            }

            if appState.activeWorkspaceURL == nil {
                Button {
                    appState.chooseWorkspaceRoot()
                } label: {
                    Label("Open Folder", systemImage: "folder.badge.plus")
                        .font(.system(size: 11, weight: .semibold))
                }
                .buttonStyle(.bordered)
            } else {
                TextField("Filter files", text: $appState.workspaceExplorerState.filterQuery)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 11))

                if filteredNodes.isEmpty {
                    Text("No files match this filter.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    explorerTree
                }
            }
        }
    }

    private var explorerTree: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                OutlineGroup(filteredNodes, children: \.childrenOrNil) { node in
                    WorkspaceExplorerRow(appState: appState, node: node)
                }
            }
            .padding(.vertical, 4)
        }
        .frame(minHeight: 280, maxHeight: 520)
        .background(
            chromeStyle == .studio
                ? RetroPalette.studioField.opacity(0.35)
                : RetroPalette.fieldFill
        )
        .clipShape(RoundedRectangle(cornerRadius: chromeStyle == .studio ? 7 : 0))
        .overlay {
            RoundedRectangle(cornerRadius: chromeStyle == .studio ? 7 : 0)
                .stroke(chromeStyle == .studio ? RetroPalette.studioBorder : RetroPalette.chromeBlue, lineWidth: 1)
        }
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
                        .font(.system(size: 11, weight: .medium))
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
