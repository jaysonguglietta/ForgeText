import SwiftUI

struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss

    private let shortcuts: [(String, String)] = [
        ("New Document", "Command-N"),
        ("Open Files", "Command-O"),
        ("Save", "Command-S"),
        ("Save As", "Shift-Command-S"),
        ("Find and Replace", "Command-F"),
        ("Search in Folder", "Shift-Command-F"),
        ("Command Palette", "Shift-Command-P"),
        ("Go to Line", "Command-L"),
        ("Next Match", "Command-G"),
        ("Previous Match", "Shift-Command-G"),
        ("Toggle Comment", "Command-/"),
        ("Next Document", "Shift-Command-]"),
        ("Previous Document", "Shift-Command-["),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Keyboard Shortcuts")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }

            List(shortcuts, id: \.0) { item in
                HStack {
                    Text(item.0)
                    Spacer()
                    Text(item.1)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            .listStyle(.inset)
        }
        .padding(18)
        .frame(minWidth: 520, minHeight: 360)
    }
}
