import SwiftUI

struct GoToLineView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState
    @State private var lineText = ""

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(alignment: .leading, spacing: 16) {
                Text("Go To Line")
                    .font(.system(size: 22, weight: .black, design: .monospaced))
                    .foregroundStyle(RetroPalette.ink)

                Text("Jump directly to a line number in the current document.")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)

                TextField("Line number", text: $lineText)
                    .textFieldStyle(.plain)
                    .retroTextField()
                    .onSubmit {
                        submit()
                    }

                HStack {
                    Spacer()

                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                    Button("Go") {
                        submit()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .accent))
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(20)
            .frame(minWidth: 360)
            .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)
            .padding(18)
        }
    }

    private func submit() {
        guard let lineNumber = Int(lineText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }

        appState.goToLine(lineNumber)
        dismiss()
    }
}
