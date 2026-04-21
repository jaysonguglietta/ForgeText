import SwiftUI

struct KeyboardShortcutsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

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

    private var filteredShortcuts: [(String, String)] {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return shortcuts
        }

        return shortcuts.filter {
            $0.0.localizedCaseInsensitiveContains(trimmedQuery) ||
                $0.1.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text("Keyboard Shortcuts")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                }

                TextField("Search shortcuts", text: $query)
                    .textFieldStyle(.plain)
                    .retroTextField()

                List(filteredShortcuts, id: \.0) { item in
                    HStack {
                        Text(item.0)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(RetroPalette.ink)
                        Spacer()
                        Text(item.1)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(RetroPalette.link)
                    }
                    .listRowBackground(RetroPalette.panelFillMuted)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(RetroPalette.panelFillMuted)

                Text("Shortcut customization is staged here as a searchable editor surface; command rebinding can be wired behind these rows without changing the UI.")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
            }
            .padding(18)
            .frame(minWidth: 520, minHeight: 360)
            .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)
            .padding(18)
        }
    }
}
