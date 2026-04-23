import Foundation

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
        let output: String
        switch mode {
        case .directShell:
            let command = "cat -- \(CommandExecutionService.shellQuote(reference.path))"
            output = try CommandExecutionService.runString("/usr/bin/ssh", arguments: [connection, command])
        case .remoteAgent:
            output = try RemoteAgentService.readFile(connection: connection, path: reference.path)
        }
        return EditorDocument.remote(reference: reference, text: output)
    }

    static func save(document: EditorDocument) throws {
        guard let reference = document.remoteReference else {
            throw RemoteError.invalidLocation
        }

        let connection = try validatedConnection(reference.connection)
        let data = try TextFileCodec.encodedData(for: document)
        let command = "cat > \(CommandExecutionService.shellQuote(reference.path))"
        _ = try CommandExecutionService.run("/usr/bin/ssh", arguments: [connection, command], input: data)
    }

    static func search(connection: String, rootPath: String, query: String) throws -> [RemoteSearchHit] {
        try search(connection: connection, rootPath: rootPath, query: query, mode: .directShell)
    }

    static func search(connection: String, rootPath: String, query: String, mode: RemoteExecutionMode) throws -> [RemoteSearchHit] {
        let connection = try validatedConnection(connection)
        let trimmedRoot = rootPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRoot.isEmpty, !trimmedQuery.isEmpty else {
            throw RemoteError.invalidSearchRoot
        }

        if mode == .remoteAgent {
            return try RemoteAgentService.search(connection: connection, rootPath: trimmedRoot, query: trimmedQuery)
        }

        let command = """
        grep -RIn --exclude-dir=.git --exclude-dir=node_modules -- \(CommandExecutionService.shellQuote(trimmedQuery)) \(CommandExecutionService.shellQuote(trimmedRoot)) 2>/dev/null
        """
        let output = try CommandExecutionService.runString("/usr/bin/ssh", arguments: [connection, command])

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
            return try CommandExecutionService.execute("/usr/bin/ssh", arguments: [connection, command])
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
}
