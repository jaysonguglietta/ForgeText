import Darwin
import Foundation

struct ChunkedTextWindow: Hashable {
    let text: String
    let startOffset: Int64
    let endOffset: Int64
    let fileSize: Int64

    var progress: Double {
        guard fileSize > 0 else { return 1 }
        return min(max(Double(endOffset) / Double(fileSize), 0), 1)
    }
}

enum ChunkedTextFileService {
    static let defaultWindowBytes = 1_048_576
    static let maximumWindowBytes = 2_097_152
    static let maximumSearchBytes: Int64 = 536_870_912

    enum ChunkError: LocalizedError {
        case unsupportedFile
        case invalidOffset
        case invalidQuery

        var errorDescription: String? {
            switch self {
            case .unsupportedFile: return "Chunked viewing supports regular, non-symbolic-link files only."
            case .invalidOffset: return "The requested file window is outside the file."
            case .invalidQuery: return "Enter a UTF-8 search term up to 4,096 characters."
            }
        }
    }

    static func readWindow(
        from url: URL,
        offset: Int64,
        maximumBytes: Int = defaultWindowBytes
    ) throws -> ChunkedTextWindow {
        let windowBytes = min(max(maximumBytes, 4_096), maximumWindowBytes)
        return try withValidatedDescriptor(url) { descriptor, fileSize in
            guard offset >= 0, offset <= fileSize else { throw ChunkError.invalidOffset }
            let requestedOffset = min(offset, max(0, fileSize - 1))
            let prefixAllowance = requestedOffset > 0 ? 8_192 : 0
            let readOffset = max(0, requestedOffset - Int64(prefixAllowance))
            let capacity = min(Int64(windowBytes + prefixAllowance + 8_192), fileSize - readOffset)
            var data = Data(count: max(0, Int(capacity)))
            let count = data.withUnsafeMutableBytes { buffer in
                pread(descriptor, buffer.baseAddress, buffer.count, off_t(readOffset))
            }
            guard count >= 0 else { throw CocoaError(.fileReadUnknown) }
            data.removeSubrange(Int(count)..<data.count)

            var lower = Int(requestedOffset - readOffset)
            if requestedOffset > 0,
               let newline = data[lower...].firstIndex(of: 0x0A) {
                lower = data.index(after: newline)
            }
            var upper = min(data.count, lower + windowBytes)
            if readOffset + Int64(upper) < fileSize,
               let newline = data[..<upper].lastIndex(of: 0x0A),
               newline >= lower {
                upper = data.index(after: newline)
            }
            let payload = data[lower..<upper]
            return ChunkedTextWindow(
                text: String(decoding: payload, as: UTF8.self),
                startOffset: readOffset + Int64(lower),
                endOffset: readOffset + Int64(upper),
                fileSize: fileSize
            )
        }
    }

    static func find(
        _ query: String,
        in url: URL,
        startingAt: Int64
    ) throws -> Int64? {
        let needle = Data(query.utf8)
        guard !needle.isEmpty, needle.count <= 16_384, query.count <= 4_096 else {
            throw ChunkError.invalidQuery
        }
        return try withValidatedDescriptor(url) { descriptor, fileSize in
            var offset = min(max(0, startingAt), fileSize)
            let budgetEnd = offset > Int64.max - maximumSearchBytes
                ? Int64.max
                : offset + maximumSearchBytes
            let searchLimit = min(fileSize, budgetEnd)
            var carry = Data()
            while offset < searchLimit {
                let count = Int(min(Int64(defaultWindowBytes), searchLimit - offset))
                var block = Data(count: count)
                let bytesRead = block.withUnsafeMutableBytes { buffer in
                    pread(descriptor, buffer.baseAddress, buffer.count, off_t(offset))
                }
                guard bytesRead > 0 else { break }
                block.removeSubrange(bytesRead..<block.count)
                let candidate = carry + block
                if let range = candidate.range(of: needle) {
                    return offset - Int64(carry.count) + Int64(range.lowerBound)
                }
                let carryCount = min(max(0, needle.count - 1), candidate.count)
                carry = Data(candidate.suffix(carryCount))
                offset += Int64(bytesRead)
            }
            return nil
        }
    }

    private static func withValidatedDescriptor<T>(
        _ url: URL,
        body: (Int32, Int64) throws -> T
    ) throws -> T {
        let descriptor = url.withUnsafeFileSystemRepresentation { path in
            path.map { Darwin.open($0, O_RDONLY | O_CLOEXEC | O_NOFOLLOW) } ?? -1
        }
        guard descriptor >= 0 else { throw ChunkError.unsupportedFile }
        defer { Darwin.close(descriptor) }
        var status = stat()
        guard fstat(descriptor, &status) == 0,
              (status.st_mode & S_IFMT) == S_IFREG,
              status.st_size >= 0
        else { throw ChunkError.unsupportedFile }
        return try body(descriptor, Int64(status.st_size))
    }
}
