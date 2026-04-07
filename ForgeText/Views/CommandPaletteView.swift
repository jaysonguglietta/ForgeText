import SwiftUI

struct CommandPaletteView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState
    @State private var query = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Command Palette")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }

            TextField("Type a command, theme, language, or file name", text: $query)
                .textFieldStyle(.roundedBorder)

            List(appState.paletteItems(matching: query)) { item in
                Button {
                    dismiss()
                    appState.performPaletteAction(item.action)
                } label: {
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: item.symbolName)
                            .foregroundStyle(.secondary)
                            .frame(width: 18)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(item.title)
                                .foregroundStyle(.primary)
                            Text(item.subtitle)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }

                        Spacer(minLength: 0)
                    }
                }
                .buttonStyle(.plain)
            }
            .listStyle(.inset)
        }
        .padding(18)
        .frame(minWidth: 680, minHeight: 420)
    }
}

