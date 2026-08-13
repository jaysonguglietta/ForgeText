import Foundation

enum DelimitedColumnType: String, Codable, Hashable, CaseIterable, Identifiable {
    case boolean
    case integer
    case decimal
    case date
    case text
    case empty

    var id: String { rawValue }

    var displayName: String {
        rawValue.capitalized
    }
}

struct DelimitedSortDescriptor: Codable, Hashable, Identifiable {
    var id: Int { columnIndex }
    let columnIndex: Int
    var isAscending: Bool
}

struct DelimitedColumnSchema: Codable, Hashable, Identifiable {
    var id: Int { columnIndex }
    let columnIndex: Int
    var displayName: String
    var type: DelimitedColumnType
}

enum DelimitedAggregationKind: String, Codable, Hashable, CaseIterable, Identifiable {
    case count
    case sum
    case average
    case minimum
    case maximum

    var id: String { rawValue }
    var displayName: String { rawValue.capitalized }
}

struct DelimitedAggregationResult: Hashable, Identifiable {
    var id: String { "\(columnIndex)-\(kind.rawValue)" }
    let columnIndex: Int
    let columnName: String
    let kind: DelimitedAggregationKind
    let value: String
}

struct DelimitedAggregationRequest: Codable, Hashable, Identifiable {
    var id: String { "\(columnIndex)-\(kind.rawValue)" }
    let columnIndex: Int
    let kind: DelimitedAggregationKind
}

struct DelimitedTableDocument {
    let delimiter: Character
    let headers: [String]
    let rows: [[String]]
    let hasHeaderRow: Bool
    let columnTypes: [DelimitedColumnType]

    var columnCount: Int {
        headers.count
    }

    var rowCount: Int {
        rows.count
    }

    var delimiterLabel: String {
        switch delimiter {
        case ",":
            return "Comma"
        case "\t":
            return "Tab"
        case ";":
            return "Semicolon"
        case "|":
            return "Pipe"
        default:
            return String(delimiter)
        }
    }
}

enum DelimitedTextTableService {
    static let maximumInteractiveRows = 250_000

    static func parse(_ text: String, preferredDelimiter: Character? = nil) -> DelimitedTableDocument? {
        let candidates: [Character]
        if let preferredDelimiter {
            candidates = [preferredDelimiter]
        } else {
            candidates = [",", "\t", ";", "|"]
        }

        let bestCandidate = candidates
            .compactMap { delimiter -> (Character, [[String]], Int)? in
                guard let parsedRows = parseRows(text, delimiter: delimiter) else {
                    return nil
                }

                let rows = removingSeparatorDirective(from: parsedRows, delimiter: delimiter)
                let score = score(rows: rows, allowsSingleRow: preferredDelimiter == delimiter)
                guard score > 0 else {
                    return nil
                }

                return (delimiter, rows, score)
            }
            .max { lhs, rhs in
                lhs.2 < rhs.2
            }

        guard let (delimiter, rawRows, _) = bestCandidate else {
            return nil
        }

        let normalizedRows = normalize(rows: rawRows)
        guard let firstRow = normalizedRows.first, firstRow.count > 1 else {
            return nil
        }

        let hasHeaderRow = inferHeaderRow(in: normalizedRows)
        let headers = hasHeaderRow ? firstRow.map(cleanHeaderCell) : generatedHeaders(count: firstRow.count)
        let rows = hasHeaderRow ? Array(normalizedRows.dropFirst()) : normalizedRows

        return DelimitedTableDocument(
            delimiter: delimiter,
            headers: headers,
            rows: rows,
            hasHeaderRow: hasHeaderRow,
            columnTypes: inferColumnTypes(rows: rows, columnCount: headers.count)
        )
    }

    static func serialized(
        headers: [String],
        rows: [[String]],
        delimiter: Character,
        includesHeader: Bool = true
    ) -> String {
        let outputRows = (includesHeader ? [headers] : []) + rows
        return outputRows.map { row in
            row.map { escaped($0, delimiter: delimiter) }.joined(separator: String(delimiter))
        }.joined(separator: "\n") + "\n"
    }

    static func applying(
        schema: [DelimitedColumnSchema],
        to document: DelimitedTableDocument
    ) -> DelimitedTableDocument {
        let byColumn = Dictionary(uniqueKeysWithValues: schema.map { ($0.columnIndex, $0) })
        let headers = document.headers.enumerated().map { index, original in
            let name = byColumn[index]?.displayName.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return name.isEmpty ? original : name
        }
        let types = document.columnTypes.enumerated().map { index, original in
            byColumn[index]?.type ?? original
        }
        return DelimitedTableDocument(
            delimiter: document.delimiter,
            headers: headers,
            rows: document.rows,
            hasHeaderRow: document.hasHeaderRow,
            columnTypes: types
        )
    }

