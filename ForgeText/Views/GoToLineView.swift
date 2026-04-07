import SwiftUI

struct GoToLineView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState
    @State private var lineText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Go To Line")
                .font(.system(size: 22, weight: .bold, design: .rounded))

            Text("Jump directly to a line number in the current document.")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)

            TextField("Line number", text: $lineText)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    submit()
                }

            HStack {
                Spacer()

                Button("Cancel") {
                    dismiss()
                }

                Button("Go") {
                    submit()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 360)
    }

    private func submit() {
        guard let lineNumber = Int(lineText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            return
        }

        appState.goToLine(lineNumber)
        dismiss()
    }
}
