import SwiftUI

struct FindReplaceBar: View {
    @ObservedObject var appState: AppState
    let document: EditorDocument

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                RetroSectionHeader(title: "Find / Replace", systemImage: "magnifyingglass", accent: RetroPalette.chromeTeal)
                    .frame(width: 168)

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
                    .tint(RetroPalette.chromePink)

                    Toggle(".*", isOn: Binding(
                        get: { document.findState.usesRegularExpression },
                        set: { appState.setRegexFind($0) }
                    ))
                    .toggleStyle(.button)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tint(RetroPalette.chromeTeal)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
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
                    .buttonStyle(RetroActionButtonStyle(tone: .accent))

                    Button {
                        appState.hideFindReplace()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(RetroIconButtonStyle(accent: RetroPalette.chromePink))
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .retroPanel(fill: RetroPalette.railFill, accent: RetroPalette.chromeTeal)
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
        .frame(maxWidth: 240, alignment: .leading)
    }
}
