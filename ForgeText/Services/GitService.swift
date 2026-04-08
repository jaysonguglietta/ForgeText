import Foundation

enum GitService {
    enum GitError: LocalizedError {
        case repositoryNotFound
        case fileOutsideRepository
        case noCommittedVersion(String)
        case branchSwitchFailed(String)

        var errorDescription: String? {
            switch self {
            case .repositoryNotFound:
                return "ForgeText couldn’t locate a Git repository for the current workspace."
            case .fileOutsideRepository:
                return "The selected file is not inside the active Git repository."
            case let .noCommittedVersion(path):
                return "Git HEAD does not contain a committed version of \(path)."
            case let .branchSwitchFailed(branch):
                return "ForgeText couldn’t switch to the Git branch '\(branch)'."
            }
        }
    }

    static func summary(for location: URL?) -> GitRepositorySummary? {
        guard let rootURL = repositoryRoot(containing: location) else {
            return nil
        }

        guard let output = try? CommandExecutionService.runString(
            "/usr/bin/git",
            arguments: ["-C", rootURL.path, "status", "--short", "--branch"]
        ) else {
            return nil
        }

        return parseStatusOutput(output, rootURL: rootURL)
    }

    static func headContents(for fileURL: URL, workspaceRoot: URL?) throws -> String {
        guard let repositoryRoot = repositoryRoot(containing: workspaceRoot ?? fileURL.deletingLastPathComponent()) else {
            throw GitError.repositoryNotFound
        }

        let relativePath = try relativePath(for: fileURL, repositoryRoot: repositoryRoot)

        do {
            return try CommandExecutionService.runString(
                "/usr/bin/git",
                arguments: ["-C", repositoryRoot.path, "show", "HEAD:\(relativePath)"]
            )
        } catch {
            throw GitError.noCommittedVersion(relativePath)
        }
    }

    static func lineDecorations(for fileURL: URL, workspaceRoot: URL?) -> [EditorLineDecoration] {
        guard let repositoryRoot = repositoryRoot(containing: workspaceRoot ?? fileURL.deletingLastPathComponent()),
              let relativePath = try? relativePath(for: fileURL, repositoryRoot: repositoryRoot)
        else {
            return []
        }

        var decorations: [Int: EditorLineDecoration] = [:]

        let diffVariants: [[String]] = [
            ["-C", repositoryRoot.path, "diff", "--unified=0", "--", relativePath],
            ["-C", repositoryRoot.path, "diff", "--cached", "--unified=0", "--", relativePath],
        ]

        for arguments in diffVariants {
            guard let output = try? CommandExecutionService.runString("/usr/bin/git", arguments: arguments) else {
                continue
            }

            for decoration in parseUnifiedDiff(output) {
                decorations[decoration.lineNumber] = decoration
            }
        }

        return decorations.values.sorted { $0.lineNumber < $1.lineNumber }
    }

    static func blame(for fileURL: URL, lineNumber: Int, workspaceRoot: URL?) -> GitBlameInfo? {
        guard lineNumber > 0,
              let repositoryRoot = repositoryRoot(containing: workspaceRoot ?? fileURL.deletingLastPathComponent()),
              let relativePath = try? relativePath(for: fileURL, repositoryRoot: repositoryRoot),
              let output = try? CommandExecutionService.runString(
                  "/usr/bin/git",
                  arguments: ["-C", repositoryRoot.path, "blame", "--porcelain", "-L", "\(lineNumber),\(lineNumber)", "--", relativePath]
              )
        else {
            return nil
        }

        let lines = output.split(whereSeparator: \.isNewline).map(String.init)
        guard let header = lines.first else {
            return nil
        }

        let commitHash = header.split(separator: " ").first.map(String.init) ?? "HEAD"
        let author = lines.first(where: { $0.hasPrefix("author ") }).map { String($0.dropFirst("author ".count)) } ?? "Unknown"
        let summary = lines.first(where: { $0.hasPrefix("summary ") }).map { String($0.dropFirst("summary ".count)) } ?? "Uncommitted change"
        let authoredAt: Date? = lines
            .first(where: { $0.hasPrefix("author-time ") })
            .flatMap { line in
                let value = line.dropFirst("author-time ".count)
                guard let timestamp = TimeInterval(value) else {
                    return nil
                }

                return Date(timeIntervalSince1970: timestamp)
            }

        return GitBlameInfo(
            commitHash: commitHash,
            author: author,
            summary: summary,
            authoredAt: authoredAt
        )
    }

    static func branches(for location: URL?) -> [String] {
        guard let repositoryRoot = repositoryRoot(containing: location) else {
            return []
        }

        guard let output = try? CommandExecutionService.runString(
            "/usr/bin/git",
            arguments: ["-C", repositoryRoot.path, "branch", "--format=%(refname:short)"]
        ) else {
            return []
        }

        return output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .sorted()
    }

