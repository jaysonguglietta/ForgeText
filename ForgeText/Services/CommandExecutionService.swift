import Darwin
import Foundation

enum CommandExecutionService {
    private final class OutputCollector: @unchecked Sendable {
        private let lock = NSLock()
        private var stdout = Data()
        private var stderr = Data()
        private var stdoutWasTruncated = false
        private var stderrWasTruncated = false

        func appendStdout(_ data: Data, limit: Int) {
            lock.lock()
            append(data, to: &stdout, wasTruncated: &stdoutWasTruncated, limit: limit)
            lock.unlock()
        }

        func appendStderr(_ data: Data, limit: Int) {
            lock.lock()
            append(data, to: &stderr, wasTruncated: &stderrWasTruncated, limit: limit)
            lock.unlock()
        }

        func snapshot() -> (stdout: Data, stderr: Data, stdoutWasTruncated: Bool, stderrWasTruncated: Bool) {
            lock.lock()
            let values = (stdout, stderr, stdoutWasTruncated, stderrWasTruncated)
            lock.unlock()
            return values
        }

        private func append(_ data: Data, to output: inout Data, wasTruncated: inout Bool, limit: Int) {
            let remainingCapacity = max(0, limit - output.count)
            if remainingCapacity > 0 {
                output.append(data.prefix(remainingCapacity))
            }
            if data.count > remainingCapacity {
                wasTruncated = true
            }
        }
    }

    struct ExecutionLimits: Sendable {
        let timeout: TimeInterval
        let maxStandardOutputBytes: Int
        let maxStandardErrorBytes: Int
        let maxStandardInputBytes: Int

        static let `default` = ExecutionLimits(
            timeout: 120,
            maxStandardOutputBytes: 8 * 1_024 * 1_024,
            maxStandardErrorBytes: 4 * 1_024 * 1_024,
            maxStandardInputBytes: 16 * 1_024 * 1_024
        )

        static let gitRead = ExecutionLimits(
            timeout: 15,
            maxStandardOutputBytes: 4 * 1_024 * 1_024,
            maxStandardErrorBytes: 1 * 1_024 * 1_024,
            maxStandardInputBytes: 1 * 1_024 * 1_024
        )

        static let formatter = ExecutionLimits(
            timeout: 30,
            maxStandardOutputBytes: 16 * 1_024 * 1_024,
            maxStandardErrorBytes: 2 * 1_024 * 1_024,
            maxStandardInputBytes: 16 * 1_024 * 1_024
        )

        static let interactiveTask = ExecutionLimits(
            timeout: 15 * 60,
            maxStandardOutputBytes: 8 * 1_024 * 1_024,
            maxStandardErrorBytes: 8 * 1_024 * 1_024,
            maxStandardInputBytes: 16 * 1_024 * 1_024
        )
    }

    struct CommandResult {
        let stdout: Data
        let stderr: Data
        let terminationStatus: Int32
        let stdoutWasTruncated: Bool
        let stderrWasTruncated: Bool

        init(
            stdout: Data,
            stderr: Data,
            terminationStatus: Int32,
            stdoutWasTruncated: Bool = false,
            stderrWasTruncated: Bool = false
        ) {
            self.stdout = stdout
            self.stderr = stderr
            self.terminationStatus = terminationStatus
            self.stdoutWasTruncated = stdoutWasTruncated
            self.stderrWasTruncated = stderrWasTruncated
        }
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

    enum ExecutionError: LocalizedError {
        case inputTooLarge(limit: Int)
        case timedOut(executable: String, timeout: TimeInterval)

        var errorDescription: String? {
            switch self {
            case let .inputTooLarge(limit):
                return "Command input exceeds the \(ByteCountFormatter.string(fromByteCount: Int64(limit), countStyle: .file)) safety limit."
            case let .timedOut(executable, timeout):
                return "\(URL(fileURLWithPath: executable).lastPathComponent) exceeded the \(Int(timeout))-second time limit."
            }
        }
    }

    static func execute(
        _ executable: String,
        arguments: [String],
        input: Data? = nil,
        currentDirectoryURL: URL? = nil,
        environment: [String: String]? = nil,
        limits: ExecutionLimits = .default
    ) throws -> CommandResult {
        if let input, input.count > limits.maxStandardInputBytes {
            throw ExecutionError.inputTooLarge(limit: limits.maxStandardInputBytes)
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectoryURL
        if let environment {
            process.environment = ProcessInfo.processInfo.environment.merging(environment) { _, replacement in replacement }
        }

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

        let outputGroup = DispatchGroup()
        let collector = OutputCollector()
        let terminationSemaphore = DispatchSemaphore(value: 0)
        process.terminationHandler = { _ in
            terminationSemaphore.signal()
        }

        try process.run()

        outputGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            drain(
                stdoutPipe.fileHandleForReading,
                append: { collector.appendStdout($0, limit: limits.maxStandardOutputBytes) }
            )
            outputGroup.leave()
        }

        outputGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            drain(
                stderrPipe.fileHandleForReading,
                append: { collector.appendStderr($0, limit: limits.maxStandardErrorBytes) }
            )
            outputGroup.leave()
        }

        if let input, let stdinPipe {
            DispatchQueue.global(qos: .userInitiated).async {
                try? stdinPipe.fileHandleForWriting.write(contentsOf: input)
                try? stdinPipe.fileHandleForWriting.close()
            }
        }

        let timedOut = terminationSemaphore.wait(timeout: .now() + limits.timeout) == .timedOut
        if timedOut {
            process.terminate()
            if terminationSemaphore.wait(timeout: .now() + 1) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                _ = terminationSemaphore.wait(timeout: .now() + 1)
            }
            try? stdinPipe?.fileHandleForWriting.close()
        }

        if outputGroup.wait(timeout: .now() + 1) == .timedOut {
            try? stdoutPipe.fileHandleForReading.close()
            try? stderrPipe.fileHandleForReading.close()
            _ = outputGroup.wait(timeout: .now() + 1)
        }
        let output = collector.snapshot()

        if timedOut {
            throw ExecutionError.timedOut(executable: executable, timeout: limits.timeout)
        }

        return CommandResult(
            stdout: output.stdout,
            stderr: output.stderr,
            terminationStatus: process.terminationStatus,
            stdoutWasTruncated: output.stdoutWasTruncated,
            stderrWasTruncated: output.stderrWasTruncated
        )
    }

    static func run(
        _ executable: String,
        arguments: [String],
        input: Data? = nil,
        currentDirectoryURL: URL? = nil,
        environment: [String: String]? = nil,
        limits: ExecutionLimits = .default
    ) throws -> Data {
        let result = try execute(
            executable,
            arguments: arguments,
            input: input,
            currentDirectoryURL: currentDirectoryURL,
            environment: environment,
            limits: limits
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
        currentDirectoryURL: URL? = nil,
        environment: [String: String]? = nil,
        limits: ExecutionLimits = .default
    ) throws -> String {
        let data = try run(
            executable,
            arguments: arguments,
            input: input,
            currentDirectoryURL: currentDirectoryURL,
            environment: environment,
            limits: limits
        )
        return String(data: data, encoding: .utf8) ?? ""
    }

    private static func drain(_ fileHandle: FileHandle, append: (Data) -> Void) {
        while true {
            let data = fileHandle.readData(ofLength: 64 * 1_024)
            guard !data.isEmpty else {
                return
            }
            append(data)
        }
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
