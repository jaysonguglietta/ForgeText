import Foundation

enum DocumentComparisonService {
    static func compare(left: String, right: String) -> [DiffLine] {
        let leftLines = splitIntoLines(left)
        let rightLines = splitIntoLines(right)

        if leftLines.count * rightLines.count > 120_000 {
            return fallbackCompare(leftLines: leftLines, rightLines: rightLines)
        }

        let table = longestCommonSubsequenceTable(left: leftLines, right: rightLines)
        var lines: [DiffLine] = []
        var leftIndex = 0
        var rightIndex = 0
        var leftLineNumber = 1
        var rightLineNumber = 1

        while leftIndex < leftLines.count, rightIndex < rightLines.count {
            if leftLines[leftIndex] == rightLines[rightIndex] {
                lines.append(
                    DiffLine(
                        kind: .unchanged,
                        leftLineNumber: leftLineNumber,
                        rightLineNumber: rightLineNumber,
                        leftText: leftLines[leftIndex],
                        rightText: rightLines[rightIndex]
                    )
                )
                leftIndex += 1
                rightIndex += 1
                leftLineNumber += 1
                rightLineNumber += 1
            } else if table[leftIndex + 1][rightIndex] >= table[leftIndex][rightIndex + 1] {
                lines.append(
                    DiffLine(
                        kind: .deleted,
                        leftLineNumber: leftLineNumber,
                        rightLineNumber: nil,
                        leftText: leftLines[leftIndex],
                        rightText: nil
                    )
                )
                leftIndex += 1
                leftLineNumber += 1
            } else {
                lines.append(
                    DiffLine(
                        kind: .inserted,
                        leftLineNumber: nil,
                        rightLineNumber: rightLineNumber,
                        leftText: nil,
                        rightText: rightLines[rightIndex]
                    )
                )
                rightIndex += 1
                rightLineNumber += 1
            }
        }

        while leftIndex < leftLines.count {
            lines.append(
                DiffLine(
                    kind: .deleted,
                    leftLineNumber: leftLineNumber,
                    rightLineNumber: nil,
                    leftText: leftLines[leftIndex],
                    rightText: nil
                )
            )
            leftIndex += 1
            leftLineNumber += 1
        }

        while rightIndex < rightLines.count {
            lines.append(
                DiffLine(
                    kind: .inserted,
                    leftLineNumber: nil,
                    rightLineNumber: rightLineNumber,
                    leftText: nil,
                    rightText: rightLines[rightIndex]
                )
            )
            rightIndex += 1
            rightLineNumber += 1
        }

        return lines
    }

    private static func splitIntoLines(_ text: String) -> [String] {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")
    }

    private static func longestCommonSubsequenceTable(left: [String], right: [String]) -> [[Int]] {
        var table = Array(repeating: Array(repeating: 0, count: right.count + 1), count: left.count + 1)

        guard !left.isEmpty, !right.isEmpty else {
            return table
        }

        for leftIndex in stride(from: left.count - 1, through: 0, by: -1) {
            for rightIndex in stride(from: right.count - 1, through: 0, by: -1) {
                if left[leftIndex] == right[rightIndex] {
                    table[leftIndex][rightIndex] = table[leftIndex + 1][rightIndex + 1] + 1
                } else {
                    table[leftIndex][rightIndex] = max(table[leftIndex + 1][rightIndex], table[leftIndex][rightIndex + 1])
                }
            }
        }

        return table
    }

    private static func fallbackCompare(leftLines: [String], rightLines: [String]) -> [DiffLine] {
        let count = max(leftLines.count, rightLines.count)

        return (0..<count).map { index in
            let left = leftLines.indices.contains(index) ? leftLines[index] : nil
            let right = rightLines.indices.contains(index) ? rightLines[index] : nil
            let kind: DiffLineKind = {
                if left == right {
                    return .unchanged
                }

                if left == nil {
                    return .inserted
                }

                if right == nil {
                    return .deleted
                }

                return .deleted
            }()

            return DiffLine(
                kind: kind,
                leftLineNumber: left.map { _ in index + 1 },
                rightLineNumber: right.map { _ in index + 1 },
                leftText: left,
                rightText: right
            )
        }
    }
}