    static func checkout(branch: String, at location: URL?) throws {
        guard let repositoryRoot = repositoryRoot(containing: location) else {
            throw GitError.repositoryNotFound
        }

        do {
            _ = try CommandExecutionService.runString(
                "/usr/bin/git",
                arguments: ["-C", repositoryRoot.path, "checkout", branch]
            )
        } catch {
            throw GitError.branchSwitchFailed(branch)
        }
    }

    static func stage(fileURL: URL, workspaceRoot: URL?) throws {
        guard let repositoryRoot = repositoryRoot(containing: workspaceRoot ?? fileURL.deletingLastPathComponent()) else {
            throw GitError.repositoryNotFound
        }

        let relativePath = try relativePath(for: fileURL, repositoryRoot: repositoryRoot)
        _ = try CommandExecutionService.runString(
            "/usr/bin/git",
            arguments: ["-C", repositoryRoot.path, "add", "--", relativePath]
        )
    }

    private static func repositoryRoot(containing location: URL?) -> URL? {
        guard let location else {
            return nil
        }

        let directory = location.hasDirectoryPath ? location : location.deletingLastPathComponent()

        guard let output = try? CommandExecutionService.runString(
            "/usr/bin/git",
            arguments: ["-C", directory.path, "rev-parse", "--show-toplevel"]
        ) else {
            return nil
        }

        let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !path.isEmpty else {
            return nil
        }

        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private static func relativePath(for fileURL: URL, repositoryRoot: URL) throws -> String {
        let filePath = fileURL.standardizedFileURL.path
        let rootPath = repositoryRoot.standardizedFileURL.path
        guard filePath.hasPrefix(rootPath) else {
            throw GitError.fileOutsideRepository
        }

        let relativePath = String(filePath.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !relativePath.isEmpty else {
            throw GitError.fileOutsideRepository
        }

        return relativePath
    }

    private static func parseStatusOutput(_ output: String, rootURL: URL) -> GitRepositorySummary {
        let lines = output.split(whereSeparator: \.isNewline).map(String.init)
        let branchLine = lines.first(where: { $0.hasPrefix("## ") }) ?? "## HEAD"
        let branchName = branchLine
            .replacingOccurrences(of: "## ", with: "")
            .split(separator: ".")
            .first
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "HEAD"

        var stagedCount = 0
        var modifiedCount = 0
        var untrackedCount = 0
        var conflictedCount = 0

        for line in lines where !line.hasPrefix("## ") {
            guard line.count >= 2 else {
                continue
            }

            let characters = Array(line)
            let indexStatus = characters[0]
            let workTreeStatus = characters[1]

            if indexStatus == "?" && workTreeStatus == "?" {
                untrackedCount += 1
                continue
            }

            if indexStatus == "U" || workTreeStatus == "U" {
                conflictedCount += 1
            }

            if indexStatus != " " && indexStatus != "?" {
                stagedCount += 1
            }

            if workTreeStatus != " " && workTreeStatus != "?" {
                modifiedCount += 1
            }
        }

        return GitRepositorySummary(
            rootURL: rootURL,
            branchName: branchName,
            stagedCount: stagedCount,
            modifiedCount: modifiedCount,
            untrackedCount: untrackedCount,
            conflictedCount: conflictedCount
        )
    }

    private static func parseUnifiedDiff(_ output: String) -> [EditorLineDecoration] {
        let pattern = #"@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return []
        }

        let nsOutput = output as NSString
        let range = NSRange(location: 0, length: nsOutput.length)

        return regex.matches(in: output, range: range).flatMap { match in
            guard match.numberOfRanges >= 5 else {
                return [EditorLineDecoration]()
            }

            let minusCount = match.range(at: 2).location != NSNotFound ? Int(nsOutput.substring(with: match.range(at: 2))) ?? 1 : 1
            let plusStart = Int(nsOutput.substring(with: match.range(at: 3))) ?? 0
            let plusCount = match.range(at: 4).location != NSNotFound ? Int(nsOutput.substring(with: match.range(at: 4))) ?? 1 : 1

            if plusCount == 0 {
                return [
                    EditorLineDecoration(
                        lineNumber: plusStart,
                        kind: .gitChanged,
                        message: "Deleted line nearby"
                    ),
                ]
            }

            let kind: EditorLineDecorationKind = minusCount == 0 ? .gitAdded : .gitChanged
            return (plusStart..<(plusStart + plusCount)).map { lineNumber in
                EditorLineDecoration(
                    lineNumber: lineNumber,
                    kind: kind,
                    message: kind == .gitAdded ? "Added in working tree" : "Modified in working tree"
                )
            }
        }
    }
}
