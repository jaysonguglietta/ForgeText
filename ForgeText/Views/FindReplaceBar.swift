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
                .textFieldStyle(.roundedBorder)
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
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    appState.replaceCurrentMatch()
                }

                Toggle("Aa", isOn: Binding(
                    get: { document.findState.isCaseSensitive },
                    set: { appState.setCaseSensitiveFind($0) }
                ))
                .toggleStyle(.button)
                .font(.system(size: 11, weight: .bold, design: .monospaced))

                Toggle(".*", isOn: Binding(
                    get: { document.findState.usesRegularExpression },
                    set: { appState.setRegexFind($0) }
                ))
                .toggleStyle(.button)
                .font(.system(size: 11, weight: .bold, design: .monospaced))

                Spacer(minLength: 0)

                Button {
                    appState.findPreviousMatch()
                } label: {
                    Image(systemName: "chevron.up")
                }

                Button {
                    appState.findNextMatch()
                } label: {
                    Image(systemName: "chevron.down")
                }

                Button("Replace") {
                    appState.replaceCurrentMatch()
                }
                .disabled(document.findState.matchRanges.isEmpty)

                Button("Replace All") {
                    appState.replaceAllMatches()
                }
                .disabled(document.findState.matchRanges.isEmpty)

                Button {
                    appState.hideFindReplace()
                } label: {
                    Image(systemName: "xmark")
                }
            }

            HStack {
                Text(document.findState.summary)
                    .font(.caption)
                    .foregroundStyle(document.findState.errorMessage == nil ? Color.secondary : Color.red)

                Spacer(minLength: 0)

                if document.isLargeFileMode {
                    Text("Large file mode keeps highlighting lightweight.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}
