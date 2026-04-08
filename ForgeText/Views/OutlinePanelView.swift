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
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(RetroPalette.ink)
                Spacer()
                Text("\(outline.count)")
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeTeal)

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
                                    .font(.system(size: 12, weight: currentLine >= item.lineNumber ? .bold : .medium, design: .monospaced))
                                    .foregroundStyle(RetroPalette.ink)
                                    .lineLimit(1)

                                if let detail = item.detail, !detail.isEmpty {
                                    Text(detail)
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundStyle(RetroPalette.link)
                                        .lineLimit(1)
                                }
                            }

                            Spacer(minLength: 0)

                            Text("Ln \(item.lineNumber)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(RetroPalette.visited)
                        }
                    }
                    .buttonStyle(.plain)
                    .listRowBackground(RetroPalette.panelFill)
                    .accessibilityLabel("Jump to outline item \(item.title)")
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .background(RetroPalette.panelFill)
            }
        }
        .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromeBlue)
        .frame(minWidth: 220, idealWidth: 260, maxWidth: 320)
    }
}
