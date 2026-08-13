import Foundation

enum GitHubWorkflowService {
    enum GitHubWorkflowError: LocalizedError {
        case cliUnavailable
        case repositoryUnavailable
        case invalidResponse
        case emptyComment
        case commentTooLarge
        case invalidInput(String)

        var errorDescription: String? {
            switch self {
            case .cliUnavailable: return "Install and authenticate the GitHub CLI (`gh auth login`) to use native team workflows."
            case .repositoryUnavailable: return "Open a workspace with a GitHub remote before loading pull requests."
            case .invalidResponse: return "The GitHub CLI returned an invalid pull-request response."
            case .emptyComment: return "Enter a review comment before posting."
            case .commentTooLarge: return "Review comments are limited to 100,000 characters."
            case let .invalidInput(message): return message
            }
        }
    }

    private struct PullRequestRecord: Decodable {
        struct Author: Decodable { let login: String? }
        let number: Int
        let title: String
        let state: String
        let isDraft: Bool
        let headRefName: String
        let baseRefName: String
        let url: String
        let author: Author?
        let reviewDecision: String?
        let updatedAt: String
    }

    private struct IssueRecord: Decodable {
        struct Label: Decodable { let name: String }
        struct Assignee: Decodable { let login: String }
        let number: Int
        let title: String
        let state: String
        let labels: [Label]
        let assignees: [Assignee]
        let url: String
        let updatedAt: String
    }

    private struct ReviewCommentRecord: Decodable {
        struct User: Decodable { let login: String? }
        let id: Int
        let path: String
        let line: Int?
        let originalLine: Int?
        let body: String
        let user: User?
        let createdAt: String
        let htmlURL: String?

        enum CodingKeys: String, CodingKey {
            case id, path, line, body, user
            case originalLine = "original_line"
            case createdAt = "created_at"
            case htmlURL = "html_url"
        }
    }

    static func state(for workspaceRoot: URL?) -> GitHubWorkflowState {
        let snapshot = GitService.snapshot(for: workspaceRoot)
        let repositoryURL = snapshot.remotes
            .compactMap { githubWebURL(from: $0.pushURL ?? $0.fetchURL ?? "") }
            .first
        let branch = snapshot.summary?.branchName
        let compareURL = compareURL(repositoryURL: repositoryURL, branchName: branch)
        let changedFileCount = snapshot.changedFiles.count

        let status: String
        if repositoryURL == nil {
            status = "No GitHub remote detected for the active workspace."
        } else if changedFileCount == 0 {
            status = "GitHub remote detected. Working tree is clean."
        } else {
            status = "GitHub remote detected with \(changedFileCount) changed file\(changedFileCount == 1 ? "" : "s")."
        }

        return GitHubWorkflowState(
            repositoryURL: repositoryURL,
            compareURL: compareURL,
            branchName: branch,
            changedFileCount: changedFileCount,
            statusMessage: status,
            refreshedAt: Date()
        )
    }

    static func githubWebURL(from remote: String) -> URL? {
        let trimmed = remote.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        if trimmed.hasPrefix("git@github.com:") {
            let path = trimmed
                .replacingOccurrences(of: "git@github.com:", with: "")
                .replacingOccurrences(of: ".git", with: "")
            return URL(string: "https://github.com/\(path)")
        }

        if trimmed.hasPrefix("ssh://git@github.com/") {
            let path = trimmed
                .replacingOccurrences(of: "ssh://git@github.com/", with: "")
                .replacingOccurrences(of: ".git", with: "")
            return URL(string: "https://github.com/\(path)")
        }

        if trimmed.hasPrefix("https://github.com/") {
            let withoutGit = trimmed.replacingOccurrences(of: ".git", with: "")
            return URL(string: withoutGit)
        }

        if trimmed.hasPrefix("http://github.com/"),
           var components = URLComponents(string: trimmed.replacingOccurrences(of: ".git", with: "")) {
            components.scheme = "https"
            return components.url
        }

        return nil
    }

    static func pullRequests(workspaceRoot: URL?) throws -> [GitHubPullRequestSummary] {
        guard let workspaceRoot else { throw GitHubWorkflowError.repositoryUnavailable }
        guard state(for: workspaceRoot).repositoryURL != nil else { throw GitHubWorkflowError.repositoryUnavailable }
        guard let ghPath = ToolchainService.trustedExecutablePath(named: "gh") else {
            throw GitHubWorkflowError.cliUnavailable
        }

        let data = try CommandExecutionService.run(
            ghPath,
            arguments: [
                "pr", "list", "--limit", "50", "--state", "open",
                "--json", "number,title,state,isDraft,headRefName,baseRefName,url,author,reviewDecision,updatedAt",
            ],
            currentDirectoryURL: workspaceRoot,
            environment: ["NO_COLOR": "1", "GH_PROMPT_DISABLED": "1"],
            limits: .gitRead
        )
        guard let records = try? JSONDecoder().decode([PullRequestRecord].self, from: data) else {
            throw GitHubWorkflowError.invalidResponse
        }
        return records.compactMap { record in
            guard let url = URL(string: record.url), url.scheme == "https", url.host?.lowercased() == "github.com" else {
                return nil
            }
            return GitHubPullRequestSummary(
                number: record.number,
                title: record.title,
                state: record.state,
                isDraft: record.isDraft,
                headBranch: record.headRefName,
                baseBranch: record.baseRefName,
                url: url,
                authorLogin: record.author?.login ?? "unknown",
                reviewDecision: record.reviewDecision?.nonEmpty,
                updatedAt: record.updatedAt
            )
        }
    }

