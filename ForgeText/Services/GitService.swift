import Foundation

enum GitService {
    struct GitWorkspaceSnapshot {
        let summary: GitRepositorySummary?
        let branches: [String]
        let changedFiles: [GitChangedFile]
        let stashes: [GitStashEntry]
        let graphEntries: [GitGraphEntry]
        let remotes: [GitRemote]

        static let empty = GitWorkspaceSnapshot(
            summary: nil,
            branches: [],
            changedFiles: [],
            stashes: [],
            graphEntries: [],
            remotes: []
        )
    }

    enum GitError: LocalizedError, Equatable {
        case repositoryNotFound
        case fileOutsideRepository
        case noCommittedVersion(String)
        case branchSwitchFailed(String)
        case commitMessageRequired
        case branchNameRequired
        case patchTooLarge
        case patchApplyFailed(String)

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
            case .patchTooLarge:
                return "The reviewed patch exceeds ForgeText's 1 MB apply limit."
            case let .patchApplyFailed(message):
                return "ForgeText could not apply the reviewed patch. \(message)"
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
            return try runGitString(
                ["-C", repositoryRoot.path, "show", "HEAD:\(relativePath)"]
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
            ["-C", repositoryRoot.path, "diff", "--no-ext-diff", "--no-textconv", "--unified=0", "--", relativePath],
            ["-C", repositoryRoot.path, "diff", "--cached", "--no-ext-diff", "--no-textconv", "--unified=0", "--", relativePath],
        ]

