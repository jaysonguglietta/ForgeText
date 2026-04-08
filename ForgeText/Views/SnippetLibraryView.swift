import SwiftUI

struct SnippetLibraryView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var snippets: [EditorPluginSnippet] {
        appState.availableSnippets(matching: query)
    }

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Label("Snippet Library", systemImage: "text.badge.plus")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)

                    Spacer(minLength: 0)

                    if let language = appState.selectedDocument?.language {
                        RetroCapsuleLabel(text: language.displayName, accent: RetroPalette.chromeGold)
                    }

                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .primary))
                }
                .padding(16)
                .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)

                RetroRule()

                VStack(alignment: .leading, spacing: 12) {
                    Text("Snippets are format-aware templates. They drop into the current cursor position and respect your active document language.")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(RetroPalette.link)

                    TextField("Search snippets", text: $query)
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
                        if snippets.isEmpty {
                            Text("No snippets are available for the current document.")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(RetroPalette.link)
                                .padding(.top, 32)
                        } else {
                            ForEach(snippets) { snippet in
                                snippetCard(snippet)
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

    private func snippetCard(_ snippet: EditorPluginSnippet) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Label(snippet.title, systemImage: snippet.symbolName)
                        .font(.system(size: 16, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)

                    Text(snippet.detail)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(RetroPalette.link)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button("Insert") {
                    appState.insertSnippet(snippet)
                    dismiss()
                }
                .buttonStyle(RetroActionButtonStyle(tone: .primary))
            }

            Text(snippet.previewText)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(RetroPalette.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
                .padding(12)
                .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeTeal)
        }
        .padding(14)
        .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)
    }
}
