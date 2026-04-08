import SwiftUI

private enum RemotePanelMode: String, CaseIterable, Identifiable {
    case open
    case grep
    case command

    var id: String { rawValue }

    var title: String {
        switch self {
        case .open:
            return "Open File"
        case .grep:
            return "Remote Grep"
        case .command:
            return "Remote Command"
        }
    }
}

struct RemoteOpenView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState
    @State private var mode: RemotePanelMode = .open

    private var selectedConnection: String? {
        appState.selectedDocument?.remoteReference?.connection
            ?? RemoteFileReference.parse(appState.remoteLocationDraft)?.connection
            ?? appState.recentRemoteLocations.first?.connection
    }

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Remote Workspace")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                }

                Picker("Remote Tool", selection: $mode) {
                    ForEach(RemotePanelMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                switch mode {
                case .open:
                    openRemoteSection
                case .grep:
                    remoteSearchSection
                case .command:
                    remoteCommandSection
                }

                if !appState.recentRemoteLocations.isEmpty {
                    RetroRule()

                    Text("Recent Remote Locations")
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroPalette.visited)

                    List(appState.recentRemoteLocations, id: \.spec) { reference in
                        Button {
                            appState.remoteLocationDraft = reference.spec
                            appState.remoteWorkspaceState.searchRootPath = URL(fileURLWithPath: reference.path).deletingLastPathComponent().path
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reference.displayName)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(RetroPalette.ink)
                                Text(reference.pathDescription)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(RetroPalette.link)
                            }
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(RetroPalette.panelFillMuted)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(RetroPalette.panelFillMuted)
                }
            }
            .padding(18)
            .frame(minWidth: 760, minHeight: 520)
            .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)
            .padding(18)
        }
    }

    private var openRemoteSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Use a location like `user@host:/absolute/path/to/file`.")
                .font(.system(size: 13, weight: .medium, design: .monospaced))
                .foregroundStyle(RetroPalette.link)

            TextField("user@host:/path/to/file", text: $appState.remoteLocationDraft)
                .textFieldStyle(.plain)
                .retroTextField()
                .accessibilityLabel("Remote file location")

            HStack {
                Button("Open Remote File") {
                    appState.openRemoteDocument()
                    dismiss()
                }
                .buttonStyle(RetroActionButtonStyle(tone: .accent))

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))
            }
        }
    }

    private var remoteSearchSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(selectedConnection.map { "Searching via \($0)" } ?? "Choose a remote connection from an open remote file or the Open File tab.")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(RetroPalette.link)

            TextField("/var/log", text: $appState.remoteWorkspaceState.searchRootPath)
                .textFieldStyle(.plain)
                .retroTextField()
                .accessibilityLabel("Remote search root")

            TextField("Search remote files", text: $appState.remoteWorkspaceState.searchQuery)
                .textFieldStyle(.plain)
                .retroTextField()
                .accessibilityLabel("Remote search query")

            HStack {
                Button(appState.remoteWorkspaceState.isSearching ? "Searching..." : "Run Remote Grep") {
                    appState.runRemoteSearch()
                }
                .buttonStyle(RetroActionButtonStyle(tone: .accent))
                .disabled(appState.remoteWorkspaceState.isSearching)

                if let statusMessage = appState.remoteWorkspaceState.statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(RetroPalette.link)
                }
            }

            if !appState.remoteWorkspaceState.grepResults.isEmpty {
                List(appState.remoteWorkspaceState.grepResults) { hit in
                    Button {
                        appState.openRemoteSearchHit(hit)
                        dismiss()
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(hit.path):\(hit.lineNumber)")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(RetroPalette.ink)

                            Text(hit.lineText)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(RetroPalette.link)
                                .lineLimit(2)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(RetroPalette.panelFillMuted)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(RetroPalette.panelFillMuted)
                .frame(maxHeight: 220)
            }
        }
    }

    private var remoteCommandSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(selectedConnection.map { "Running commands via \($0)" } ?? "Choose a remote connection from an open remote file or the Open File tab.")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(RetroPalette.link)

            TextField("journalctl -n 200", text: $appState.remoteWorkspaceState.commandText)
                .textFieldStyle(.plain)
                .retroTextField()
                .accessibilityLabel("Remote command")

            HStack {
                Button(appState.remoteWorkspaceState.isRunningCommand ? "Running..." : "Run Command") {
                    appState.runRemoteCommand()
                }
                .buttonStyle(RetroActionButtonStyle(tone: .accent))
                .disabled(appState.remoteWorkspaceState.isRunningCommand)

                RetroCapsuleLabel(text: appState.remoteWorkspaceState.lastCommandStatus.displayName, accent: accent(for: appState.remoteWorkspaceState.lastCommandStatus))
            }

            if let output = appState.remoteWorkspaceState.lastCommandOutput {
                ScrollView {
                    Text(output)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(12)
                        .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeTeal)
                }
                .frame(maxHeight: 240)
            }
        }
    }

    private func accent(for status: PluginExecutionStatus) -> Color {
        switch status {
        case .idle:
            return RetroPalette.chromeTeal
        case .running:
            return RetroPalette.chromeGold
        case .succeeded:
            return RetroPalette.success
        case .failed:
            return RetroPalette.danger
        }
    }
}
