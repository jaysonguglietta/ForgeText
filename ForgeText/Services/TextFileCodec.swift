import Foundation

struct TextFileCodec {
    static let largeFileThreshold: Int64 = 8_000_000
    static let previewByteLimit = 1_000_000

    struct DecodedFile {
        let text: String
        let encoding: String.Encoding
        let includesByteOrderMark: Bool
        let lineEnding: LineEnding
        let isReadOnly: Bool
        let isPartialPreview: Bool
        let fileSize: Int64?
        let presentationMode: DocumentPresentationMode
        let preferredLanguage: DocumentLanguage?
        let statusMessage: String?
    }

    enum CodecError: LocalizedError {
        case unableToDecode
        case unableToEncode(String.Encoding)
        case cannotSaveReadOnlyPreview
        case symbolicLinkSaveRequiresSaveAs

        var errorDescription: String? {
            switch self {
            case .unableToDecode:
                return "ForgeText couldn’t decode that file as text using its current encoding set."
            case let .unableToEncode(encoding):
                return "The document contains characters that can’t be saved as \(encoding.displayName)."
            case .cannotSaveReadOnlyPreview:
                return "This document is a read-only preview, so ForgeText won’t overwrite the original file from it."
            case .symbolicLinkSaveRequiresSaveAs:
                return "This path is a symbolic link. Use Save As to avoid overwriting the wrong target."
            }
        }
    }

    static func load(from url: URL) throws -> DecodedFile {
        let rawData = try Data(contentsOf: url)
        let data: Data
        let preferredLanguage: DocumentLanguage?
        let statusMessage: String?

        if CompressedFileService.isGzipFile(url: url, data: rawData) {
            let likelyLanguage = DocumentLanguage.detect(from: CompressedFileService.underlyingURL(forGzipURL: url))
            preferredLanguage = likelyLanguage

            do {
                data = try CompressedFileService.decompressGzip(at: url, maximumSize: Int(largeFileThreshold))
                statusMessage = "Opened gzip-compressed file"
            } catch CompressedFileService.CompressionError.outputTooLarge {
                let preview = try CompressedFileService.decompressGzipPreview(at: url, maxBytes: previewByteLimit)
                return try gzipPreview(from: preview.data, likelyLanguage: likelyLanguage, statusMessage: "Large gzip preview loaded read-only")
            }
        } else {
            data = rawData
            preferredLanguage = nil
            statusMessage = nil
        }

        let fileSize = Int64(data.count)

        if data.isEmpty {
            return DecodedFile(
                text: "",
                encoding: .utf8,
                includesByteOrderMark: false,
                lineEnding: .lf,
                isReadOnly: false,
                isPartialPreview: false,
                fileSize: fileSize,
                presentationMode: .editor,
                preferredLanguage: preferredLanguage,
                statusMessage: statusMessage
            )
        }

        let decoded = try decode(data: data)
        return DecodedFile(
            text: decoded.text,
            encoding: decoded.encoding,
            includesByteOrderMark: decoded.includesByteOrderMark,
            lineEnding: LineEnding.detect(in: decoded.text),
            isReadOnly: false,
            isPartialPreview: false,
            fileSize: fileSize,
            presentationMode: .editor,
            preferredLanguage: preferredLanguage,
            statusMessage: statusMessage
        )
    }

