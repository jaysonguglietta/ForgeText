import Foundation

enum GitService {
    struct GitWorkspaceSnapshot {
        let summary: GitRepositorySummary?
        let branches: [String]
        let changedFiles: [GitChangedFile]
        let stashes: [GitStashEntry]

        static let empty = GitWorkspaceSnapshot(
            summary: nil,
            branches: [],
            changedFiles: [],
            stashes: []
        )
    }

    enum GitError: LocalizedError {
        case repositoryNotFound
        case fileOutsideRepository
        case noCommittedVersion(String)
        case branchSwitchFailed(String)
        case commitMessageRequired
        case branchNameRequired

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
            case .commitMessageRequired:
                return "Enter a commit message before committing changes."
            case .branchNameRequired:
                return "Enter a branch name before creating a branch."
            }
        }
    }

    static func summary(for location: URL?) -> GitRepositorySummary? {
        guard let rootURL = repositoryRoot(containing: location) else {
            return nil
        }

        return summary(repositoryRoot: rootURL)
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

        return branches(repositoryRoot: repositoryRoot)
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

    static func unstage(fileURL: URL, workspaceRoot: URL?) throws {
        guard let repositoryRoot = repositoryRoot(containing: workspaceRoot ?? fileURL.deletingLastPathComponent()) else {
            throw GitError.repositoryNotFound
        }

        let relativePath = try relativePath(for: fileURL, repositoryRoot: repositoryRoot)
        _ = try CommandExecutionService.runString(
            "/usr/bin/git",
            arguments: ["-C", repositoryRoot.path, "restore", "--staged", "--", relativePath]
        )
    }

    static func changedFiles(for location: URL?) -> [GitChangedFile] {
        guard let repositoryRoot = repositoryRoot(containing: location) else {
            return []
        }

        return changedFiles(repositoryRoot: repositoryRoot)
    }

    static func stashes(for location: URL?) -> [GitStashEntry] {
        guard let repositoryRoot = repositoryRoot(containing: location) else {
            return []
        }

        return stashes(repositoryRoot: repositoryRoot)
    }

    static func snapshot(for location: URL?) -> GitWorkspaceSnapshot {
        guard let repositoryRoot = repositoryRoot(containing: location) else {
            return .empty
        }

        return GitWorkspaceSnapshot(
            summary: summary(repositoryRoot: repositoryRoot),
            branches: branches(repositoryRoot: repositoryRoot),
            changedFiles: changedFiles(repositoryRoot: repositoryRoot),
            stashes: stashes(repositoryRoot: repositoryRoot)
        )
    }

    static func fetch(at location: URL?) throws {
        guard let repositoryRoot = repositoryRoot(containing: location) else {
            throw GitError.repositoryNotFound
        }

        _ = try CommandExecutionService.runString(
            "/usr/bin/git",
            arguments: ["-C", repositoryRoot.path, "fetch", "--all", "--prune"]
        )
    }

    static func pull(at location: URL?) throws {
        guard let repositoryRoot = repositoryRoot(containing: location) else {
            throw GitError.repositoryNotFound
        }

        _ = try CommandExecutionService.runString(
            "/usr/bin/git",
            arguments: ["-C", repositoryRoot.path, "pull", "--ff-only"]
        )
    }

    static func push(at location: URL?) throws {
        guard let repositoryRoot = repositoryRoot(containing: location) else {
            throw GitError.repositoryNotFound
        }

        _ = try CommandExecutionService.runString(
            "/usr/bin/git",
            arguments: ["-C", repositoryRoot.path, "push"]
        )
    }

    static func commit(message: String, at location: URL?) throws {
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedMessage.isEmpty else {
            throw GitError.commitMessageRequired
        }
        guard let repositoryRoot = repositoryRoot(containing: location) else {
            throw GitError.repositoryNotFound
        }

        _ = try CommandExecutionService.runString(
            "/usr/bin/git",
            arguments: ["-C", repositoryRoot.path, "commit", "-m", trimmedMessage]
        )
    }

    static func createBranch(named branch: String, at location: URL?) throws {
        let trimmedBranch = branch.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedBranch.isEmpty else {
            throw GitError.branchNameRequired
        }
        guard let repositoryRoot = repositoryRoot(containing: location) else {
            throw GitError.repositoryNotFound
        }

        _ = try CommandExecutionService.runString(
            "/usr/bin/git",
            arguments: ["-C", repositoryRoot.path, "checkout", "-b", trimmedBranch]
        )
    }

    static func stashSave(message: String, at location: URL?) throws {
        guard let repositoryRoot = repositoryRoot(containing: location) else {
            throw GitError.repositoryNotFound
        }

        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)
        var arguments = ["-C", repositoryRoot.path, "stash", "push", "-u"]
        if !trimmedMessage.isEmpty {
            arguments += ["-m", trimmedMessage]
        }

        _ = try CommandExecutionService.runString("/usr/bin/git", arguments: arguments)
    }

    static func stashPop(_ stashID: String?, at location: URL?) throws {
        guard let repositoryRoot = repositoryRoot(containing: location) else {
            throw GitError.repositoryNotFound
        }

        var arguments = ["-C", repositoryRoot.path, "stash", "pop"]
        if let stashID, !stashID.isEmpty {
            arguments.append(stashID)
        }

        _ = try CommandExecutionService.runString("/usr/bin/git", arguments: arguments)
    }

    static func diffForWorkingTree(at location: URL?) throws -> String {
        guard let repositoryRoot = repositoryRoot(containing: location) else {
            throw GitError.repositoryNotFound
        }

        return try CommandExecutionService.runString(
            "/usr/bin/git",
            arguments: ["-C", repositoryRoot.path, "diff", "--cached", "--stat", "--patch"]
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

    private static func summary(repositoryRoot: URL) -> GitRepositorySummary? {
        guard let output = try? CommandExecutionService.runString(
            "/usr/bin/git",
            arguments: ["-C", repositoryRoot.path, "status", "--short", "--branch"]
        ) else {
            return nil
        }

        return parseStatusOutput(output, rootURL: repositoryRoot)
    }

    private static func branches(repositoryRoot: URL) -> [String] {
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

    private static func changedFiles(repositoryRoot: URL) -> [GitChangedFile] {
        guard let output = try? CommandExecutionService.runString(
            "/usr/bin/git",
            arguments: ["-C", repositoryRoot.path, "status", "--porcelain=v1"]
        ) else {
            return []
        }

        return output
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                let value = String(line)
                guard value.count >= 3 else {
                    return nil
                }

                let characters = Array(value)
                let indexStatus = String(characters[0])
                let workTreeStatus = String(characters[1])
                let rawPath = String(value.dropFirst(3))
                let resolvedPath = rawPath.contains(" -> ")
                    ? String(rawPath.split(separator: ">", maxSplits: 1).last?.trimmingCharacters(in: .whitespacesAndNewlines) ?? rawPath)
                    : rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
                let absoluteURL = repositoryRoot.appendingPathComponent(resolvedPath)

                return GitChangedFile(
                    id: resolvedPath,
                    relativePath: resolvedPath,
                    absoluteURL: absoluteURL,
                    indexStatus: indexStatus,
                    workTreeStatus: workTreeStatus
                )
            }
    }

    private static func stashes(repositoryRoot: URL) -> [GitStashEntry] {
        guard let output = try? CommandExecutionService.runString(
            "/usr/bin/git",
            arguments: ["-C", repositoryRoot.path, "stash", "list"]
        ) else {
            return []
        }

        return output
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                let value = String(line)
                let parts = value.split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
                guard parts.count >= 3 else {
                    return nil
                }
                return GitStashEntry(
                    id: String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines),
                    name: String(parts[1]).trimmingCharacters(in: .whitespacesAndNewlines),
                    summary: String(parts[2]).trimmingCharacters(in: .whitespacesAndNewlines)
                )
            }
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
