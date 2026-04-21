import Foundation

struct DelimitedTableDocument {
    let delimiter: Character
    let headers: [String]
    let rows: [[String]]
    let hasHeaderRow: Bool

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
            hasHeaderRow: hasHeaderRow
        )
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
