import Foundation

enum SSHCommandService {
    static func arguments(connection: String, command: String, interactive: Bool = false) -> [String] {
        var values = [
            "-o", "StrictHostKeyChecking=yes",
            "-o", "UpdateHostKeys=yes",
            "-o", "ConnectTimeout=10",
            "-o", "ServerAliveInterval=15",
            "-o", "ServerAliveCountMax=3",
            "-o", "ClearAllForwardings=yes",
            "-o", "LogLevel=ERROR",
        ]
        if !interactive {
            values += ["-o", "BatchMode=yes"]
        }
        values += [connection, command]
        return values
    }

    static func runString(
        connection: String,
        command: String,
        retryCount: Int = 0,
        limits: CommandExecutionService.ExecutionLimits = .gitRead
    ) throws -> String {
        var lastError: Error?
        for attempt in 0...min(max(0, retryCount), 2) {
            do {
                return try CommandExecutionService.runString(
                    "/usr/bin/ssh",
                    arguments: arguments(connection: connection, command: command),
                    limits: limits
                )
            } catch {
                lastError = error
                if attempt < retryCount { Thread.sleep(forTimeInterval: 0.35 * Double(attempt + 1)) }
            }
        }
        throw lastError ?? RemoteFileService.RemoteError.invalidConnection
    }
}

enum SFTPDirectoryService {
    enum DirectoryError: LocalizedError {
        case invalidConnection
        case invalidPath

        var errorDescription: String? {
            switch self {
            case .invalidConnection: return "Enter a safe SSH connection before browsing with SFTP."
            case .invalidPath: return "SFTP browsing requires an absolute path without control characters."
            }
        }
    }

    static func arguments(connection: String) -> [String] {
        [
            "-q", "-b", "-",
            "-o", "StrictHostKeyChecking=yes",
            "-o", "UpdateHostKeys=yes",
            "-o", "ConnectTimeout=10",
            "-o", "ServerAliveInterval=15",
            "-o", "ServerAliveCountMax=3",
            "-o", "ClearAllForwardings=yes",
            "-o", "BatchMode=yes",
            connection,
        ]
    }

    static func list(connection: String, path: String) throws -> [RemoteDirectoryEntry] {
        guard RemoteFileReference.isValidConnection(connection) else { throw DirectoryError.invalidConnection }
        let path = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard RemoteFileReference.isValidAbsolutePath(path) else { throw DirectoryError.invalidPath }

        let escaped = path.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let input = Data("ls -la \"\(escaped)\"\nbye\n".utf8)
        let output = try CommandExecutionService.run(
            "/usr/bin/sftp",
            arguments: arguments(connection: connection),
            input: input,
            limits: .gitRead
        )
        return parseListing(String(decoding: output, as: UTF8.self), rootPath: path)
    }

    static func parseListing(_ output: String, rootPath: String) -> [RemoteDirectoryEntry] {
        output.split(whereSeparator: \.isNewline).compactMap { rawLine -> RemoteDirectoryEntry? in
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard let marker = line.first, [Character("d"), "-", "l"].contains(marker) else { return nil }
            let fields = line.split(
                maxSplits: 8,
                omittingEmptySubsequences: true,
                whereSeparator: \.isWhitespace
            )
            guard fields.count >= 9 else { return nil }
            let rawName = String(fields[8])
            let name = rawName.components(separatedBy: " -> ").first ?? rawName
            guard name != ".", name != "..", !name.contains("/"), !name.contains("\0") else { return nil }
            let kind: RemoteDirectoryEntry.Kind = marker == "d" ? .directory : (marker == "l" ? .symbolicLink : .file)
            let root = rootPath == "/" ? "" : rootPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            return RemoteDirectoryEntry(
                name: name,
                path: "/\([root, name].filter { !$0.isEmpty }.joined(separator: "/"))",
                kind: kind,
                size: Int64(fields[4])
            )
        }
        .sorted {
            if $0.kind == .directory, $1.kind != .directory { return true }
            if $0.kind != .directory, $1.kind == .directory { return false }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }
}

enum RemoteFileService {
    enum RemoteError: LocalizedError {
        case invalidLocation
        case invalidConnection
        case invalidSearchRoot

        var errorDescription: String? {
            switch self {
            case .invalidLocation:
                return "Enter a remote location like user@host:/absolute/path/to/file."
            case .invalidConnection:
                return "Enter a safe SSH connection like user@host. Connections can’t start with '-' or contain whitespace, path separators, or command options."
            case .invalidSearchRoot:
                return "Enter a remote folder path like /var/log or /etc before running a remote search."
            }
        }
    }

    static func open(spec: String) throws -> EditorDocument {
        try open(spec: spec, mode: .directShell)
    }

