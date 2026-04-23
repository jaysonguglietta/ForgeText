import Foundation

enum RemoteAgentService {
    static let installPath = "~/.forgetext/bin/forgetext-agent"
    private static let version = "1.0.0"

    static func status(connection: String) -> RemoteAgentStatus {
        let originalConnection = connection
        guard let connection = validatedConnection(connection) else {
            return .unavailable(connection: originalConnection, installPath: installPath, error: RemoteFileService.RemoteError.invalidConnection.localizedDescription)
        }

        let command = """
        if [ -x \(installPath) ]; then \(installPath) --version; else exit 12; fi
        """

        do {
            let result = try CommandExecutionService.runString("/usr/bin/ssh", arguments: [connection, command])
            let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
            return RemoteAgentStatus(
                connection: connection,
                isInstalled: !trimmed.isEmpty,
                version: trimmed.isEmpty ? nil : trimmed,
                installPath: installPath,
                checkedAt: Date(),
                lastError: nil
            )
        } catch {
            return .unavailable(connection: connection, installPath: installPath, error: error.localizedDescription)
        }
    }

    static func install(on connection: String) throws -> RemoteAgentStatus {
        guard let connection = validatedConnection(connection) else {
            throw RemoteFileService.RemoteError.invalidConnection
        }

        let script = remoteAgentScript()
        let escapedScript = script
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")

        let command = """
        mkdir -p ~/.forgetext/bin && printf "%s" "\(escapedScript)" > ~/.forgetext/bin/forgetext-agent && chmod +x ~/.forgetext/bin/forgetext-agent && ~/.forgetext/bin/forgetext-agent --version
        """

        let output = try CommandExecutionService.runString("/usr/bin/ssh", arguments: [connection, command])
        return RemoteAgentStatus(
            connection: connection,
            isInstalled: true,
            version: output.trimmingCharacters(in: .whitespacesAndNewlines),
            installPath: installPath,
            checkedAt: Date(),
            lastError: nil
        )
    }

    static func search(connection: String, rootPath: String, query: String) throws -> [RemoteSearchHit] {
        guard let connection = validatedConnection(connection) else {
            throw RemoteFileService.RemoteError.invalidConnection
        }

        let output = try CommandExecutionService.runString(
            "/usr/bin/ssh",
            arguments: [connection, "\(installPath) search \(CommandExecutionService.shellQuote(rootPath)) \(CommandExecutionService.shellQuote(query))"]
        )

        guard let data = output.data(using: .utf8),
              let records = try? JSONDecoder().decode([RemoteSearchRecord].self, from: data)
        else {
            return []
        }

        return records.map {
            RemoteSearchHit(connection: connection, path: $0.path, lineNumber: $0.lineNumber, lineText: $0.lineText)
        }
    }

    static func run(connection: String, command: String) throws -> CommandExecutionService.CommandResult {
        guard let connection = validatedConnection(connection) else {
            throw RemoteFileService.RemoteError.invalidConnection
        }

        let output = try CommandExecutionService.runString(
            "/usr/bin/ssh",
            arguments: [connection, "\(installPath) run \(CommandExecutionService.shellQuote(command))"]
        )

        guard let data = output.data(using: .utf8),
              let response = try? JSONDecoder().decode(RemoteCommandResponse.self, from: data)
        else {
            return CommandExecutionService.CommandResult(stdout: Data(), stderr: Data(), terminationStatus: 1)
        }

        return CommandExecutionService.CommandResult(
            stdout: Data(response.stdout.utf8),
            stderr: Data(response.stderr.utf8),
            terminationStatus: response.status
        )
    }

    static func readFile(connection: String, path: String) throws -> String {
        guard let connection = validatedConnection(connection) else {
            throw RemoteFileService.RemoteError.invalidConnection
        }

        return try CommandExecutionService.runString(
            "/usr/bin/ssh",
            arguments: [connection, "\(installPath) read \(CommandExecutionService.shellQuote(path))"]
        )
    }

    private static func validatedConnection(_ connection: String) -> String? {
        let trimmed = connection.trimmingCharacters(in: .whitespacesAndNewlines)
        return RemoteFileReference.isValidConnection(trimmed) ? trimmed : nil
    }

    private static func remoteAgentScript() -> String {
        """
        #!/usr/bin/env python3
        import json
        import subprocess
        import sys
        from pathlib import Path

        VERSION = "\(version)"

        def main() -> int:
            if len(sys.argv) < 2:
                return 1

            command = sys.argv[1]

            if command == "--version":
                print(VERSION)
                return 0

            if command == "read":
                if len(sys.argv) < 3:
                    return 1
                sys.stdout.write(Path(sys.argv[2]).read_text())
                return 0

            if command == "search":
                if len(sys.argv) < 4:
                    return 1
                root_path = sys.argv[2]
                query = sys.argv[3]
                process = subprocess.run(
                    ["grep", "-RIn", "--exclude-dir=.git", "--exclude-dir=node_modules", "--", query, root_path],
                    capture_output=True,
                    text=True,
                )
                results = []
                for raw_line in process.stdout.splitlines():
                    parts = raw_line.split(":", 2)
                    if len(parts) != 3:
                        continue
                    try:
                        line_number = int(parts[1])
                    except ValueError:
                        continue
                    results.append({"path": parts[0], "lineNumber": line_number, "lineText": parts[2]})
                print(json.dumps(results))
                return 0

            if command == "run":
                if len(sys.argv) < 3:
                    return 1
                process = subprocess.run(sys.argv[2], shell=True, capture_output=True, text=True)
                print(json.dumps({
                    "status": process.returncode,
                    "stdout": process.stdout,
                    "stderr": process.stderr,
                }))
                return 0

            return 1

        if __name__ == "__main__":
            raise SystemExit(main())
        """
    }

    private struct RemoteSearchRecord: Codable {
        let path: String
        let lineNumber: Int
        let lineText: String
    }

    private struct RemoteCommandResponse: Codable {
        let status: Int32
        let stdout: String
        let stderr: String
    }
}