        for arguments in diffVariants {
            guard let output = try? runGitString(arguments) else {
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
              let output = try? runGitString(
                  ["-C", repositoryRoot.path, "blame", "--porcelain", "-L", "\(lineNumber),\(lineNumber)", "--", relativePath]
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
            _ = try runGitString(
                ["-C", repositoryRoot.path, "checkout", branch],
                limits: .default
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
        _ = try runGitString(
            ["-C", repositoryRoot.path, "add", "--", relativePath],
            limits: .default
        )
    }

    static func unstage(fileURL: URL, workspaceRoot: URL?) throws {
        guard let repositoryRoot = repositoryRoot(containing: workspaceRoot ?? fileURL.deletingLastPathComponent()) else {
            throw GitError.repositoryNotFound
        }

        let relativePath = try relativePath(for: fileURL, repositoryRoot: repositoryRoot)
        _ = try runGitString(
            ["-C", repositoryRoot.path, "restore", "--staged", "--", relativePath],
            limits: .default
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
            stashes: stashes(repositoryRoot: repositoryRoot),
            graphEntries: graphEntries(repositoryRoot: repositoryRoot),
            remotes: remotes(repositoryRoot: repositoryRoot)
        )
    }

    static func fetch(at location: URL?) throws {
        guard let repositoryRoot = repositoryRoot(containing: location) else {
            throw GitError.repositoryNotFound
        }

        _ = try runGitString(
            ["-C", repositoryRoot.path, "fetch", "--all", "--prune"],
            limits: .default
        )
    }

    static func pull(at location: URL?) throws {
        guard let repositoryRoot = repositoryRoot(containing: location) else {
            throw GitError.repositoryNotFound
        }

        _ = try runGitString(
            ["-C", repositoryRoot.path, "pull", "--ff-only"],
            limits: .default
        )
    }

    static func push(at location: URL?) throws {
        guard let repositoryRoot = repositoryRoot(containing: location) else {
            throw GitError.repositoryNotFound
        }

        _ = try runGitString(
            ["-C", repositoryRoot.path, "push"],
            limits: .default
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

        _ = try runGitString(
            ["-C", repositoryRoot.path, "commit", "-m", trimmedMessage],
            limits: .default
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

        _ = try runGitString(
            ["-C", repositoryRoot.path, "checkout", "-b", trimmedBranch],
            limits: .default
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

        _ = try runGitString(arguments, limits: .default)
    }

    static func stashPop(_ stashID: String?, at location: URL?) throws {
        guard let repositoryRoot = repositoryRoot(containing: location) else {
            throw GitError.repositoryNotFound
        }

        var arguments = ["-C", repositoryRoot.path, "stash", "pop"]
        if let stashID, !stashID.isEmpty {
            arguments.append(stashID)
        }

        _ = try runGitString(arguments, limits: .default)
    }

    static func diffForWorkingTree(at location: URL?) throws -> String {
        guard let repositoryRoot = repositoryRoot(containing: location) else {
            throw GitError.repositoryNotFound
        }

        return try runGitString(
            ["-C", repositoryRoot.path, "diff", "--cached", "--no-ext-diff", "--no-textconv", "--stat", "--patch"]
        )
    }

    static func workingTreePatch(for fileURL: URL, workspaceRoot: URL?) throws -> String {
        guard let repositoryRoot = repositoryRoot(containing: workspaceRoot ?? fileURL.deletingLastPathComponent()) else {
            throw GitError.repositoryNotFound
        }

        let relativePath = try relativePath(for: fileURL, repositoryRoot: repositoryRoot)
        return try runGitString(
            ["-C", repositoryRoot.path, "diff", "--no-ext-diff", "--no-textconv", "--", relativePath]
        )
    }

    static func stageReviewedPatch(_ patch: String, at location: URL?) throws {
        guard patch.utf8.count <= 1_024 * 1_024 else {
            throw GitError.patchTooLarge
        }
        guard let repositoryRoot = repositoryRoot(containing: location) else {
            throw GitError.repositoryNotFound
        }

        let patchData = Data(patch.utf8)
        do {
            _ = try runGitString(
                ["-C", repositoryRoot.path, "apply", "--cached", "--check", "--whitespace=nowarn", "-"],
                input: patchData,
                limits: .default
            )
            _ = try runGitString(
                ["-C", repositoryRoot.path, "apply", "--cached", "--whitespace=nowarn", "-"],
                input: patchData,
                limits: .default
            )
        } catch {
            throw GitError.patchApplyFailed(error.localizedDescription)
        }
    }

    static func fileHistory(for fileURL: URL, workspaceRoot: URL?, limit: Int = 40) throws -> [GitGraphEntry] {
        guard let repositoryRoot = repositoryRoot(containing: workspaceRoot ?? fileURL.deletingLastPathComponent()) else {
            throw GitError.repositoryNotFound
        }

        let relativePath = try relativePath(for: fileURL, repositoryRoot: repositoryRoot)
        let boundedLimit = min(max(limit, 1), 100)
        let output = try runGitString(
            [
                "-C", repositoryRoot.path,
                "log", "--follow", "--date=relative",
                "--format=%x01%H%x01%an%x01%ar%x01%d%x01%s",
                "-n", String(boundedLimit), "--", relativePath,
            ]
        )
        return parseGraphEntries(output)
    }

    static func worktrees(for location: URL?) -> [GitWorktreeRecord] {
        guard let repositoryRoot = repositoryRoot(containing: location),
              let output = try? runGitString(["-C", repositoryRoot.path, "worktree", "list", "--porcelain"])
        else {
            return []
        }

        return parseWorktrees(output)
    }

    static func applyReviewedPatch(_ patch: String, at location: URL?, reverse: Bool = false) throws {
        guard patch.utf8.count <= 1_024 * 1_024 else {
            throw GitError.patchTooLarge
        }
        guard let repositoryRoot = repositoryRoot(containing: location) else {
            throw GitError.repositoryNotFound
        }

        let patchData = Data(patch.utf8)
        var checkArguments = ["-C", repositoryRoot.path, "apply", "--check", "--whitespace=nowarn"]
        if reverse { checkArguments.append("--reverse") }
        checkArguments.append("-")

        do {
            _ = try runGitString(checkArguments, input: patchData, limits: .default)

            var applyArguments = ["-C", repositoryRoot.path, "apply", "--whitespace=nowarn"]
            if reverse { applyArguments.append("--reverse") }
            applyArguments.append("-")
            _ = try runGitString(applyArguments, input: patchData, limits: .default)
        } catch {
            throw GitError.patchApplyFailed(error.localizedDescription)
        }
    }

    private static func repositoryRoot(containing location: URL?) -> URL? {
        guard let location else {
            return nil
        }

        let directory = location.hasDirectoryPath ? location : location.deletingLastPathComponent()

        guard let output = try? runGitString(
            ["-C", directory.path, "rev-parse", "--show-toplevel"]
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
        guard let output = try? runGitString(
            ["-C", repositoryRoot.path, "status", "--short", "--branch"]
        ) else {
            return nil
        }

        return parseStatusOutput(output, rootURL: repositoryRoot)
    }

    private static func branches(repositoryRoot: URL) -> [String] {
        guard let output = try? runGitString(
            ["-C", repositoryRoot.path, "branch", "--format=%(refname:short)"]
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
        guard let output = try? runGitString(
            ["-C", repositoryRoot.path, "status", "--porcelain=v1"]
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
        guard let output = try? runGitString(
            ["-C", repositoryRoot.path, "stash", "list"]
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

    private static func graphEntries(repositoryRoot: URL) -> [GitGraphEntry] {
        guard let output = try? runGitString(
            [
                "-C",
                repositoryRoot.path,
                "log",
                "--graph",
                "--decorate",
                "--date=relative",
                "--format=%x01%H%x01%an%x01%ar%x01%d%x01%s",
                "-n",
                "24",
            ]
        ) else {
            return []
        }

        return parseGraphEntries(output)
    }

    private static func parseGraphEntries(_ output: String) -> [GitGraphEntry] {
        output
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                let raw = String(line)
                guard let markerIndex = raw.firstIndex(of: "\u{1}") else {
                    return nil
                }

                let graphPrefix = String(raw[..<markerIndex]).trimmingCharacters(in: .whitespaces)
                let payload = String(raw[markerIndex...])
                let fields = payload
                    .split(separator: "\u{1}", omittingEmptySubsequences: false)
                    .dropFirst()
                    .map(String.init)

                guard fields.count >= 5 else {
                    return nil
                }

                return GitGraphEntry(
                    id: fields[0],
                    graphPrefix: graphPrefix,
                    commitHash: fields[0],
                    author: fields[1],
                    relativeDate: fields[2],
                    references: fields[3].trimmingCharacters(in: .whitespacesAndNewlines),
                    summary: fields[4]
                )
            }
    }

    private static func parseWorktrees(_ output: String) -> [GitWorktreeRecord] {
        var records: [GitWorktreeRecord] = []
        var fields: [String: String] = [:]
        var flags = Set<String>()

        func appendRecord() {
            guard let path = fields["worktree"], let head = fields["HEAD"] else { return }
            let rawBranch = fields["branch"]
            let branch = rawBranch.map { value in
                value.hasPrefix("refs/heads/") ? String(value.dropFirst("refs/heads/".count)) : value
            }
            records.append(
                GitWorktreeRecord(
                    id: path,
                    path: path,
                    head: head,
                    branch: branch,
                    isBare: flags.contains("bare"),
                    isDetached: flags.contains("detached"),
                    isLocked: flags.contains("locked") || fields["locked"] != nil
                )
            )
        }

        for line in output.split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.isEmpty {
                appendRecord()
                fields = [:]
                flags = []
                continue
            }

            let parts = line.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: false)
            let key = String(parts[0])
            if parts.count == 2 {
                fields[key] = String(parts[1])
            } else {
                flags.insert(key)
            }
        }
        appendRecord()
        return records
    }

    private static func remotes(repositoryRoot: URL) -> [GitRemote] {
        guard let output = try? runGitString(
            ["-C", repositoryRoot.path, "remote", "-v"]
        ) else {
            return []
        }

        var remotes: [String: GitRemote] = [:]

        for line in output.split(whereSeparator: \.isNewline).map(String.init) {
            let parts = line.split(whereSeparator: \.isWhitespace).map(String.init)
            guard parts.count >= 3 else {
                continue
            }

            let name = parts[0]
            let url = parts[1]
            let kind = parts[2]
            let existing = remotes[name] ?? GitRemote(id: name, name: name, fetchURL: nil, pushURL: nil)

            if kind.contains("(fetch)") {
                remotes[name] = GitRemote(id: name, name: name, fetchURL: url, pushURL: existing.pushURL)
            } else if kind.contains("(push)") {
                remotes[name] = GitRemote(id: name, name: name, fetchURL: existing.fetchURL, pushURL: url)
            }
        }

        return remotes.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private static func relativePath(for fileURL: URL, repositoryRoot: URL) throws -> String {
        let standardizedFileURL = fileURL.standardizedFileURL
        let standardizedRootURL = repositoryRoot.standardizedFileURL
        let filePath = standardizedFileURL.path
        let rootPath = standardizedRootURL.path
        let rootPrefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"

        guard filePath.hasPrefix(rootPrefix) else {
            throw GitError.fileOutsideRepository
        }

        let relativePath = standardizedFileURL.path(percentEncoded: false)
            .replacingOccurrences(of: rootPrefix, with: "", options: [.anchored])
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !relativePath.isEmpty else {
            throw GitError.fileOutsideRepository
        }

        return relativePath
    }

    private static func runGitString(
        _ arguments: [String],
        input: Data? = nil,
        limits: CommandExecutionService.ExecutionLimits = .gitRead
    ) throws -> String {
        let inertConfiguration = [
            "-c", "core.fsmonitor=false",
            "-c", "core.hooksPath=/dev/null",
            "-c", "protocol.ext.allow=never",
        ]
        return try CommandExecutionService.runString(
            "/usr/bin/git",
            arguments: inertConfiguration + arguments,
            input: input,
            environment: [
                "GIT_EDITOR": "/usr/bin/true",
                "GIT_EXTERNAL_DIFF": "",
                "GIT_PAGER": "cat",
                "GIT_SEQUENCE_EDITOR": "/usr/bin/true",
                "GIT_TERMINAL_PROMPT": "0",
            ],
            limits: limits
        )
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
