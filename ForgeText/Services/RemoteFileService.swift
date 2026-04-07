import Foundation

enum RemoteFileService {
    enum RemoteError: LocalizedError {
        case invalidLocation

        var errorDescription: String? {
            switch self {
            case .invalidLocation:
                return "Enter a remote location like user@host:/absolute/path/to/file."
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
}
