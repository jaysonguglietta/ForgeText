import AppKit
import SwiftUI

struct CSVTableView: View {
    let document: EditorDocument
    let theme: EditorTheme
    let onShowRawText: () -> Void

    private let tableDocument: DelimitedTableDocument?
    private let columnWidths: [CGFloat]
    private let tableWidth: CGFloat
    @State private var filterText = ""
    @State private var sortDescriptors: [DelimitedSortDescriptor] = []
    @State private var schema: [DelimitedColumnSchema] = []
    @State private var aggregationRequests: [DelimitedAggregationRequest] = []
    @State private var freezesFirstColumn = false
    @State private var showsColumnTypes = true
    @State private var showingSchemaEditor = false

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
        _schema = State(initialValue: parsedTable.map { table in
            table.headers.enumerated().map { index, header in
                DelimitedColumnSchema(columnIndex: index, displayName: header, type: table.columnTypes[index])
            }
        } ?? [])
    }

    var body: some View {
        Group {
            if let originalTableDocument = tableDocument {
                let tableDocument = DelimitedTextTableService.applying(schema: schema, to: originalTableDocument)
                VStack(spacing: 0) {
                    summaryBar(tableDocument)
                    Divider()

                    if !aggregationRequests.isEmpty {
                        aggregationBar(tableDocument)
                        Divider()
                    }

                    tableBody(tableDocument)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(Color(nsColor: theme.backgroundColor))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .sheet(isPresented: $showingSchemaEditor) {
                    DelimitedSchemaEditorView(schema: $schema)
                }
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
        HStack(spacing: 10) {
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

            TextField("Filter rows", text: $filterText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
                .accessibilityLabel("Filter table rows")

            Menu {
                Button("Original order") {
                    sortDescriptors = []
                }
                Divider()
                ForEach(Array(tableDocument.headers.enumerated()), id: \.offset) { columnIndex, header in
                    Menu(header) {
                        Button("Sort ascending") {
                            setPrimarySort(columnIndex: columnIndex, ascending: true)
                        }
                        Button("Sort descending") {
                            setPrimarySort(columnIndex: columnIndex, ascending: false)
                        }
                        Button("Add as secondary sort") {
                            addSecondarySort(columnIndex: columnIndex)
                        }
                    }
                }
                Divider()
                Menu("Aggregations") {
                    ForEach(Array(tableDocument.headers.enumerated()), id: \.offset) { columnIndex, header in
                        Menu(header) {
                            Button("Count") { toggleAggregation(columnIndex: columnIndex, kind: .count) }
                            if [.integer, .decimal].contains(tableDocument.columnTypes[columnIndex]) {
                                Button("Sum") { toggleAggregation(columnIndex: columnIndex, kind: .sum) }
                                Button("Average") { toggleAggregation(columnIndex: columnIndex, kind: .average) }
                                Button("Minimum") { toggleAggregation(columnIndex: columnIndex, kind: .minimum) }
                                Button("Maximum") { toggleAggregation(columnIndex: columnIndex, kind: .maximum) }
                            }
                        }
                    }
                    if !aggregationRequests.isEmpty {
                        Divider()
                        Button("Clear aggregations") { aggregationRequests = [] }
                    }
                }
                Button("Edit column schema...") { showingSchemaEditor = true }
                Toggle("Freeze first column", isOn: $freezesFirstColumn)
                Toggle("Show column types", isOn: $showsColumnTypes)
            } label: {
                Label("View", systemImage: "line.3.horizontal.decrease.circle")
            }
            .menuStyle(.borderlessButton)

            Button {
                copyVisibleRows(tableDocument)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }
            .buttonStyle(.bordered)

            Button {
                exportVisibleRows(tableDocument)
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .buttonStyle(.bordered)

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
                headerCell(
                    text: header,
                    type: tableDocument.columnTypes[columnIndex],
                    width: columnWidths[columnIndex],
                    columnIndex: columnIndex
                )
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

    private func rowView(rowIndex: Int, row: [String], startingColumn: Int = 0, includesRowNumber: Bool = true) -> some View {
        HStack(spacing: 0) {
            if includesRowNumber {
                rowNumberCell(rowIndex)
            }

            ForEach(Array(row.enumerated().dropFirst(startingColumn)), id: \.offset) { columnIndex, value in
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
            .lineLimit(1)
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

    @ViewBuilder
    private func tableBody(_ tableDocument: DelimitedTableDocument) -> some View {
        let rows = visibleRows(in: tableDocument)
        if freezesFirstColumn, tableDocument.columnCount > 1 {
            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 0) {
                        HStack(spacing: 0) {
                            rowNumberHeader
                            headerCell(
                                text: tableDocument.headers[0],
                                type: tableDocument.columnTypes[0],
                                width: columnWidths[0],
                                columnIndex: 0
                            )
                        }
                        LazyVStack(spacing: 0) {
                            ForEach(rows, id: \.offset) { item in
                                HStack(spacing: 0) {
                                    rowNumberCell(item.offset)
                                    cell(text: item.row[0], width: columnWidths[0], isHeader: false)
                                }
                            }
                        }
                    }
                    .background(Color(nsColor: theme.backgroundColor))
                    .shadow(color: .black.opacity(0.12), radius: 3, x: 2, y: 0)
                    .zIndex(1)

                    ScrollView(.horizontal) {
                        VStack(alignment: .leading, spacing: 0) {
                            HStack(spacing: 0) {
                                ForEach(Array(tableDocument.headers.enumerated().dropFirst()), id: \.offset) { columnIndex, header in
                                    headerCell(
                                        text: header,
                                        type: tableDocument.columnTypes[columnIndex],
                                        width: columnWidths[columnIndex],
                                        columnIndex: columnIndex
                                    )
                                }
                            }
                            LazyVStack(spacing: 0) {
                                ForEach(rows, id: \.offset) { item in
                                    rowView(rowIndex: item.offset, row: item.row, startingColumn: 1, includesRowNumber: false)
                                }
                            }
                        }
                    }
                }
                .background(
                    StructuredScrollViewConfigurator(theme: theme, showsHorizontal: true, showsVertical: true)
                        .frame(width: 0, height: 0)
                )
            }
        } else {
            ScrollView([.horizontal, .vertical]) {
                VStack(alignment: .leading, spacing: 0) {
                    headerRow(tableDocument)
                    if rows.isEmpty {
                        emptyRowsView
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(rows, id: \.offset) { item in
                                rowView(rowIndex: item.offset, row: item.row)
                            }
                        }
                    }
                }
                .frame(minWidth: tableWidth, alignment: .topLeading)
                .background(
                    StructuredScrollViewConfigurator(theme: theme, showsHorizontal: true, showsVertical: true)
                        .frame(width: 0, height: 0)
                )
            }
        }
    }

    private func headerCell(
        text: String,
        type: DelimitedColumnType,
        width: CGFloat,
        columnIndex: Int
    ) -> some View {
        Button {
            let existing = sortDescriptors.first(where: { $0.columnIndex == columnIndex })
            setPrimarySort(columnIndex: columnIndex, ascending: !(existing?.isAscending ?? false))
        } label: {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(text)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .lineLimit(1)
                    if showsColumnTypes {
                        Text(type.displayName)
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(Color(nsColor: theme.secondaryTextColor))
                    }
                }
                Spacer(minLength: 0)
                if let sort = sortDescriptors.first(where: { $0.columnIndex == columnIndex }) {
                    Image(systemName: sort.isAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                    if let priority = sortDescriptors.firstIndex(where: { $0.columnIndex == columnIndex }), sortDescriptors.count > 1 {
                        Text("\(priority + 1)")
                            .font(.system(size: 8, weight: .bold))
                    }
                }
            }
            .foregroundStyle(Color(nsColor: theme.textColor))
            .frame(width: width, alignment: .leading)
            .padding(.horizontal, 12)
            .padding(.vertical, showsColumnTypes ? 5 : 10)
            .overlay(alignment: .trailing) {
                Rectangle().fill(Color(nsColor: theme.borderColor)).frame(width: 1)
            }
            .overlay(alignment: .bottom) {
                Rectangle().fill(Color(nsColor: theme.borderColor)).frame(height: 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Sort by \(text)")
    }

    private func rowNumberCell(_ rowIndex: Int) -> some View {
        Text("\(rowIndex + 1)")
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(Color(nsColor: theme.secondaryTextColor))
            .frame(width: 54, alignment: .trailing)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .lineLimit(1)
            .background(Color(nsColor: theme.gutterBackgroundColor).opacity(rowIndex.isMultiple(of: 2) ? 0.92 : 0.72))
    }

    private func visibleRows(in tableDocument: DelimitedTableDocument) -> [(offset: Int, row: [String])] {
        var rows = Array(tableDocument.rows.enumerated()).map { (offset: $0.offset, row: $0.element) }
        let query = filterText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !query.isEmpty {
            rows = rows.filter { item in
                item.row.contains { $0.localizedCaseInsensitiveContains(query) }
            }
        }
        return DelimitedTextTableService.sortedRows(
            rows,
            columnTypes: tableDocument.columnTypes,
            descriptors: sortDescriptors
        )
    }

    private func setPrimarySort(columnIndex: Int, ascending: Bool) {
        let remaining = sortDescriptors.filter { $0.columnIndex != columnIndex }
        sortDescriptors = [DelimitedSortDescriptor(columnIndex: columnIndex, isAscending: ascending)] + remaining
    }

    private func addSecondarySort(columnIndex: Int) {
        guard !sortDescriptors.contains(where: { $0.columnIndex == columnIndex }) else { return }
        sortDescriptors.append(DelimitedSortDescriptor(columnIndex: columnIndex, isAscending: true))
    }

    private func toggleAggregation(columnIndex: Int, kind: DelimitedAggregationKind) {
        let request = DelimitedAggregationRequest(columnIndex: columnIndex, kind: kind)
        if aggregationRequests.contains(request) {
            aggregationRequests.removeAll { $0 == request }
        } else {
            aggregationRequests.append(request)
        }
    }

    private func aggregationBar(_ tableDocument: DelimitedTableDocument) -> some View {
        let results = DelimitedTextTableService.aggregate(
            rows: visibleRows(in: tableDocument).map(\.row),
            headers: tableDocument.headers,
            columnTypes: tableDocument.columnTypes,
            requests: aggregationRequests
        )
        return ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Label("Visible rows", systemImage: "function")
                    .font(.system(size: 11, weight: .semibold))
                ForEach(results) { result in
                    summaryPill("\(result.columnName) \(result.kind.displayName.lowercased()): \(result.value)")
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 8)
        }
        .background(Color(nsColor: theme.gutterBackgroundColor).opacity(0.72))
    }

    private func copyVisibleRows(_ tableDocument: DelimitedTableDocument) {
        let text = DelimitedTextTableService.serialized(
            headers: tableDocument.headers,
            rows: visibleRows(in: tableDocument).map(\.row),
            delimiter: tableDocument.delimiter
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func exportVisibleRows(_ tableDocument: DelimitedTableDocument) {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(document.displayName)-filtered.csv"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            let text = DelimitedTextTableService.serialized(
                headers: tableDocument.headers,
                rows: visibleRows(in: tableDocument).map(\.row),
                delimiter: tableDocument.delimiter
            )
            try? Data(text.utf8).write(to: url, options: .atomic)
        }
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

private struct DelimitedSchemaEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var schema: [DelimitedColumnSchema]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Column Schema")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Names and types affect this table view only. Raw file contents remain unchanged.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }

            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach($schema) { $column in
                        HStack(spacing: 12) {
                            Text("\(column.columnIndex + 1)")
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .trailing)
                            TextField("Column name", text: $column.displayName)
                                .textFieldStyle(.roundedBorder)
                                .accessibilityLabel("Column \(column.columnIndex + 1) name")
                            Picker("Type", selection: $column.type) {
                                ForEach(DelimitedColumnType.allCases) { type in
                                    Text(type.displayName).tag(type)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 130)
                            .accessibilityLabel("Column \(column.columnIndex + 1) type")
                        }
                    }
                }
            }
        }
        .padding(20)
        .frame(minWidth: 560, minHeight: 360)
    }
}
