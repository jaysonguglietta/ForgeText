import SwiftUI

struct FindReplaceBar: View {
    @ObservedObject var appState: AppState
    let document: EditorDocument

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                TextField(
                    "Find",
                    text: Binding(
                        get: { document.findState.query },
                        set: { appState.updateFindQuery($0) }
                    )
                )
                .textFieldStyle(.plain)
                .retroTextField()
                .onSubmit {
                    appState.findNextMatch()
                }

                TextField(
                    "Replace",
                    text: Binding(
                        get: { document.findState.replacement },
                        set: { appState.updateReplacementQuery($0) }
                    )
                )
                .textFieldStyle(.plain)
                .retroTextField()
                .onSubmit {
                    appState.replaceCurrentMatch()
                }

                Toggle("Aa", isOn: Binding(
                    get: { document.findState.isCaseSensitive },
                    set: { appState.setCaseSensitiveFind($0) }
                ))
                .toggleStyle(.button)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tint(RetroPalette.chromePink)

                Toggle(".*", isOn: Binding(
                    get: { document.findState.usesRegularExpression },
                    set: { appState.setRegexFind($0) }
                ))
                .toggleStyle(.button)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tint(RetroPalette.chromeTeal)

                Spacer(minLength: 0)

                Button {
                    appState.findPreviousMatch()
                } label: {
                    Image(systemName: "chevron.up")
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                Button {
                    appState.findNextMatch()
                } label: {
                    Image(systemName: "chevron.down")
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                Button("Replace") {
                    appState.replaceCurrentMatch()
                }
                .disabled(document.findState.matchRanges.isEmpty)
                .buttonStyle(RetroActionButtonStyle(tone: .primary))

                Button("Replace All") {
                    appState.replaceAllMatches()
                }
                .disabled(document.findState.matchRanges.isEmpty)
                .buttonStyle(RetroActionButtonStyle(tone: .accent))

                Button {
                    appState.hideFindReplace()
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromeTeal)
    }
}
