import SwiftUI

struct OutlinePanelView: View {
    let document: EditorDocument
    let currentLine: Int
    let theme: EditorTheme
    let onSelectLine: (Int) -> Void

    private var outline: [OutlineItem] {
        DocumentOutlineService.outline(for: document)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Outline")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(nsColor: theme.secondaryTextColor))
                Spacer()
                Text("\(outline.count)")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(nsColor: theme.secondaryTextColor))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(nsColor: theme.gutterBackgroundColor))

            if outline.isEmpty {
                ContentUnavailableView(
                    "No Outline",
                    systemImage: "list.bullet.indent",
                    description: Text("ForgeText couldn’t find headings, sections, or symbols in this file.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: theme.backgroundColor))
            } else {
                List(outline) { item in
                    Button {
                        onSelectLine(item.lineNumber)
                    } label: {
                        HStack(spacing: 10) {
                            Color.clear
                                .frame(width: CGFloat(item.level * 10), height: 1)

                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.title)
                                    .font(.system(size: 12, weight: currentLine >= item.lineNumber ? .semibold : .regular))
                                    .foregroundStyle(Color(nsColor: theme.textColor))
                                    .lineLimit(1)

                                if let detail = item.detail, !detail.isEmpty {
                                    Text(detail)
                                        .font(.caption)
                                        .foregroundStyle(Color(nsColor: theme.secondaryTextColor))
                                        .lineLimit(1)
                                }
                            }

                            Spacer(minLength: 0)

                            Text("Ln \(item.lineNumber)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(Color(nsColor: theme.secondaryTextColor))
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(Color(nsColor: theme.backgroundColor))
                    .accessibilityLabel("Jump to outline item \(item.title)")
                }
                .listStyle(.inset)
                .scrollContentBackground(.hidden)
                .background(Color(nsColor: theme.backgroundColor))
            }
        }
        .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
    }
}
