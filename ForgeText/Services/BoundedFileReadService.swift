import Darwin
import Foundation

enum BoundedFileReadService {
    enum ReadError: LocalizedError {
        case unsupportedFile
        case fileTooLarge(Int)

        var errorDescription: String? {
            switch self {
            case .unsupportedFile:
                return "ForgeText only accepts regular, non-symbolic-link files for this import."
            case let .fileTooLarge(limit):
                return "The import exceeds the \(ByteCountFormatter.string(fromByteCount: Int64(limit), countStyle: .file)) safety limit."
            }
        }
    }

    static func read(_ url: URL, maximumBytes: Int) throws -> Data {
        guard maximumBytes >= 0, maximumBytes < Int.max else {
            throw ReadError.fileTooLarge(max(0, maximumBytes))
        }
        let descriptor = url.withUnsafeFileSystemRepresentation { path -> Int32 in
            guard let path else {
                return -1
            }
            return Darwin.open(path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW)
        }
        guard descriptor >= 0 else {
            throw ReadError.unsupportedFile
        }

        var fileStatus = stat()
        guard fstat(descriptor, &fileStatus) == 0,
              (fileStatus.st_mode & S_IFMT) == S_IFREG
        else {
            Darwin.close(descriptor)
            throw ReadError.unsupportedFile
        }
        guard fileStatus.st_size >= 0, fileStatus.st_size <= off_t(maximumBytes) else {
            Darwin.close(descriptor)
            throw ReadError.fileTooLarge(maximumBytes)
        }

        let handle = FileHandle(fileDescriptor: descriptor, closeOnDealloc: true)
        defer { try? handle.close() }
        let data = try handle.read(upToCount: maximumBytes + 1) ?? Data()
        guard data.count <= maximumBytes else {
            throw ReadError.fileTooLarge(maximumBytes)
        }
        return data
    }
}
