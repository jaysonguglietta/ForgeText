import Foundation

enum GitHubWorkflowService {
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

        if trimmed.hasPrefix("https://github.com/") || trimmed.hasPrefix("http://github.com/") {
            let withoutGit = trimmed.replacingOccurrences(of: ".git", with: "")
            return URL(string: withoutGit)
        }

        return nil
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
