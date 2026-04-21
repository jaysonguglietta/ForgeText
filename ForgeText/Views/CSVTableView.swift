import SwiftUI

struct CSVTableView: View {
    let document: EditorDocument
    let theme: EditorTheme
    let onShowRawText: () -> Void

    private let tableDocument: DelimitedTableDocument?
    private let columnWidths: [CGFloat]
    private let tableWidth: CGFloat

    init(
        document: EditorDocument,
        theme: EditorTheme,
        onShowRawText: @escaping () -> Void
    ) {
        self.document = document
        self.theme = theme
        self.onShowRawText = onShowRawText

        let preferredDelimiter: Character?
        switch document.fileURL?.pathExtension.lowercased() {
        case "tsv", "tab":
            preferredDelimiter = "\t"
        case "csv":
            preferredDelimiter = ","
        default:
            preferredDelimiter = nil
        }

        let parsedTable = DelimitedTextTableService.parse(document.text, preferredDelimiter: preferredDelimiter)
        tableDocument = parsedTable
        columnWidths = Self.makeColumnWidths(for: parsedTable)
        tableWidth = Self.makeTableWidth(for: columnWidths)
    }

    var body: some View {
        Group {
            if let tableDocument {
                VStack(spacing: 0) {
                    summaryBar(tableDocument)
                    Divider()

                    ScrollView([.horizontal, .vertical]) {
                        VStack(alignment: .leading, spacing: 0) {
                            headerRow(tableDocument)

                            if tableDocument.rows.isEmpty {
                                emptyRowsView
                            } else {
                                ForEach(Array(tableDocument.rows.enumerated()), id: \.offset) { rowIndex, row in
                                    rowView(rowIndex: rowIndex, row: row)
                                }
                            }
                        }
                        .frame(minWidth: tableWidth, alignment: .topLeading)
                        .background(
                            StructuredScrollViewConfigurator(
                                theme: theme,
                                showsHorizontal: true,
                                showsVertical: true
                            )
                            .frame(width: 0, height: 0)
                        )
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Color(nsColor: theme.backgroundColor))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView(
                    "Couldn’t Parse as CSV",
                    systemImage: "tablecells",
                    description: Text("ForgeText couldn’t confidently turn this file into a structured table. You can still work with the raw text version.")
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

    private func summaryBar(_ tableDocument: DelimitedTableDocument) -> some View {
        HStack(spacing: 12) {
            Label("Table View", systemImage: "tablecells")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(nsColor: theme.textColor))

            summaryPill("\(tableDocument.rowCount) rows")
            summaryPill("\(tableDocument.columnCount) columns")
            summaryPill(tableDocument.delimiterLabel)

            if tableDocument.hasHeaderRow {
                summaryPill("Header Row")
            }

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

    private func headerRow(_ tableDocument: DelimitedTableDocument) -> some View {
        HStack(spacing: 0) {
            rowNumberHeader

            ForEach(Array(tableDocument.headers.enumerated()), id: \.offset) { columnIndex, header in
                cell(text: header, width: columnWidths[columnIndex], isHeader: true)
            }
        }
        .background(Color(nsColor: theme.gutterBackgroundColor))
    }

    private var rowNumberHeader: some View {
        Text("#")
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(Color(nsColor: theme.secondaryTextColor))
            .frame(width: 54, alignment: .trailing)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(Color(nsColor: theme.gutterBackgroundColor))
    }

    private func rowView(rowIndex: Int, row: [String]) -> some View {
        HStack(spacing: 0) {
            Text("\(rowIndex + 1)")
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(nsColor: theme.secondaryTextColor))
                .frame(width: 54, alignment: .trailing)
                .padding(.horizontal, 10)
                .padding(.vertical, 10)
                .background(Color(nsColor: theme.gutterBackgroundColor).opacity(rowIndex.isMultiple(of: 2) ? 0.92 : 0.72))

            ForEach(Array(row.enumerated()), id: \.offset) { columnIndex, value in
                cell(text: value, width: columnWidths[columnIndex], isHeader: false)
            }
        }
        .background(
            rowIndex.isMultiple(of: 2)
                ? Color(nsColor: theme.backgroundColor)
                : Color(nsColor: theme.gutterBackgroundColor).opacity(0.14)
        )
    }

    private var emptyRowsView: some View {
        HStack(spacing: 0) {
            Text(" ")
                .frame(width: 54, alignment: .trailing)
                .padding(.horizontal, 10)
                .padding(.vertical, 18)
                .background(Color(nsColor: theme.gutterBackgroundColor).opacity(0.72))

            Text("No data rows found. The header is still shown above; switch to Raw Text to edit the source directly.")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(nsColor: theme.secondaryTextColor))
                .frame(width: max(tableWidth - 74, 260), alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 18)
        }
        .background(Color(nsColor: theme.backgroundColor))
    }

    private func cell(text: String, width: CGFloat, isHeader: Bool) -> some View {
        Text(text.isEmpty ? " " : text)
            .font(.system(size: 12, weight: isHeader ? .semibold : .regular, design: .monospaced))
            .foregroundStyle(Color(nsColor: isHeader ? theme.textColor : theme.textColor))
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .overlay(alignment: .trailing) {
                Rectangle()
                    .fill(Color(nsColor: theme.borderColor))
                    .frame(width: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color(nsColor: theme.borderColor))
                    .frame(height: 1)
            }
            .textSelection(.enabled)
    }

    private static func makeColumnWidths(for tableDocument: DelimitedTableDocument?) -> [CGFloat] {
        guard let tableDocument else {
            return []
        }

        let sampleRows = Array(tableDocument.rows.prefix(30))

        return tableDocument.headers.enumerated().map { columnIndex, header in
            let candidateLengths = sampleRows.map { row -> Int in
                guard row.indices.contains(columnIndex) else {
                    return 0
                }

                return row[columnIndex].count
            }

            let maxLength = max(header.count, candidateLengths.max() ?? 0)
            let width = CGFloat(maxLength * 8 + 36)
            return min(max(width, 110), 320)
        }
    }

    private static func makeTableWidth(for columnWidths: [CGFloat]) -> CGFloat {
        74 + columnWidths.reduce(0) { partialResult, width in
            partialResult + width + 24
        }
    }
}
