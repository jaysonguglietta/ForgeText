import Foundation

enum ToolchainService {
    private static let trustedExecutableRoots = [
        "/bin",
        "/usr/bin",
        "/usr/local",
        "/opt/homebrew",
        "/Applications/Xcode.app/Contents/Developer/usr/bin",
    ]

    static func executablePath(named executable: String) -> String? {
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-+._"))
        guard !executable.isEmpty,
              executable.unicodeScalars.allSatisfy(allowedCharacters.contains)
        else {
            return nil
        }

        guard let output = try? CommandExecutionService.runString(
            "/usr/bin/which",
            arguments: [executable],
            limits: .gitRead
        ) else {
            return nil
        }

        let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    static func isAvailable(_ executable: String) -> Bool {
        executablePath(named: executable) != nil
    }

    static func trustedExecutablePath(named executable: String) -> String? {
        guard let path = executablePath(named: executable) else {
            return nil
        }

        let standardizedPath = URL(fileURLWithPath: path)
            .resolvingSymlinksInPath()
            .standardizedFileURL
            .path
        guard isTrustedAbsoluteExecutablePath(standardizedPath) else {
            return nil
        }

        return standardizedPath
    }

    static func isTrustedAbsoluteExecutablePath(_ path: String) -> Bool {
        let standardizedURL = URL(fileURLWithPath: path).resolvingSymlinksInPath().standardizedFileURL
        let standardizedPath = standardizedURL.path
        return standardizedURL.isFileURL
            && standardizedPath.hasPrefix("/")
            && trustedExecutableRoots.contains { directory in
                standardizedPath == directory || standardizedPath.hasPrefix(directory + "/")
            }
            && FileManager.default.isExecutableFile(atPath: standardizedPath)
            && (try? standardizedURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    }
}