    static func open(spec: String, mode: RemoteExecutionMode) throws -> EditorDocument {
        guard let reference = RemoteFileReference.parse(spec) else {
            throw RemoteError.invalidLocation
        }

        return try open(reference: reference, mode: mode)
    }

    static func open(reference: RemoteFileReference) throws -> EditorDocument {
        try open(reference: reference, mode: .directShell)
    }

    static func open(reference: RemoteFileReference, mode: RemoteExecutionMode) throws -> EditorDocument {
        let connection = try validatedConnection(reference.connection)
        let remotePath = try validatedAbsolutePath(reference.path)
        let output: String
        switch mode {
        case .directShell:
            let command = "cat -- \(CommandExecutionService.shellQuote(remotePath))"
            output = try SSHCommandService.runString(connection: connection, command: command, retryCount: 1)
        case .remoteAgent:
            output = try RemoteAgentService.readFile(connection: connection, path: remotePath)
        }
        return EditorDocument.remote(reference: reference, text: output)
    }

    static func save(document: EditorDocument) throws {
        guard let reference = document.remoteReference else {
            throw RemoteError.invalidLocation
        }

        let connection = try validatedConnection(reference.connection)
        let remotePath = try validatedAbsolutePath(reference.path)
        let data = try TextFileCodec.encodedData(for: document)
        let path = CommandExecutionService.shellQuote(remotePath)
        let command = "target=\(path); directory=$(dirname -- \"$target\"); temporary=$(mktemp \"$directory/.forgetext.XXXXXX\") || exit 1; trap 'rm -f -- \"$temporary\"' EXIT; if cat > \"$temporary\"; then chmod --reference=\"$target\" \"$temporary\" 2>/dev/null || true; mv -f -- \"$temporary\" \"$target\"; trap - EXIT; else exit 1; fi"
        _ = try CommandExecutionService.run(
            "/usr/bin/ssh",
            arguments: SSHCommandService.arguments(connection: connection, command: command),
            input: data,
            limits: .interactiveTask
        )
    }

    static func search(connection: String, rootPath: String, query: String) throws -> [RemoteSearchHit] {
        try search(connection: connection, rootPath: rootPath, query: query, mode: .directShell)
    }

    static func search(connection: String, rootPath: String, query: String, mode: RemoteExecutionMode) throws -> [RemoteSearchHit] {
        let connection = try validatedConnection(connection)
        let trimmedRoot = rootPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard RemoteFileReference.isValidAbsolutePath(trimmedRoot),
              !trimmedQuery.isEmpty,
              trimmedQuery.count <= 4_096,
              trimmedQuery.rangeOfCharacter(from: .controlCharacters) == nil
        else {
            throw RemoteError.invalidSearchRoot
        }

        if mode == .remoteAgent {
            return try RemoteAgentService.search(connection: connection, rootPath: trimmedRoot, query: trimmedQuery)
        }

        let command = """
        grep -RIn --exclude-dir=.git --exclude-dir=node_modules -- \(CommandExecutionService.shellQuote(trimmedQuery)) \(CommandExecutionService.shellQuote(trimmedRoot)) 2>/dev/null
        """
        let output = try SSHCommandService.runString(connection: connection, command: command, retryCount: 1)

        return output
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                let components = String(line).split(separator: ":", maxSplits: 2, omittingEmptySubsequences: false)
                guard components.count == 3, let lineNumber = Int(components[1]) else {
                    return nil
                }

                return RemoteSearchHit(
                    connection: connection,
                    path: String(components[0]),
                    lineNumber: lineNumber,
                    lineText: String(components[2])
                )
            }
    }

    static func run(connection: String, command: String) throws -> CommandExecutionService.CommandResult {
        try run(connection: connection, command: command, mode: .directShell)
    }

    static func run(connection: String, command: String, mode: RemoteExecutionMode) throws -> CommandExecutionService.CommandResult {
        let connection = try validatedConnection(connection)
        switch mode {
        case .directShell:
            return try CommandExecutionService.execute(
                "/usr/bin/ssh",
                arguments: SSHCommandService.arguments(connection: connection, command: command),
                limits: .interactiveTask
            )
        case .remoteAgent:
            return try RemoteAgentService.run(connection: connection, command: command)
        }
    }

    private static func validatedConnection(_ connection: String) throws -> String {
        let trimmed = connection.trimmingCharacters(in: .whitespacesAndNewlines)
        guard RemoteFileReference.isValidConnection(trimmed) else {
            throw RemoteError.invalidConnection
        }

        return trimmed
    }

    private static func validatedAbsolutePath(_ path: String) throws -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard RemoteFileReference.isValidAbsolutePath(trimmed) else {
            throw RemoteError.invalidLocation
        }
        return trimmed
    }
}
