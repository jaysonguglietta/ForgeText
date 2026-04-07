import SwiftUI

struct ConfigInspectorView: View {
    let document: EditorDocument
    let theme: EditorTheme
    let onShowRawText: () -> Void
    let onSelectLine: (Int) -> Void

    @State private var filterText = ""

    private let configDocument: StructuredConfigDocument?

    init(
        document: EditorDocument,
        theme: EditorTheme,
        onShowRawText: @escaping () -> Void,
        onSelectLine: @escaping (Int) -> Void
    ) {
        self.document = document
        self.theme = theme
        self.onShowRawText = onShowRawText
        self.onSelectLine = onSelectLine
        configDocument = StructuredConfigService.parse(
            document.text,
            url: document.fileURL ?? document.remoteReference.map { URL(fileURLWithPath: $0.path) }
        )
    }

    private var filteredNodes: [StructuredConfigNode] {
        guard let configDocument else {
            return []
        }

        return StructuredConfigService.filteredNodes(in: configDocument, matching: filterText)
    }

    var body: some View {
        Group {
            if let configDocument {
                VStack(spacing: 0) {
                    summaryBar(configDocument)
                    Divider()
                    filterBar
                    Divider()

                    if filteredNodes.isEmpty {
                        ContentUnavailableView(
                            "No Matching Config Keys",
                            systemImage: "slider.horizontal.below.square.filled.and.square",
                            description: Text("Try a different key, section, or value filter.")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: theme.backgroundColor))
                    } else {
                        List {
                            OutlineGroup(filteredNodes, children: \.childrenOrNil) { node in
                                Button {
                                    onSelectLine(node.lineNumber)
                                } label: {
                                    ConfigInspectorRow(node: node, theme: theme)
                                }
                                .buttonStyle(.plain)
                                .listRowBackground(Color(nsColor: theme.backgroundColor))
                                .accessibilityLabel("Jump to config key \(node.key)")
                            }
                        }
                        .listStyle(.inset)
                        .scrollContentBackground(.hidden)
                        .background(Color(nsColor: theme.backgroundColor))
                    }
                }
            } else {
                ContentUnavailableView(
                    "Couldn’t Inspect This Config",
                    systemImage: "slider.horizontal.below.square.filled.and.square",
                    description: Text("ForgeText couldn’t build a structured config view. You can still work with the raw text version.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: theme.backgroundColor))
                .overlay(alignment: .bottom) {
                    Button("Open Raw Text") {
                        onShowRawText()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 28)
                    .accessibilityLabel("Open raw config text")
                }
            }
        }
    }

    private func summaryBar(_ configDocument: StructuredConfigDocument) -> some View {
        HStack(spacing: 12) {
            Label("Config Inspector", systemImage: "slider.horizontal.below.square.filled.and.square")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(nsColor: theme.textColor))

            summaryPill(configDocument.format.displayName)
            summaryPill("\(configDocument.topLevelCount) top-level")
            summaryPill("\(configDocument.itemCount) items")

            Spacer(minLength: 0)

            Button("Raw Text") {
                onShowRawText()
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Switch to raw config text")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(nsColor: theme.gutterBackgroundColor))
    }

    private var filterBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color(nsColor: theme.secondaryTextColor))

            TextField("Filter sections, keys, and values", text: $filterText)
                .textFieldStyle(.plain)
                .accessibilityLabel("Filter config entries")

            if !filterText.isEmpty {
                Button("Clear") {
                    filterText = ""
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Clear config filter")
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

private struct ConfigInspectorRow: View {
    let node: StructuredConfigNode
    let theme: EditorTheme

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: iconName)
                .foregroundStyle(Color(nsColor: theme.secondaryTextColor))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(node.key)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(Color(nsColor: theme.textColor))

                    Text("Ln \(node.lineNumber)")
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

    private var iconName: String {
        switch node.kind {
        case .section:
            return "square.split.2x1"
        case .keyValue:
            return "key"
        case .arrayItem:
            return "list.bullet"
        }
    }
}