    static func sortedRows(
        _ rows: [(offset: Int, row: [String])],
        columnTypes: [DelimitedColumnType],
        descriptors: [DelimitedSortDescriptor]
    ) -> [(offset: Int, row: [String])] {
        let validDescriptors = descriptors.prefix(8).filter {
            columnTypes.indices.contains($0.columnIndex)
        }
        guard !validDescriptors.isEmpty else { return rows }

        return rows.sorted { lhs, rhs in
            for descriptor in validDescriptors {
                guard lhs.row.indices.contains(descriptor.columnIndex),
                      rhs.row.indices.contains(descriptor.columnIndex)
                else { continue }
                let comparison = compare(
                    lhs.row[descriptor.columnIndex],
                    rhs.row[descriptor.columnIndex],
                    type: columnTypes[descriptor.columnIndex]
                )
                guard comparison != .orderedSame else { continue }
                return descriptor.isAscending
                    ? comparison == .orderedAscending
                    : comparison == .orderedDescending
            }
            return lhs.offset < rhs.offset
        }
    }

    static func aggregate(
        rows: [[String]],
        headers: [String],
        columnTypes: [DelimitedColumnType],
        requests: [DelimitedAggregationRequest]
    ) -> [DelimitedAggregationResult] {
        requests.prefix(24).compactMap { request in
            guard headers.indices.contains(request.columnIndex),
                  columnTypes.indices.contains(request.columnIndex)
            else { return nil }
            let values = rows.prefix(maximumInteractiveRows).compactMap { row -> Double? in
                guard row.indices.contains(request.columnIndex) else { return nil }
                return numericValue(row[request.columnIndex], type: columnTypes[request.columnIndex])
            }
            let rendered: String
            switch request.kind {
            case .count:
                let count = rows.prefix(maximumInteractiveRows).filter {
                    $0.indices.contains(request.columnIndex) && !$0[request.columnIndex].isEmpty
                }.count
                rendered = String(count)
            case .sum:
                guard !values.isEmpty else { return nil }
                rendered = formatNumber(values.reduce(0, +))
            case .average:
                guard !values.isEmpty else { return nil }
                rendered = formatNumber(values.reduce(0, +) / Double(values.count))
            case .minimum:
                guard let value = values.min() else { return nil }
                rendered = formatNumber(value)
            case .maximum:
                guard let value = values.max() else { return nil }
                rendered = formatNumber(value)
            }
            return DelimitedAggregationResult(
                columnIndex: request.columnIndex,
                columnName: headers[request.columnIndex],
                kind: request.kind,
                value: rendered
            )
        }
    }

    private static func parseRows(_ text: String, delimiter: Character) -> [[String]]? {
        var rows: [[String]] = []
        var currentRow: [String] = []
        var currentField = ""
        var insideQuotes = false
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]

            if insideQuotes {
                if character == "\"" {
                    let nextIndex = text.index(after: index)
                    if nextIndex < text.endIndex, text[nextIndex] == "\"" {
                        currentField.append("\"")
                        index = text.index(after: nextIndex)
                        continue
                    }

                    insideQuotes = false
                    index = text.index(after: index)
                    continue
                }

                currentField.append(character)
                index = text.index(after: index)
                continue
            }

            switch character {
            case "\"":
                insideQuotes = true
            case delimiter:
                currentRow.append(currentField)
                currentField = ""
            case "\n":
                currentRow.append(currentField)
                rows.append(currentRow)
                currentRow = []
                currentField = ""
            case "\r":
                currentRow.append(currentField)
                rows.append(currentRow)
                currentRow = []
                currentField = ""

                let nextIndex = text.index(after: index)
                if nextIndex < text.endIndex, text[nextIndex] == "\n" {
                    index = nextIndex
                }
            default:
                currentField.append(character)
            }

