import Foundation

enum RemoteFileService {
    enum RemoteError: LocalizedError {
        case invalidLocation
        case invalidSearchRoot

        var errorDescription: String? {
            switch self {
            case .invalidLocation:
                return "Enter a remote location like user@host:/absolute/path/to/file."
            case .invalidSearchRoot:
                return "Enter a remote folder path like /var/log or /etc before running a remote search."
            }
        }
    }

    static func open(spec: String) throws -> EditorDocument {
        guard let reference = RemoteFileReference.parse(spec) else {
            throw RemoteError.invalidLocation
        }

        return try open(reference: reference)
    }

    static func open(reference: RemoteFileReference) throws -> EditorDocument {
        let command = "cat -- \(CommandExecutionService.shellQuote(reference.path))"
        let output = try CommandExecutionService.runString("/usr/bin/ssh", arguments: [reference.connection, command])
        return EditorDocument.remote(reference: reference, text: output)
    }

    static func save(document: EditorDocument) throws {
        guard let reference = document.remoteReference else {
            throw RemoteError.invalidLocation
        }

        let data = try TextFileCodec.encodedData(for: document)
        let command = "cat > \(CommandExecutionService.shellQuote(reference.path))"
        _ = try CommandExecutionService.run("/usr/bin/ssh", arguments: [reference.connection, command], input: data)
    }

    static func search(connection: String, rootPath: String, query: String) throws -> [RemoteSearchHit] {
        let trimmedRoot = rootPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedRoot.isEmpty, !trimmedQuery.isEmpty else {
            throw RemoteError.invalidSearchRoot
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
        try CommandExecutionService.execute("/usr/bin/ssh", arguments: [connection, command])
    }
}
