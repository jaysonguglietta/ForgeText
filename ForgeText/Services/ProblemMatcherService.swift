import Foundation

enum ProblemMatcherService {
    static func parseProblems(from output: String, source: String) -> [ProblemRecord] {
        let patterns: [(PluginDiagnosticSeverity, String)] = [
            (.error, #"(?m)^(.+?):(\d+):(?:(\d+):)?\s*error:\s*(.+)$"#),
            (.warning, #"(?m)^(.+?):(\d+):(?:(\d+):)?\s*warning:\s*(.+)$"#),
            (.info, #"(?m)^(.+?):(\d+):(?:(\d+):)?\s*note:\s*(.+)$"#),
            (.error, #"(?m)^(.+?)\((\d+),(\d+)\):\s*error\s*(.+)$"#),
            (.warning, #"(?m)^(.+?)\((\d+),(\d+)\):\s*warning\s*(.+)$"#),
        ]

        let nsOutput = output as NSString
        let fullRange = NSRange(location: 0, length: nsOutput.length)
        var records: [ProblemRecord] = []

        for (severity, pattern) in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }

            for match in regex.matches(in: output, range: fullRange) {
                guard match.numberOfRanges >= 5 else {
                    continue
                }

                let filePath = nsOutput.substring(with: match.range(at: 1))
                let lineNumber = Int(nsOutput.substring(with: match.range(at: 2)))
                let columnNumber = match.range(at: 3).location != NSNotFound ? Int(nsOutput.substring(with: match.range(at: 3))) : nil
                let message = nsOutput.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespacesAndNewlines)

                records.append(
                    ProblemRecord(
                        source: source,
                        severity: severity,
                        filePath: filePath,
                        lineNumber: lineNumber,
                        columnNumber: columnNumber,
                        message: message,
                        detail: nil
                    )
                )
            }
        }

        return deduplicated(records)
    }

    private static func deduplicated(_ records: [ProblemRecord]) -> [ProblemRecord] {
        var seen = Set<String>()
        return records.filter { record in
            let key = [record.source, record.filePath ?? "", record.lineNumber.map(String.init) ?? "", record.columnNumber.map(String.init) ?? "", record.message].joined(separator: "|")
            return seen.insert(key).inserted
        }
    }
}
