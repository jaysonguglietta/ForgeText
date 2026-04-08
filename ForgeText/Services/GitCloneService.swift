import Foundation

enum GitCloneService {
    enum GitCloneError: LocalizedError {
        case missingRepositorySpecifier
        case missingDestinationParent
        case invalidDirectoryName
        case gitUnavailable
        case destinationAlreadyExists(URL)

        var errorDescription: String? {
            switch self {
            case .missingRepositorySpecifier:
                return "Enter a GitHub or Git repository URL before cloning."
            case .missingDestinationParent:
                return "Choose a local parent folder for the cloned repository."
            case .invalidDirectoryName:
                return "Enter a valid folder name for the cloned repository."
            case .gitUnavailable:
                return "ForgeText couldn’t find the `git` command-line tool on this Mac."
            case let .destinationAlreadyExists(url):
                return "A folder already exists at \(url.path(percentEncoded: false))."
            }
        }
    }

    static func suggestedDirectoryName(for repositorySpecifier: String) -> String? {
        var candidate = repositorySpecifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))

        guard !candidate.isEmpty else {
            return nil
        }

        if let queryIndex = candidate.firstIndex(of: "?") {
            candidate = String(candidate[..<queryIndex])
        }

        if let fragmentIndex = candidate.firstIndex(of: "#") {
            candidate = String(candidate[..<fragmentIndex])
        }

        if let slashIndex = candidate.lastIndex(of: "/") {
            candidate = String(candidate[candidate.index(after: slashIndex)...])
        } else if let colonIndex = candidate.lastIndex(of: ":") {
            candidate = String(candidate[candidate.index(after: colonIndex)...])
        }

        if candidate.lowercased().hasSuffix(".git") {
            candidate.removeLast(4)
        }

        let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func defaultDestinationParentURL() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let developer = home.appendingPathComponent("Developer", isDirectory: true)
        if FileManager.default.fileExists(atPath: developer.path) {
            return developer
        }

        return home
    }

    static func cloneRepository(
        repositorySpecifier: String,
        destinationParentURL: URL,
        directoryName: String,
        branchName: String,
        usesShallowClone: Bool
    ) throws -> URL {
        let repositorySpecifier = repositorySpecifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !repositorySpecifier.isEmpty else {
            throw GitCloneError.missingRepositorySpecifier
        }

        let parentURL = destinationParentURL.standardizedFileURL
        guard FileManager.default.fileExists(atPath: parentURL.path) else {
            throw GitCloneError.missingDestinationParent
        }

        let directoryName = try validatedDirectoryName(directoryName)

        guard let gitPath = ToolchainService.executablePath(named: "git")
        else {
            throw GitCloneError.gitUnavailable
        }

        let destinationURL = parentURL.appendingPathComponent(directoryName, isDirectory: true)
        guard !FileManager.default.fileExists(atPath: destinationURL.path) else {
            throw GitCloneError.destinationAlreadyExists(destinationURL)
        }

        var arguments = ["clone"]
        if usesShallowClone {
            arguments += ["--depth", "1"]
        }

        let trimmedBranchName = branchName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedBranchName.isEmpty {
            arguments += ["--branch", trimmedBranchName, "--single-branch"]
        }

        arguments += [repositorySpecifier, destinationURL.path]
        _ = try CommandExecutionService.runString(gitPath, arguments: arguments)

        return destinationURL
    }

    private static func validatedDirectoryName(_ directoryName: String) throws -> String {
        let trimmed = directoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed != ".",
              trimmed != "..",
              trimmed.rangeOfCharacter(from: CharacterSet(charactersIn: "/:")) == nil
        else {
            throw GitCloneError.invalidDirectoryName
        }

        return trimmed
    }
}
