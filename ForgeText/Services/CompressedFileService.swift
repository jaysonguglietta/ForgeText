import Foundation

enum CompressedFileService {
    static func isGzipFile(url: URL, data: Data? = nil) -> Bool {
        if url.pathExtension.lowercased() == "gz" {
            return true
        }

        guard let data else {
            return false
        }

        let bytes = Array(data.prefix(2))
        return bytes == [0x1F, 0x8B]
    }

    static func decompressGzip(at url: URL) throws -> Data {
        try CommandExecutionService.run("/usr/bin/gunzip", arguments: ["-c", url.path])
    }

    static func compressGzip(_ data: Data) throws -> Data {
        try CommandExecutionService.run("/usr/bin/gzip", arguments: ["-c"], input: data)
    }

    static func underlyingURL(forGzipURL url: URL) -> URL {
        guard url.pathExtension.lowercased() == "gz" else {
            return url
        }

        return url.deletingPathExtension()
    }
}
