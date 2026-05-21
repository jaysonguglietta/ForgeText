import SwiftUI

struct CommandPaletteView: View {
    @Environment(\.retroChromeStyle) private var chromeStyle
    @ObservedObject var appState: AppState
    @State private var query = ""
    @State private var mode: CommandPaletteMode = .all

    private var items: [AppState.PaletteItem] {
        appState.paletteItems(matching: query, mode: mode)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Label("Command Palette", systemImage: "command")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(RetroPalette.ink)

                Spacer(minLength: 0)

                Text("Search commands, files, symbols, tasks, and recent places")
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(RetroPalette.link)
                    .lineLimit(1)

                Button("Close") {
                    dismissOverlay()
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))
            }

            TextField("Type >commands, @files, #symbols, themes, languages, tasks, or recent files", text: $query)
                .textFieldStyle(.plain)
                .retroTextField()

            HStack(spacing: 10) {
                Picker("Mode", selection: $mode) {
                    ForEach(CommandPaletteMode.allCases) { mode in
                        Label(mode.displayName, systemImage: mode.symbolName)
                            .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 340)

                Text(mode.hint)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)

                Spacer(minLength: 0)

                Button("Reindex") {
                    appState.refreshWorkspaceIndex()
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))
            }

            List(items) { item in
                Button {
                    dismissOverlay()
                    appState.performPaletteAction(item.action)
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: item.symbolName)
                            .foregroundStyle(item.kind == .command ? RetroPalette.chromeBlue : RetroPalette.chromePink)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(item.title)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(RetroPalette.ink)
                            Text(item.subtitle)
                                .font(.system(size: 11, weight: .regular))
                                .foregroundStyle(RetroPalette.link)
                                .lineLimit(1)
                        }

                        Spacer(minLength: 0)

                        RetroCapsuleLabel(
                            text: item.kind.rawValue,
                            accent: item.kind == .symbol ? RetroPalette.chromePink : RetroPalette.chromeTeal
                        )
                    }
                    .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
                .listRowBackground(chromeStyle == .studio ? RetroPalette.studioPanelMuted : RetroPalette.panelFillMuted)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(chromeStyle == .studio ? RetroPalette.studioPanelMuted : RetroPalette.panelFillMuted)
        }
        .padding(14)
        .frame(minWidth: 720, idealWidth: 760, minHeight: 400)
        .background(chromeStyle == .studio ? RetroPalette.studioCanvasMuted : RetroPalette.pageCream)
        .retroPanel(fill: chromeStyle == .studio ? RetroPalette.studioPanel : RetroPalette.panelFill, accent: RetroPalette.chromePink)
        .padding(14)
    }

    private func dismissOverlay() {
        appState.showingCommandPalette = false
        appState.showingQuickOpen = false
    }
}