    static func postComment(_ body: String, pullRequestNumber: Int, workspaceRoot: URL?) throws {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw GitHubWorkflowError.emptyComment }
        guard trimmed.count <= 100_000 else { throw GitHubWorkflowError.commentTooLarge }
        guard pullRequestNumber > 0, let workspaceRoot else { throw GitHubWorkflowError.repositoryUnavailable }
        guard let ghPath = ToolchainService.trustedExecutablePath(named: "gh") else {
            throw GitHubWorkflowError.cliUnavailable
        }

        _ = try CommandExecutionService.run(
            ghPath,
            arguments: ["pr", "comment", String(pullRequestNumber), "--body-file", "-"],
            input: Data(trimmed.utf8),
            currentDirectoryURL: workspaceRoot,
            environment: ["NO_COLOR": "1", "GH_PROMPT_DISABLED": "1"],
            limits: .gitRead
        )
    }

    static func issues(workspaceRoot: URL?) throws -> [GitHubIssueSummary] {
        let (ghPath, workspaceRoot) = try authenticatedContext(workspaceRoot)
        let data = try CommandExecutionService.run(
            ghPath,
            arguments: ["issue", "list", "--limit", "100", "--state", "open", "--json", "number,title,state,labels,assignees,url,updatedAt"],
            currentDirectoryURL: workspaceRoot,
            environment: githubEnvironment,
            limits: .gitRead
        )
        guard let records = try? JSONDecoder().decode([IssueRecord].self, from: data) else {
            throw GitHubWorkflowError.invalidResponse
        }
        return records.compactMap { record in
            guard let url = validatedGitHubURL(record.url) else { return nil }
            return GitHubIssueSummary(
                number: record.number,
                title: record.title,
                state: record.state,
                labels: record.labels.map(\.name),
                assignees: record.assignees.map(\.login),
                url: url,
                updatedAt: record.updatedAt
            )
        }
    }

    static func checks(pullRequestNumber: Int, workspaceRoot: URL?) throws -> [GitHubCheckSummary] {
        guard pullRequestNumber > 0 else { throw GitHubWorkflowError.invalidInput("Select a valid pull request first.") }
        let (ghPath, workspaceRoot) = try authenticatedContext(workspaceRoot)
        let data = try CommandExecutionService.run(
            ghPath,
            arguments: ["pr", "view", String(pullRequestNumber), "--json", "statusCheckRollup"],
            currentDirectoryURL: workspaceRoot,
            environment: githubEnvironment,
            limits: .gitRead
        )
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let records = root["statusCheckRollup"] as? [[String: Any]]
        else { throw GitHubWorkflowError.invalidResponse }
        return records.prefix(250).compactMap { record in
            let name = record["name"] as? String ?? record["context"] as? String ?? "Unnamed check"
            let detailsURL = record["detailsUrl"] as? String ?? record["targetUrl"] as? String
            return GitHubCheckSummary(
                name: name,
                state: record["status"] as? String ?? record["state"] as? String ?? "UNKNOWN",
                conclusion: record["conclusion"] as? String,
                workflow: record["workflowName"] as? String,
                url: detailsURL.flatMap(validatedGitHubURL)
            )
        }
    }

    static func reviewThreads(pullRequestNumber: Int, workspaceRoot: URL?) throws -> [GitHubReviewThreadSummary] {
        guard pullRequestNumber > 0 else { throw GitHubWorkflowError.invalidInput("Select a valid pull request first.") }
        let (ghPath, workspaceRoot) = try authenticatedContext(workspaceRoot)
        let ownerName = try repositoryNameWithOwner(ghPath: ghPath, workspaceRoot: workspaceRoot)
        let data = try CommandExecutionService.run(
            ghPath,
            arguments: [
                "api",
                "repos/\(ownerName)/pulls/\(pullRequestNumber)/comments?per_page=100",
                "--paginate",
                "--slurp",
            ],
            currentDirectoryURL: workspaceRoot,
            environment: githubEnvironment,
            limits: .gitRead
        )
        guard let pages = try? JSONDecoder().decode([[ReviewCommentRecord]].self, from: data) else {
            throw GitHubWorkflowError.invalidResponse
        }
        let records = pages.prefix(10).flatMap { $0.prefix(100) }
        return records.prefix(1_000).map { record in
            GitHubReviewThreadSummary(
                id: record.id,
                path: record.path,
                line: record.line ?? record.originalLine,
                author: record.user?.login ?? "unknown",
                body: record.body,
                createdAt: record.createdAt,
                url: record.htmlURL.flatMap(validatedGitHubURL)
            )
        }
    }

    @discardableResult
    static func createPullRequest(
        title: String,
        body: String,
        baseBranch: String,
        headBranch: String?,
        isDraft: Bool,
        workspaceRoot: URL?
    ) throws -> URL? {
        let safeTitle = try validatedText(title, name: "Pull-request title", maximum: 256)
        let safeBody = try validatedText(body, name: "Pull-request body", maximum: 100_000, allowsEmpty: true)
        let safeBase = try validatedGitReference(baseBranch, label: "base branch")
        let safeHead = try headBranch.map { try validatedGitReference($0, label: "head branch") }
        let (ghPath, workspaceRoot) = try authenticatedContext(workspaceRoot)
        var arguments = ["pr", "create", "--title", safeTitle, "--body-file", "-", "--base", safeBase]
        if let safeHead { arguments += ["--head", safeHead] }
        if isDraft { arguments.append("--draft") }
        let output = try CommandExecutionService.runString(
            ghPath,
            arguments: arguments,
            input: Data(safeBody.utf8),
            currentDirectoryURL: workspaceRoot,
            environment: githubEnvironment,
            limits: .gitRead
        )
        return output.split(whereSeparator: \.isWhitespace).compactMap { validatedGitHubURL(String($0)) }.first
    }

    static func draftRelease(
        tag: String,
        title: String,
        notes: String,
        target: String?,
        workspaceRoot: URL?
    ) throws {
        let safeTag = try validatedGitReference(tag, label: "release tag")
        let safeTitle = try validatedText(title, name: "Release title", maximum: 256)
        let safeNotes = try validatedText(notes, name: "Release notes", maximum: 500_000, allowsEmpty: true)
        let safeTarget = try target.map { try validatedGitReference($0, label: "release target") }
        let (ghPath, workspaceRoot) = try authenticatedContext(workspaceRoot)
        var arguments = ["release", "create", safeTag, "--draft", "--title", safeTitle, "--notes-file", "-"]
        if let safeTarget { arguments += ["--target", safeTarget] }
        _ = try CommandExecutionService.run(
            ghPath,
            arguments: arguments,
            input: Data(safeNotes.utf8),
            currentDirectoryURL: workspaceRoot,
            environment: githubEnvironment,
            limits: .gitRead
        )
    }

    private static let githubEnvironment = ["NO_COLOR": "1", "GH_PROMPT_DISABLED": "1"]

    private static func authenticatedContext(_ workspaceRoot: URL?) throws -> (String, URL) {
        guard let workspaceRoot else { throw GitHubWorkflowError.repositoryUnavailable }
        guard state(for: workspaceRoot).repositoryURL != nil else { throw GitHubWorkflowError.repositoryUnavailable }
        guard let ghPath = ToolchainService.trustedExecutablePath(named: "gh") else { throw GitHubWorkflowError.cliUnavailable }
        return (ghPath, workspaceRoot)
    }

    private static func repositoryNameWithOwner(ghPath: String, workspaceRoot: URL) throws -> String {
        let data = try CommandExecutionService.run(
            ghPath,
            arguments: ["repo", "view", "--json", "nameWithOwner"],
            currentDirectoryURL: workspaceRoot,
            environment: githubEnvironment,
            limits: .gitRead
        )
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let value = object["nameWithOwner"] as? String,
              value.range(of: #"^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$"#, options: .regularExpression) != nil
        else { throw GitHubWorkflowError.invalidResponse }
        return value
    }

    private static func validatedGitReference(_ value: String, label: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.range(of: #"^[A-Za-z0-9][A-Za-z0-9._/-]{0,127}$"#, options: .regularExpression) != nil,
              !trimmed.contains(".."), !trimmed.contains("//"), !trimmed.hasSuffix("/")
        else { throw GitHubWorkflowError.invalidInput("The \(label) contains unsupported characters.") }
        return trimmed
    }

    private static func validatedText(_ value: String, name: String, maximum: Int, allowsEmpty: Bool = false) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard allowsEmpty || !trimmed.isEmpty else { throw GitHubWorkflowError.invalidInput("\(name) is required.") }
        guard trimmed.count <= maximum else { throw GitHubWorkflowError.invalidInput("\(name) exceeds \(maximum) characters.") }
        return trimmed
    }

    private static func validatedGitHubURL(_ value: String) -> URL? {
        guard let url = URL(string: value), url.scheme == "https", url.host?.lowercased() == "github.com" else { return nil }
        return url
    }

    private static func compareURL(repositoryURL: URL?, branchName: String?) -> URL? {
        guard let repositoryURL,
              var components = URLComponents(url: repositoryURL, resolvingAgainstBaseURL: false)
        else {
            return nil
        }

        let branch = branchName?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let branch, !branch.isEmpty, branch != "HEAD" else {
            return repositoryURL
        }

        components.path = "/" + components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) + "/compare/\(branch)"
        components.queryItems = [URLQueryItem(name: "expand", value: "1")]
        return components.url
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
