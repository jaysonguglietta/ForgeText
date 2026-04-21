import SwiftUI

struct FindReplaceBar: View {
    @ObservedObject var appState: AppState
    let document: EditorDocument

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 9) {
                Label("Find / Replace", systemImage: "magnifyingglass")
                    .font(.system(size: 11, weight: .black, design: .monospaced))
                    .foregroundStyle(RetroPalette.ink)
                    .frame(width: 132, alignment: .leading)

                labeledField(
                    title: "Find",
                    text: Binding(
                        get: { document.findState.query },
                        set: { appState.updateFindQuery($0) }
                    ),
                    submit: appState.findNextMatch
                )

                labeledField(
                    title: "Replace",
                    text: Binding(
                        get: { document.findState.replacement },
                        set: { appState.updateReplacementQuery($0) }
                    ),
                    submit: appState.replaceCurrentMatch
                )

                HStack(spacing: 8) {
                    Toggle("Aa", isOn: Binding(
                        get: { document.findState.isCaseSensitive },
                        set: { appState.setCaseSensitiveFind($0) }
                    ))
                    .toggleStyle(.button)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tint(RetroPalette.chromeBlue)

                    Toggle(".*", isOn: Binding(
                        get: { document.findState.usesRegularExpression },
                        set: { appState.setRegexFind($0) }
                    ))
                    .toggleStyle(.button)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tint(RetroPalette.chromeTeal)
                }
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)

                Spacer(minLength: 0)

                HStack(spacing: 6) {
                    Button {
                        appState.findPreviousMatch()
                    } label: {
                        Image(systemName: "chevron.up")
                    }
                    .buttonStyle(RetroIconButtonStyle(accent: RetroPalette.chromeTeal))

                    Button {
                        appState.findNextMatch()
                    } label: {
                        Image(systemName: "chevron.down")
                    }
                    .buttonStyle(RetroIconButtonStyle(accent: RetroPalette.chromeTeal))

                    Button("Replace") {
                        appState.replaceCurrentMatch()
                    }
                    .disabled(document.findState.matchRanges.isEmpty)
                    .buttonStyle(RetroActionButtonStyle(tone: .primary))

                    Button("Replace All") {
                        appState.replaceAllMatches()
                    }
                    .disabled(document.findState.matchRanges.isEmpty)
                    .buttonStyle(RetroActionButtonStyle(tone: .primary))

                    Button {
                        appState.hideFindReplace()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(RetroIconButtonStyle(accent: RetroPalette.chromeBlue))
                }
            }

            HStack {
                Text(document.findState.summary)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(document.findState.errorMessage == nil ? RetroPalette.link : RetroPalette.danger)

                Spacer(minLength: 0)

                if document.isLargeFileMode {
                    Text("Large file mode keeps highlighting lightweight.")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(RetroPalette.visited)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .retroPanel(fill: RetroPalette.railFill, accent: RetroPalette.chromeBlue)
    }

    private func labeledField(title: String, text: Binding<String>, submit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .tracking(0.7)
                .foregroundStyle(RetroPalette.mutedInk)

            TextField(title, text: text)
                .textFieldStyle(.plain)
                .retroTextField()
                .onSubmit(submit)
        }
        .frame(maxWidth: 230, alignment: .leading)
    }
}
