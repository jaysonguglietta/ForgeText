import Foundation

enum EmbeddedTerminalService {
    static let suggestedCommands = [
        "ls -la",
        "git status --short",
        "pwd",
        "swift test",
        "npm test",
        "python3 -m pytest",
    ]

    static func run(command: String, currentDirectoryURL: URL?) async -> TerminalCommandRun {
        let startedAt = Date()

        do {
            let result = try CommandExecutionService.execute(
                "/bin/zsh",
                arguments: ["-lc", command],
                currentDirectoryURL: currentDirectoryURL
            )

            let stdout = String(data: result.stdout, encoding: .utf8) ?? ""
            let stderr = String(data: result.stderr, encoding: .utf8) ?? ""
            let output = [stdout, stderr]
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                .joined(separator: stdout.isEmpty || stderr.isEmpty ? "" : "\n\n")

            return TerminalCommandRun(
                command: command,
                workingDirectoryPath: currentDirectoryURL?.path,
                startedAt: startedAt,
                endedAt: Date(),
                output: output.isEmpty ? "Command finished without output." : output,
                status: result.terminationStatus == 0 ? .succeeded : .failed,
                exitCode: result.terminationStatus
            )
        } catch {
            return TerminalCommandRun(
                command: command,
                workingDirectoryPath: currentDirectoryURL?.path,
                startedAt: startedAt,
                endedAt: Date(),
                output: error.localizedDescription,
                status: .failed,
                exitCode: nil
            )
        }
    }
}
