import Foundation

enum CommandExecutionService {
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

    static func run(_ executable: String, arguments: [String], input: Data? = nil) throws -> Data {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments

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

        let stdout = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        guard process.terminationStatus == 0 else {
            throw CommandFailure(
                executable: executable,
                arguments: arguments,
                status: process.terminationStatus,
                stderr: stderr
            )
        }

        return stdout
    }

    static func runString(_ executable: String, arguments: [String], input: Data? = nil) throws -> String {
        let data = try run(executable, arguments: arguments, input: input)
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
