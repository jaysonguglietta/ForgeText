import SwiftUI

struct CommandPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState
    @State private var query = ""
    @State private var mode: CommandPaletteMode = .all

    private var items: [AppState.PaletteItem] {
        appState.paletteItems(matching: query, mode: mode)
    }

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Command Palette")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                }

                HStack(spacing: 10) {
                    Picker("Mode", selection: $mode) {
                        ForEach(CommandPaletteMode.allCases) { mode in
                            Label(mode.displayName, systemImage: mode.symbolName)
                                .tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 420)

                    Button("Reindex") {
                        appState.refreshWorkspaceIndex()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                }

                TextField("Type >commands, @files, #symbols, themes, languages, tasks, or recent files", text: $query)
                    .textFieldStyle(.plain)
                    .retroTextField()

                HStack(spacing: 8) {
                    ForEach(CommandPaletteMode.allCases) { mode in
                        RetroCapsuleLabel(text: mode.prefix.map { "\($0) \(mode.displayName)" } ?? mode.displayName, accent: mode == self.mode ? RetroPalette.chromePink : RetroPalette.chromeBlue)
                    }
                    Spacer(minLength: 0)
                    Text(mode.hint)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroPalette.link)
                }

                List(items) { item in
                    Button {
                        dismiss()
                        appState.performPaletteAction(item.action)
                    } label: {
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: item.symbolName)
                                .foregroundStyle(RetroPalette.chromePink)
                                .frame(width: 18)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                    .foregroundStyle(RetroPalette.ink)
                                Text(item.subtitle)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(RetroPalette.link)
                                    .lineLimit(2)
                            }

                            Spacer(minLength: 0)

                            RetroCapsuleLabel(text: item.kind.rawValue, accent: item.kind == .symbol ? RetroPalette.chromePink : RetroPalette.chromeTeal)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(RetroPalette.panelFillMuted)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(RetroPalette.panelFillMuted)
            }
            .padding(18)
            .frame(minWidth: 760, minHeight: 520)
            .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)
            .padding(18)
        }
    }
}
