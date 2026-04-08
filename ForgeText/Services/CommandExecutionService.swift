import Foundation

enum CommandExecutionService {
    struct CommandResult {
        let stdout: Data
        let stderr: Data
        let terminationStatus: Int32
    }

    struct CommandFailure: LocalizedError {
        let executable: String
        let arguments: [String]
        let status: Int32
        let stderr: String

        var errorDescription: String? {
            let suffix = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            if suffix.isEmpty {
                return "\(URL(fileURLWithPath: executable).lastPathComponent) exited with status \(status)."
            }

            return "\(URL(fileURLWithPath: executable).lastPathComponent) failed: \(suffix)"
        }
    }

    static func execute(
        _ executable: String,
        arguments: [String],
        input: Data? = nil,
        currentDirectoryURL: URL? = nil
    ) throws -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        let stdinPipe: Pipe?
        if input != nil {
            let pipe = Pipe()
            process.standardInput = pipe
            stdinPipe = pipe
        } else {
            stdinPipe = nil
        }

        try process.run()

        if let input, let stdinPipe {
            stdinPipe.fileHandleForWriting.write(input)
            try? stdinPipe.fileHandleForWriting.close()
        }

        process.waitUntilExit()

        return CommandResult(
            stdout: stdoutPipe.fileHandleForReading.readDataToEndOfFile(),
            stderr: stderrPipe.fileHandleForReading.readDataToEndOfFile(),
            terminationStatus: process.terminationStatus
        )
    }

    static func run(
        _ executable: String,
        arguments: [String],
        input: Data? = nil,
        currentDirectoryURL: URL? = nil
    ) throws -> Data {
        let result = try execute(
            executable,
            arguments: arguments,
            input: input,
            currentDirectoryURL: currentDirectoryURL
        )
        let stderr = String(data: result.stderr, encoding: .utf8) ?? ""

        guard result.terminationStatus == 0 else {
            throw CommandFailure(
                executable: executable,
                arguments: arguments,
                status: result.terminationStatus,
                stderr: stderr
            )
        }

        return result.stdout
    }

    static func runString(
        _ executable: String,
        arguments: [String],
        input: Data? = nil,
        currentDirectoryURL: URL? = nil
    ) throws -> String {
        let data = try run(
            executable,
            arguments: arguments,
            input: input,
            currentDirectoryURL: currentDirectoryURL
        )
        return String(data: data, encoding: .utf8) ?? ""
    }

    static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    static func appleScriptQuote(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