            index = text.index(after: index)
        }

        guard !insideQuotes else {
            return nil
        }

        if !currentField.isEmpty || !currentRow.isEmpty {
            currentRow.append(currentField)
            rows.append(currentRow)
        }

        return rows
            .map { $0.map { $0.trimmingCharacters(in: .newlines) } }
            .filter { row in
                row.contains { !$0.isEmpty }
            }
    }

    private static func score(rows: [[String]], allowsSingleRow: Bool = false) -> Int {
        let sampledRows = Array(rows.prefix(25))
        let candidateWidths = sampledRows.map(\.count).filter { $0 > 1 }
        guard candidateWidths.count >= 2 else {
            if allowsSingleRow, let firstWidth = candidateWidths.first {
                return firstWidth * 100
            }

            return 0
        }

        let widthFrequencies = Dictionary(candidateWidths.map { ($0, 1) }, uniquingKeysWith: +)
        guard let dominantWidth = widthFrequencies.max(by: { $0.value < $1.value })?.key else {
            return 0
        }

        let consistency = candidateWidths.filter { $0 == dominantWidth }.count
        guard dominantWidth > 1, consistency >= 2 else {
            return 0
        }

        return (dominantWidth * 100) + (consistency * 25) - sampledRows.count
    }

    private static func removingSeparatorDirective(from rows: [[String]], delimiter: Character) -> [[String]] {
        guard let firstRow = rows.first, !firstRow.isEmpty else {
            return rows
        }

        let trimmedCells = firstRow.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        guard let firstCell = trimmedCells.first?.lowercased() else {
            return rows
        }

        let trailingCellsAreEmpty = trimmedCells.dropFirst().allSatisfy(\.isEmpty)
        let declaresSeparator = firstCell == "sep="
            || firstCell == "sep=\(delimiter)"
            || firstCell == "separator=\(delimiter)"

        guard declaresSeparator, trailingCellsAreEmpty else {
            return rows
        }

        return Array(rows.dropFirst())
    }

    private static func normalize(rows: [[String]]) -> [[String]] {
        let maxColumnCount = rows.map(\.count).max() ?? 0
        return rows.map { row in
            if row.count == maxColumnCount {
                return row
            }

            return row + Array(repeating: "", count: maxColumnCount - row.count)
        }
    }

    private static func inferHeaderRow(in rows: [[String]]) -> Bool {
        guard rows.count >= 2 else {
            return false
        }

        let firstRow = rows[0].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        let secondRow = rows[1].map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }

        let nonEmptyHeaders = firstRow.filter { !$0.isEmpty }
        let uniqueHeaders = Set(nonEmptyHeaders.map { $0.lowercased() }).count == nonEmptyHeaders.count
        let firstRowLooksLabelLike = nonEmptyHeaders.filter { containsAlphabeticCharacter($0) && !looksNumeric($0) }.count
        let secondRowLooksLabelLike = secondRow.filter { containsAlphabeticCharacter($0) && !looksNumeric($0) }.count

        return uniqueHeaders && firstRowLooksLabelLike >= max(1, secondRowLooksLabelLike)
    }

    private static func generatedHeaders(count: Int) -> [String] {
        (1...count).map { "Column \($0)" }
    }

    private static func cleanHeaderCell(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Untitled" : trimmed
    }

    private static func inferColumnTypes(rows: [[String]], columnCount: Int) -> [DelimitedColumnType] {
        (0..<columnCount).map { columnIndex in
            let values = rows.prefix(500).compactMap { row -> String? in
                guard row.indices.contains(columnIndex) else { return nil }
                let value = row[columnIndex].trimmingCharacters(in: .whitespacesAndNewlines)
                return value.isEmpty ? nil : value
            }
            guard !values.isEmpty else { return .empty }
            if values.allSatisfy({ ["true", "false", "yes", "no"].contains($0.lowercased()) }) {
                return .boolean
            }
            if values.allSatisfy({ Int64($0) != nil }) {
                return .integer
            }
            if values.allSatisfy({ Double($0.replacingOccurrences(of: ",", with: "")) != nil }) {
                return .decimal
            }
            if values.allSatisfy({ ISO8601DateFormatter().date(from: $0) != nil }) {
                return .date
            }
            return .text
        }
    }

    private static func compare(_ lhs: String, _ rhs: String, type: DelimitedColumnType) -> ComparisonResult {
        if let left = numericValue(lhs, type: type), let right = numericValue(rhs, type: type) {
            if left < right { return .orderedAscending }
            if left > right { return .orderedDescending }
            return .orderedSame
        }
        if type == .date {
            let formatter = ISO8601DateFormatter()
            if let left = formatter.date(from: lhs), let right = formatter.date(from: rhs) {
                return left.compare(right)
            }
        }
        return lhs.localizedStandardCompare(rhs)
    }

    private static func numericValue(_ value: String, type: DelimitedColumnType) -> Double? {
        switch type {
        case .integer, .decimal:
            return Double(value.replacingOccurrences(of: ",", with: ""))
        default:
            return nil
        }
    }

    private static func formatNumber(_ value: Double) -> String {
        value.rounded() == value ? String(format: "%.0f", value) : String(format: "%.3f", value)
    }

    private static func escaped(_ value: String, delimiter: Character) -> String {
        guard value.contains(delimiter) || value.contains("\"") || value.contains("\n") || value.contains("\r") else {
            return value
        }
        return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
    }

    private static func containsAlphabeticCharacter(_ value: String) -> Bool {
        value.unicodeScalars.contains { CharacterSet.letters.contains($0) }
    }

    private static func looksNumeric(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return false
        }

        let allowedCharacters = CharacterSet(charactersIn: "-+0123456789.,%$")
        return trimmed.unicodeScalars.allSatisfy { allowedCharacters.contains($0) }
    }
}
