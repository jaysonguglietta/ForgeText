import Foundation

enum GitConflictService {
    static func sections(from fileURL: URL) -> [GitConflictSection] {
        guard let text = try? String(contentsOf: fileURL) else {
            return []
        }

        let lines = text.components(separatedBy: .newlines)
        var sections: [GitConflictSection] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            guard line.hasPrefix("<<<<<<< ") else {
                index += 1
                continue
            }

            let currentLabel = String(line.dropFirst("<<<<<<< ".count))
            index += 1

            var currentLines: [String] = []
            while index < lines.count, !lines[index].hasPrefix("||||||| "), !lines[index].hasPrefix("=======") {
                currentLines.append(lines[index])
                index += 1
            }

            var baseLines: [String] = []
            if index < lines.count, lines[index].hasPrefix("||||||| ") {
                index += 1
                while index < lines.count, !lines[index].hasPrefix("=======") {
                    baseLines.append(lines[index])
                    index += 1
                }
            }

            guard index < lines.count, lines[index].hasPrefix("=======") else {
                break
            }
            index += 1

            var incomingLines: [String] = []
            while index < lines.count, !lines[index].hasPrefix(">>>>>>> ") {
                incomingLines.append(lines[index])
                index += 1
            }

            let incomingLabel: String
            if index < lines.count, lines[index].hasPrefix(">>>>>>> ") {
                incomingLabel = String(lines[index].dropFirst(">>>>>>> ".count))
                index += 1
            } else {
                incomingLabel = "Incoming"
            }

            sections.append(
                GitConflictSection(
                    heading: "Conflict \(sections.count + 1)",
                    currentLabel: currentLabel,
                    currentText: currentLines.joined(separator: "\n"),
                    baseText: baseLines.isEmpty ? nil : baseLines.joined(separator: "\n"),
                    incomingLabel: incomingLabel,
                    incomingText: incomingLines.joined(separator: "\n")
                )
            )
        }

        return sections
    }

    static func resolveAllConflicts(in text: String, strategy: GitConflictResolutionStrategy) -> String {
        let lines = text.components(separatedBy: .newlines)
        var resolved: [String] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            guard line.hasPrefix("<<<<<<< ") else {
                resolved.append(line)
                index += 1
                continue
            }

            index += 1
            var currentLines: [String] = []
            while index < lines.count, !lines[index].hasPrefix("||||||| "), !lines[index].hasPrefix("=======") {
                currentLines.append(lines[index])
                index += 1
            }

            if index < lines.count, lines[index].hasPrefix("||||||| ") {
                index += 1
                while index < lines.count, !lines[index].hasPrefix("=======") {
                    index += 1
                }
            }

            guard index < lines.count, lines[index].hasPrefix("=======") else {
                break
            }
            index += 1

            var incomingLines: [String] = []
            while index < lines.count, !lines[index].hasPrefix(">>>>>>> ") {
                incomingLines.append(lines[index])
                index += 1
            }

            if index < lines.count, lines[index].hasPrefix(">>>>>>> ") {
                index += 1
            }

            switch strategy {
            case .current:
                resolved.append(contentsOf: currentLines)
            case .incoming:
                resolved.append(contentsOf: incomingLines)
            case .both:
                resolved.append(contentsOf: currentLines)
                resolved.append(contentsOf: incomingLines)
            }
        }

        return resolved.joined(separator: "\n")
    }
}
