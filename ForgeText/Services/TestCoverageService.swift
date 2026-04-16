import Foundation

enum TestCoverageService {
    static func summary(from output: String) -> TestCoverageSummary? {
        let lines = output.split(whereSeparator: \.isNewline).map(String.init)

        let patterns: [(String, String)] = [
            ("TOTAL\\s+\\d+\\s+\\d+\\s+(\\d+(?:\\.\\d+)?)%", "pytest-cov"),
            ("Lines:\\s*(\\d+(?:\\.\\d+)?)%", "coverage"),
            ("Coverage:\\s*(\\d+(?:\\.\\d+)?)%", "coverage"),
            ("test coverage\\s*:\\s*(\\d+(?:\\.\\d+)?)%", "test runner"),
        ]

        for line in lines {
            for (pattern, toolName) in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                    continue
                }

                let nsLine = line as NSString
                let range = NSRange(location: 0, length: nsLine.length)
                guard let match = regex.firstMatch(in: line, options: [], range: range),
                      match.numberOfRanges > 1
                else {
                    continue
                }

                let valueRange = match.range(at: 1)
                let valueString = nsLine.substring(with: valueRange)
                guard let percentage = Double(valueString) else {
                    continue
                }

                return TestCoverageSummary(toolName: toolName, percentage: percentage, detail: line)
            }
        }

        return nil
    }
}
