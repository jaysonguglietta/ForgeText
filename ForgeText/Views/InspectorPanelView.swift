import SwiftUI

struct InspectorPanelView: View {
    let document: EditorDocument
    let currentLine: Int
    let theme: EditorTheme
    let diagnostics: [PluginDiagnostic]
    let blame: GitBlameInfo?
    let showsOutline: Bool
    let onSelectLine: (Int) -> Void

    private var outline: [OutlineItem] {
        DocumentOutlineService.outline(for: document)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Inspector", systemImage: "sidebar.trailing")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(RetroPalette.ink)

                Spacer(minLength: 0)

                Text(document.language.displayName)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .retroPanel(fill: RetroPalette.railFill, accent: RetroPalette.chromeBlue)

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    metadataSection

                    if !diagnostics.isEmpty {
                        diagnosticsSection
                    }

                    if let blame {
                        blameSection(blame)
                    }

                    if showsOutline {
                        outlineSection
                    }
                }
                .padding(10)
            }
            .background(Color(nsColor: theme.backgroundColor))
        }
        .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)
        .frame(minWidth: 240, idealWidth: 280, maxWidth: 340)
    }

    private var metadataSection: some View {
        inspectorSection("Document", systemImage: "doc.text") {
            metadataRow("Line", "\(currentLine)")
            metadataRow("Mode", document.presentationMode.displayName)
            metadataRow("Encoding", document.encoding.displayName)
            metadataRow("Line Endings", document.lineEnding.label)

            if let fileSize = document.fileSize {
                metadataRow("Size", ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
            }

            if document.isDirty {
                metadataRow("State", "Edited")
            }
        }
    }

    private var diagnosticsSection: some View {
        inspectorSection("Current Line Issues", systemImage: "exclamationmark.triangle") {
            ForEach(diagnostics) { diagnostic in
                VStack(alignment: .leading, spacing: 4) {
                    Text(diagnostic.severity.displayName)
                        .font(.system(size: 10, weight: .black, design: .monospaced))
                        .foregroundStyle(diagnostic.severity == .error ? RetroPalette.danger : RetroPalette.warning)

                    Text(diagnostic.message)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .retroInsetPanel(fill: RetroPalette.fieldFill, accent: diagnostic.severity == .error ? RetroPalette.danger : RetroPalette.warning)
            }
        }
    }

    private func blameSection(_ blame: GitBlameInfo) -> some View {
        inspectorSection("Git Blame", systemImage: "point.topleft.down.curvedto.point.bottomright.up") {
            metadataRow("Author", blame.author)
            metadataRow("Commit", blame.shortCommitHash)
            Text(blame.summary)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(RetroPalette.ink)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var outlineSection: some View {
        inspectorSection("Outline", systemImage: "list.bullet.indent") {
            if outline.isEmpty {
                Text("No headings, sections, or symbols found.")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
            } else {
                ForEach(outline) { item in
                    Button {
                        onSelectLine(item.lineNumber)
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Color.clear
                                .frame(width: CGFloat(item.level * 8), height: 1)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.title)
                                    .font(.system(size: 11, weight: currentLine >= item.lineNumber ? .bold : .medium, design: .monospaced))
                                    .foregroundStyle(RetroPalette.ink)
                                    .lineLimit(1)

                                Text("Ln \(item.lineNumber)")
                                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(RetroPalette.link)
                            }

                            Spacer(minLength: 0)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func inspectorSection<Content: View>(
        _ title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(RetroPalette.ink)

            content()
        }
        .padding(10)
        .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromeBlue)
    }

    private func metadataRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title.uppercased())
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .foregroundStyle(RetroPalette.mutedInk)
                .frame(width: 78, alignment: .leading)

            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(RetroPalette.ink)
                .lineLimit(2)

            Spacer(minLength: 0)
        }
    }
}
