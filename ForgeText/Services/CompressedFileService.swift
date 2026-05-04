import Foundation

enum CompressedFileService {
    struct PreviewResult {
        let data: Data
        let isTruncated: Bool
    }

    enum CompressionError: LocalizedError {
        case outputTooLarge(Int)

        var errorDescription: String? {
            switch self {
            case let .outputTooLarge(limit):
                return "ForgeText stopped decompressing this gzip file because it expanded past the safe limit of \(limit.formatted()) bytes."
            }
        }
    }

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

    static func decompressGzip(at url: URL, maximumSize: Int) throws -> Data {
        let preview = try limitedDecompression(at: url, maximumSize: maximumSize, allowTruncation: false)
        return preview.data
    }

    static func decompressGzipPreview(at url: URL, maxBytes: Int) throws -> PreviewResult {
        try limitedDecompression(at: url, maximumSize: maxBytes, allowTruncation: true)
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

    private static func limitedDecompression(at url: URL, maximumSize: Int, allowTruncation: Bool) throws -> PreviewResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/gunzip")
        process.arguments = ["-c", url.path]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()

        let stdout = stdoutPipe.fileHandleForReading
        let stderr = stderrPipe.fileHandleForReading
        let chunkSize = 64 * 1_024
        var output = Data()
        var exceededLimit = false

        while true {
            let chunk = try stdout.read(upToCount: chunkSize) ?? Data()
            guard !chunk.isEmpty else {
                break
            }

            let remaining = maximumSize - output.count
            if chunk.count > remaining {
                if remaining > 0 {
                    output.append(chunk.prefix(remaining))
                }
                exceededLimit = true
                process.terminate()
                break
            }

            output.append(chunk)
        }

        process.waitUntilExit()
        let stderrData = try stderr.readToEnd() ?? Data()
        let stderrText = String(data: stderrData, encoding: .utf8) ?? ""

        if exceededLimit {
            if allowTruncation {
                return PreviewResult(data: output, isTruncated: true)
            }
            throw CompressionError.outputTooLarge(maximumSize)
        }

        guard process.terminationStatus == 0 else {
            throw CommandExecutionService.CommandFailure(
                executable: "/usr/bin/gunzip",
                arguments: ["-c", url.path],
                status: process.terminationStatus,
                stderr: stderrText
            )
        }

        return PreviewResult(data: output, isTruncated: false)
    }
}
