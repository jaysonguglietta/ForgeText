import SwiftUI

struct ArchiveBrowserView: View {
    let document: EditorDocument
    let theme: EditorTheme

    @State private var filterText = ""

    private let archiveDocument: ArchiveDocument?

    init(document: EditorDocument, theme: EditorTheme) {
        self.document = document
        self.theme = theme

        if let fileURL = document.fileURL, let archive = try? ArchiveBrowserService.loadArchive(at: fileURL) {
            archiveDocument = archive
        } else {
            let entries = document.text
                .split(whereSeparator: \.isNewline)
                .map(String.init)
                .map { ArchiveEntry(id: $0, path: $0) }
            archiveDocument = ArchiveDocument(kindLabel: "Archive", entries: entries)
        }
    }

    private var filteredEntries: [ArchiveEntry] {
        guard let archiveDocument else {
            return []
        }

        let trimmed = filterText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else {
            return archiveDocument.entries
        }

        return archiveDocument.entries.filter { $0.path.lowercased().contains(trimmed) }
    }

    var body: some View {
        Group {
            if let archiveDocument {
                VStack(spacing: 0) {
                    HStack(spacing: 12) {
                        Label("Archive Browser", systemImage: "archivebox")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Color(nsColor: theme.textColor))

                        summaryPill(archiveDocument.kindLabel)
                        summaryPill("\(archiveDocument.entries.count) entries")
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color(nsColor: theme.gutterBackgroundColor))

                    Divider()

                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(Color(nsColor: theme.secondaryTextColor))
                        TextField("Filter archive paths", text: $filterText)
                            .textFieldStyle(.plain)
                            .accessibilityLabel("Filter archive entries")
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 12)
                    .background(Color(nsColor: theme.backgroundColor))

                    Divider()

                    List(filteredEntries) { entry in
                        HStack(spacing: 10) {
                            Image(systemName: "doc")
                                .foregroundStyle(Color(nsColor: theme.secondaryTextColor))
                            Text(entry.path)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Color(nsColor: theme.textColor))
                                .textSelection(.enabled)
                        }
                        .listRowBackground(Color(nsColor: theme.backgroundColor))
                    }
                    .listStyle(.inset)
                    .scrollContentBackground(.hidden)
                    .background(Color(nsColor: theme.backgroundColor))
                }
            } else {
                ContentUnavailableView(
                    "Couldn’t Browse Archive",
                    systemImage: "archivebox",
                    description: Text("ForgeText couldn’t list the contents of this archive.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: theme.backgroundColor))
            }
        }
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
