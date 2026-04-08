import SwiftUI

struct CommandPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState
    @State private var query = ""

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

                TextField("Type a command, theme, language, or file name", text: $query)
                    .textFieldStyle(.plain)
                    .retroTextField()

                List(appState.paletteItems(matching: query)) { item in
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
            .frame(minWidth: 680, minHeight: 420)
            .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)
            .padding(18)
        }
    }
}
