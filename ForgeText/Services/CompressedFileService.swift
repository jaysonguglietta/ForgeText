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
        try decompressGzip(at: url, maximumSize: 64 * 1_024 * 1_024)
    }

    static func decompressGzip(at url: URL, maximumSize: Int) throws -> Data {
        let preview = try limitedDecompression(at: url, maximumSize: maximumSize, allowTruncation: false)
        return preview.data
    }

    static func decompressGzipPreview(at url: URL, maxBytes: Int) throws -> PreviewResult {
        try limitedDecompression(at: url, maximumSize: maxBytes, allowTruncation: true)
    }

    static func compressGzip(_ data: Data) throws -> Data {
        try CommandExecutionService.run(
            "/usr/bin/gzip",
            arguments: ["-c"],
            input: data,
            limits: CommandExecutionService.ExecutionLimits(
                timeout: 120,
                maxStandardOutputBytes: 64 * 1_024 * 1_024,
                maxStandardErrorBytes: 1 * 1_024 * 1_024,
                maxStandardInputBytes: 64 * 1_024 * 1_024
            )
        )
    }

    static func underlyingURL(forGzipURL url: URL) -> URL {
        guard url.pathExtension.lowercased() == "gz" else {
            return url
        }

        return url.deletingPathExtension()
    }

    private static func limitedDecompression(at url: URL, maximumSize: Int, allowTruncation: Bool) throws -> PreviewResult {
        let result = try CommandExecutionService.execute(
            "/usr/bin/gunzip",
            arguments: ["-c", url.path],
            limits: CommandExecutionService.ExecutionLimits(
                timeout: 120,
                maxStandardOutputBytes: maximumSize,
                maxStandardErrorBytes: 1_024 * 1_024,
                maxStandardInputBytes: 1_024
            )
        )
        let stderrText = String(data: result.stderr, encoding: .utf8) ?? ""

        if result.stdoutWasTruncated {
            if allowTruncation {
                return PreviewResult(data: result.stdout, isTruncated: true)
            }
            throw CompressionError.outputTooLarge(maximumSize)
        }

        guard result.terminationStatus == 0 else {
            throw CommandExecutionService.CommandFailure(
                executable: "/usr/bin/gunzip",
                arguments: ["-c", url.path],
                status: result.terminationStatus,
                stderr: stderrText
            )
        }

        return PreviewResult(data: result.stdout, isTruncated: false)
    }
}