    static func open(from url: URL) throws -> DecodedFile {
        if ArchiveBrowserService.canBrowse(url) {
            let archive = try ArchiveBrowserService.loadArchive(at: url)
            return DecodedFile(
                text: archive.entries.map(\.path).joined(separator: "\n"),
                encoding: .utf8,
                includesByteOrderMark: false,
                lineEnding: .lf,
                isReadOnly: true,
                isPartialPreview: false,
                fileSize: nil,
                presentationMode: .archiveBrowser,
                preferredLanguage: .plainText,
                statusMessage: "\(archive.kindLabel) opened read-only"
            )
        }

        if CompressedFileService.isGzipFile(url: url) {
            let likelyLanguage = DocumentLanguage.detect(from: CompressedFileService.underlyingURL(forGzipURL: url))
            do {
                let decompressedData = try CompressedFileService.decompressGzip(at: url, maximumSize: Int(largeFileThreshold))
                let fileSize = Int64(decompressedData.count)

                if isLikelyBinary(decompressedData) {
                    return binaryPreview(from: Data(decompressedData.prefix(previewByteLimit)), fileSize: fileSize, isPartialPreview: fileSize > Int64(previewByteLimit))
                }

                let decoded = try decode(data: decompressedData)
                return DecodedFile(
                    text: decoded.text,
                    encoding: decoded.encoding,
                    includesByteOrderMark: decoded.includesByteOrderMark,
                    lineEnding: LineEnding.detect(in: decoded.text),
                    isReadOnly: false,
                    isPartialPreview: false,
                    fileSize: fileSize,
                    presentationMode: .editor,
                    preferredLanguage: likelyLanguage,
                    statusMessage: "Opened gzip-compressed file"
                )
            } catch CompressedFileService.CompressionError.outputTooLarge {
                let preview = try CompressedFileService.decompressGzipPreview(at: url, maxBytes: previewByteLimit)
                return try gzipPreview(from: preview.data, likelyLanguage: likelyLanguage, statusMessage: "Large gzip preview loaded read-only")
            }
        }

        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isSymbolicLinkKey])
        let fileSize = values?.fileSize.map(Int64.init) ?? 0
        let likelyLanguage = DocumentLanguage.detect(from: url)
        let shouldPreview = fileSize > largeFileThreshold

        if shouldPreview {
            let previewFromEnd = likelyLanguage == .log
            let previewData = try readPreviewData(from: url, maxBytes: previewByteLimit, fromEnd: previewFromEnd)

            if isLikelyBinary(previewData) {
                return binaryPreview(from: previewData, fileSize: fileSize, isPartialPreview: true)
            }

            if let decoded = try? decode(data: previewData) {
                let previewLabel = previewFromEnd ? "Large file tail preview" : "Large file preview"
                return DecodedFile(
                    text: decoded.text,
                    encoding: decoded.encoding,
                    includesByteOrderMark: decoded.includesByteOrderMark,
                    lineEnding: LineEnding.detect(in: decoded.text),
                    isReadOnly: true,
                    isPartialPreview: true,
                    fileSize: fileSize,
                    presentationMode: .readOnlyPreview,
                    preferredLanguage: likelyLanguage,
                    statusMessage: "\(previewLabel) loaded read-only"
                )
            }

            return binaryPreview(from: previewData, fileSize: fileSize, isPartialPreview: true)
        }

        let fullData = try Data(contentsOf: url, options: [.mappedIfSafe])

        if isLikelyBinary(fullData) {
            let previewData = Data(fullData.prefix(previewByteLimit))
            return binaryPreview(from: previewData, fileSize: fileSize, isPartialPreview: fileSize > Int64(previewData.count))
        }

        do {
            let decoded = try decode(data: fullData)
            return DecodedFile(
                text: decoded.text,
                encoding: decoded.encoding,
                includesByteOrderMark: decoded.includesByteOrderMark,
                lineEnding: LineEnding.detect(in: decoded.text),
                isReadOnly: false,
                isPartialPreview: false,
                fileSize: fileSize,
                presentationMode: .editor,
                preferredLanguage: nil,
                statusMessage: nil
            )
        } catch CodecError.unableToDecode {
            let previewData = try readPreviewData(from: url, maxBytes: previewByteLimit, fromEnd: false)
            return binaryPreview(from: previewData, fileSize: fileSize, isPartialPreview: fileSize > Int64(previewData.count))
        }
    }

    static func save(document: EditorDocument, to url: URL) throws {
        if document.isReadOnly {
            throw CodecError.cannotSaveReadOnlyPreview
        }

        if (try? url.resourceValues(forKeys: [.isSymbolicLinkKey]).isSymbolicLink) == true {
            throw CodecError.symbolicLinkSaveRequiresSaveAs
        }

        var data = try encodedData(for: document)

        if url.pathExtension.lowercased() == "gz" {
            data = try CompressedFileService.compressGzip(data)
        }

        let manager = FileManager.default
        let directory = url.deletingLastPathComponent()
        let tempURL = directory.appendingPathComponent(".forge-\(UUID().uuidString).tmp")
        let originalAttributes = try? manager.attributesOfItem(atPath: url.path)

        try data.write(to: tempURL, options: .atomic)

        if let originalAttributes {
            var appliedAttributes: [FileAttributeKey: Any] = [:]

            if let permissions = originalAttributes[.posixPermissions] {
                appliedAttributes[.posixPermissions] = permissions
            }
            if let owner = originalAttributes[.ownerAccountID] {
                appliedAttributes[.ownerAccountID] = owner
            }
            if let group = originalAttributes[.groupOwnerAccountID] {
                appliedAttributes[.groupOwnerAccountID] = group
            }

            if !appliedAttributes.isEmpty {
                try? manager.setAttributes(appliedAttributes, ofItemAtPath: tempURL.path)
            }
        }

        if manager.fileExists(atPath: url.path) {
            _ = try manager.replaceItemAt(url, withItemAt: tempURL)
        } else {
            try manager.moveItem(at: tempURL, to: url)
        }
    }

    static func encodedData(for document: EditorDocument) throws -> Data {
        let normalizedText = document.lineEnding.applying(to: document.text)
        guard var data = normalizedText.data(using: document.encoding, allowLossyConversion: false) else {
            throw CodecError.unableToEncode(document.encoding)
        }

        if document.includesByteOrderMark, let bom = byteOrderMark(for: document.encoding) {
            data.insert(contentsOf: bom, at: 0)
        }

        return data
    }

    static func searchableText(from url: URL, maxBytes: Int) -> String? {
        guard let fileSize = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize), fileSize <= maxBytes else {
            return nil
        }

        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else {
            return nil
        }

        if isLikelyBinary(data) {
            return nil
        }

        return (try? decode(data: data).text)
    }

    private static func decode(data: Data) throws -> (text: String, encoding: String.Encoding, includesByteOrderMark: Bool) {
        if let bomMatch = decodeUsingByteOrderMark(data: data) {
            return bomMatch
        }

        let candidateEncodings: [String.Encoding] = [
            .utf8,
            .utf16LittleEndian,
            .utf16BigEndian,
            .utf32LittleEndian,
            .utf32BigEndian,
            .utf16,
            .utf32,
            .windowsCP1252,
            .isoLatin1,
            .macOSRoman,
        ]

        for encoding in candidateEncodings {
            if let string = String(data: data, encoding: encoding) {
                return (string, encoding, false)
            }
        }

        throw CodecError.unableToDecode
    }

    private static func decodeUsingByteOrderMark(data: Data) -> (text: String, encoding: String.Encoding, includesByteOrderMark: Bool)? {
        let bytes = Array(data)

        let matches: [(prefix: [UInt8], encoding: String.Encoding)] = [
            ([0x00, 0x00, 0xFE, 0xFF], .utf32BigEndian),
            ([0xFF, 0xFE, 0x00, 0x00], .utf32LittleEndian),
            ([0xEF, 0xBB, 0xBF], .utf8),
            ([0xFE, 0xFF], .utf16BigEndian),
            ([0xFF, 0xFE], .utf16LittleEndian),
        ]

        for match in matches where bytes.starts(with: match.prefix) {
            let payload = Data(bytes.dropFirst(match.prefix.count))
            if let string = String(data: payload, encoding: match.encoding) {
                return (string, match.encoding, true)
            }
        }

        return nil
    }

    private static func byteOrderMark(for encoding: String.Encoding) -> [UInt8]? {
        switch encoding {
        case .utf8:
            return [0xEF, 0xBB, 0xBF]
        case .utf16BigEndian:
            return [0xFE, 0xFF]
        case .utf16LittleEndian:
            return [0xFF, 0xFE]
        case .utf32BigEndian:
            return [0x00, 0x00, 0xFE, 0xFF]
        case .utf32LittleEndian:
            return [0xFF, 0xFE, 0x00, 0x00]
        default:
            return nil
        }
    }

    private static func isLikelyBinary(_ data: Data) -> Bool {
        guard !data.isEmpty else {
            return false
        }

        let bytes = Array(data.prefix(4_096))
        if bytes.contains(0) {
            return true
        }

        let suspiciousControlCount = bytes.reduce(into: 0) { partialResult, byte in
            if byte < 0x09 || (byte > 0x0D && byte < 0x20) {
                partialResult += 1
            }
        }

        return Double(suspiciousControlCount) / Double(bytes.count) > 0.05
    }

    private static func readPreviewData(from url: URL, maxBytes: Int, fromEnd: Bool) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }

        let size = try handle.seekToEnd()
        let requestedBytes = UInt64(maxBytes)

        if fromEnd, size > requestedBytes {
            try handle.seek(toOffset: size - requestedBytes)
        } else {
            try handle.seek(toOffset: 0)
        }

        return try handle.read(upToCount: maxBytes) ?? Data()
    }

    private static func binaryPreview(from data: Data, fileSize: Int64, isPartialPreview: Bool) -> DecodedFile {
        let preview = hexDump(from: data, truncated: isPartialPreview)
        return DecodedFile(
            text: preview,
            encoding: .utf8,
            includesByteOrderMark: false,
            lineEnding: .lf,
            isReadOnly: true,
            isPartialPreview: isPartialPreview,
            fileSize: fileSize,
            presentationMode: .binaryHex,
            preferredLanguage: .plainText,
            statusMessage: "Binary file opened as hex preview"
        )
    }

    private static func gzipPreview(from data: Data, likelyLanguage: DocumentLanguage?, statusMessage: String) throws -> DecodedFile {
        if isLikelyBinary(data) {
            return DecodedFile(
                text: hexDump(from: data, truncated: true),
                encoding: .utf8,
                includesByteOrderMark: false,
                lineEnding: .lf,
                isReadOnly: true,
                isPartialPreview: true,
                fileSize: nil,
                presentationMode: .binaryHex,
                preferredLanguage: .plainText,
                statusMessage: statusMessage
            )
        }

        let decoded = try decode(data: data)
        return DecodedFile(
            text: decoded.text,
            encoding: decoded.encoding,
            includesByteOrderMark: decoded.includesByteOrderMark,
            lineEnding: LineEnding.detect(in: decoded.text),
            isReadOnly: true,
            isPartialPreview: true,
            fileSize: nil,
            presentationMode: .readOnlyPreview,
            preferredLanguage: likelyLanguage,
            statusMessage: statusMessage
        )
    }

    private static func hexDump(from data: Data, truncated: Bool) -> String {
        let bytes = Array(data)
        let header = truncated ? "Binary preview (truncated)\n" : "Binary preview\n"
        let lines = stride(from: 0, to: bytes.count, by: 16).map { offset -> String in
            let chunk = Array(bytes[offset..<min(offset + 16, bytes.count)])
            let hexBytes = chunk.map { String(format: "%02X", $0) }.joined(separator: " ")
            let paddedHex = hexBytes.padding(toLength: 47, withPad: " ", startingAt: 0)
            let ascii = chunk.map { byte -> Character in
                if (32...126).contains(byte) {
                    return Character(UnicodeScalar(byte))
                }
                return "."
            }
            return String(format: "%08X  %@  |%@|", offset, paddedHex, String(ascii))
        }

        return header + lines.joined(separator: "\n")
    }
}
