import SwiftUI

struct JSONTreeView: View {
    let document: EditorDocument
    let theme: EditorTheme
    let onShowRawText: () -> Void

    @State private var filterText = ""

    private let treeDocument: JSONTreeDocument?

    init(
        document: EditorDocument,
        theme: EditorTheme,
        onShowRawText: @escaping () -> Void
    ) {
        self.document = document
        self.theme = theme
        self.onShowRawText = onShowRawText
        treeDocument = JSONTreeService.parse(document.text)
    }

    private var filteredNodes: [JSONTreeNode] {
        guard let treeDocument else {
            return []
        }

        return JSONTreeService.filteredNodes(in: treeDocument, matching: filterText)
    }

    var body: some View {
        Group {
            if let treeDocument {
                VStack(spacing: 0) {
                    summaryBar(treeDocument)
                    Divider()
                    filterBar
                    Divider()

                    if filteredNodes.isEmpty {
                        ContentUnavailableView(
                            "No Matching JSON Fields",
                            systemImage: "magnifyingglass",
                            description: Text("Try a different key, value, or type filter.")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: theme.backgroundColor))
                    } else {
                        List {
                            OutlineGroup(filteredNodes, children: \.childrenOrNil) { node in
                                JSONTreeNodeRow(node: node, theme: theme)
                                    .listRowBackground(Color(nsColor: theme.backgroundColor))
                            }
                        }
                        .listStyle(.inset)
                        .scrollContentBackground(.hidden)
                        .background(Color(nsColor: theme.backgroundColor))
                    }
                }
            } else {
                ContentUnavailableView(
                    "Couldn’t Parse JSON",
                    systemImage: "curlybraces",
                    description: Text("ForgeText couldn’t build a structured tree for this file. You can keep working with the raw text version.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: theme.backgroundColor))
                .overlay(alignment: .bottom) {
                    Button("Open Raw Text") {
                        onShowRawText()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 28)
                }
            }
        }
    }

    private func summaryBar(_ treeDocument: JSONTreeDocument) -> some View {
        HStack(spacing: 12) {
            Label("JSON Tree", systemImage: "list.bullet.indent")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(nsColor: theme.textColor))

            summaryPill(treeDocument.topLevelType.displayName)
            summaryPill("\(treeDocument.topLevelCount) top-level")
            summaryPill("\(treeDocument.nodeCount) nodes")
            summaryPill("Depth \(treeDocument.maxDepth)")

            Spacer(minLength: 0)

            Button("Raw Text") {
                onShowRawText()
            }
            .buttonStyle(.bordered)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(nsColor: theme.gutterBackgroundColor))
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField("Filter keys, values, and types", text: $filterText)
                .textFieldStyle(.plain)

            if !filterText.isEmpty {
                Button("Clear") {
                    filterText = ""
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(nsColor: theme.backgroundColor))
    }

    private func summaryPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(nsColor: theme.secondaryTextColor))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color(nsColor: theme.backgroundColor).opacity(0.55))
            )
    }
}

private struct JSONTreeNodeRow: View {
    let node: JSONTreeNode
    let theme: EditorTheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: node.kind.symbolName)
                .foregroundStyle(Color(nsColor: theme.secondaryTextColor))
                .frame(width: 18, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(node.primaryLabel)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(nsColor: theme.textColor))

                    Text(node.kind.displayName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(nsColor: theme.secondaryTextColor))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            Capsule()
                                .fill(Color(nsColor: theme.gutterBackgroundColor))
                        )
                }

                Text(node.summary)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color(nsColor: theme.secondaryTextColor))
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 4)
    }
}
