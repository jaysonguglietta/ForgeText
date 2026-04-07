import Foundation

struct EditorDocument: Identifiable {
    let id: UUID
    var untitledName: String
    var text: String
    var fileURL: URL?
    var remoteReference: RemoteFileReference?
    var encoding: String.Encoding
    var includesByteOrderMark: Bool
    var lineEnding: LineEnding
    var selectedRange: NSRange
    var isDirty: Bool
    var lastSavedText: String
    var language: DocumentLanguage
    var findState: FindState
    var hasExternalChanges: Bool
    var fileMissingOnDisk: Bool
    var hasRecoveredDraft: Bool
    var lastKnownDiskFingerprint: DiskFingerprint?
    var lastSavedAt: Date?
    var statusMessage: String?
    var isReadOnly = false
    var isPartialPreview = false
    var fileSize: Int64?
    var presentationMode: DocumentPresentationMode = .editor
    var followModeEnabled = false
    var prefersStructuredPresentation = false

    static func untitled(named name: String) -> EditorDocument {
        EditorDocument(
            id: UUID(),
            untitledName: name,
            text: "",
            fileURL: nil,
            remoteReference: nil,
            encoding: .utf8,
            includesByteOrderMark: false,
            lineEnding: .lf,
            selectedRange: NSRange(location: 0, length: 0),
            isDirty: false,
            lastSavedText: "",
            language: .plainText,
            findState: .init(),
            hasExternalChanges: false,
            fileMissingOnDisk: false,
            hasRecoveredDraft: false,
            lastKnownDiskFingerprint: nil,
            lastSavedAt: nil,
            statusMessage: nil
        )
    }

    static func loaded(file: TextFileCodec.DecodedFile, url: URL) -> EditorDocument {
        let detectedLanguage: DocumentLanguage = {
            if file.presentationMode == .binaryHex || file.presentationMode == .archiveBrowser {
                return .plainText
            }

            return file.preferredLanguage ?? DocumentLanguage.detect(from: url, text: file.text)
        }()
        let prefersStructuredPresentation = (detectedLanguage.structuredPresentationMode != nil)
        let initialPresentationMode: DocumentPresentationMode = {
            if file.presentationMode == .binaryHex {
                return .binaryHex
            }

            if file.presentationMode == .archiveBrowser {
                return .archiveBrowser
            }

            return detectedLanguage.structuredPresentationMode ?? .editor
        }()

        return EditorDocument(
            id: UUID(),
            untitledName: url.lastPathComponent,
            text: file.text,
            fileURL: url,
            remoteReference: nil,
            encoding: file.encoding,
            includesByteOrderMark: file.includesByteOrderMark,
            lineEnding: file.lineEnding,
            selectedRange: NSRange(location: 0, length: 0),
            isDirty: false,
            lastSavedText: file.text,
            language: detectedLanguage,
            findState: .init(),
            hasExternalChanges: false,
            fileMissingOnDisk: false,
            hasRecoveredDraft: false,
            lastKnownDiskFingerprint: DiskFingerprint.capture(for: url),
            lastSavedAt: Date(),
            statusMessage: file.statusMessage,
            isReadOnly: file.isReadOnly,
            isPartialPreview: file.isPartialPreview,
            fileSize: file.fileSize,
            presentationMode: initialPresentationMode,
            followModeEnabled: false,
            prefersStructuredPresentation: prefersStructuredPresentation
        )
    }

    static func remote(reference: RemoteFileReference, text: String, encoding: String.Encoding = .utf8) -> EditorDocument {
        let language = DocumentLanguage.detect(from: URL(fileURLWithPath: reference.path), text: text)
        let prefersStructuredPresentation = language.structuredPresentationMode != nil

        return EditorDocument(
            id: UUID(),
            untitledName: reference.displayName,
            text: text,
            fileURL: nil,
            remoteReference: reference,
            encoding: encoding,
            includesByteOrderMark: false,
            lineEnding: .detect(in: text),
            selectedRange: NSRange(location: 0, length: 0),
            isDirty: false,
            lastSavedText: text,
            language: language,
            findState: .init(),
            hasExternalChanges: false,
            fileMissingOnDisk: false,
            hasRecoveredDraft: false,
            lastKnownDiskFingerprint: nil,
            lastSavedAt: Date(),
            statusMessage: "Opened remote file",
            isReadOnly: false,
            isPartialPreview: false,
            fileSize: Int64(text.utf8.count),
            presentationMode: language.structuredPresentationMode ?? .editor,
            followModeEnabled: false,
            prefersStructuredPresentation: prefersStructuredPresentation
        )
    }

    var displayName: String {
        fileURL?.lastPathComponent ?? remoteReference?.displayName ?? untitledName
    }

    var pathDescription: String {
        fileURL?.path(percentEncoded: false) ?? remoteReference?.pathDescription ?? "Unsaved document"
    }

    var isRemote: Bool {
        remoteReference != nil
    }

    var sourceURL: URL? {
        fileURL ?? remoteReference.map { URL(fileURLWithPath: $0.path) }
    }

    var availableStructuredPresentationMode: DocumentPresentationMode? {
        if let fileURL, ArchiveBrowserService.canBrowse(fileURL) {
            return .archiveBrowser
        }

        return language.structuredPresentationMode
    }

    var isLargeFileMode: Bool {
        if let fileSize, fileSize >= TextFileCodec.largeFileThreshold {
            return true
        }

        return text.utf16.count > 350_000
    }

    var statusSummary: String? {
        if fileMissingOnDisk {
            return "File missing on disk"
        }

        if hasExternalChanges {
            return "Updated outside ForgeText"
        }

        if presentationMode == .binaryHex {
            return "Binary hex preview"
        }

        if presentationMode == .archiveBrowser {
            return "Archive browser"
        }

        if isPartialPreview {
            return "Read-only preview"
        }

        return statusMessage
    }

    mutating func syncDirtyState() {
        if isReadOnly {
            isDirty = false
            return
        }

        isDirty = (text != lastSavedText)
    }

    mutating func refreshLanguageIfNeeded() {
        guard presentationMode != .binaryHex else {
            return
        }

        if let fileURL, ArchiveBrowserService.canBrowse(fileURL) {
            language = .plainText
            syncPresentationMode()
            return
        }

        let previousLanguage = language
        if sourceURL != nil || language == .plainText {
            language = DocumentLanguage.detect(from: sourceURL, text: text)
        }

        if language.structuredPresentationMode == nil {
            prefersStructuredPresentation = false
        } else if previousLanguage.structuredPresentationMode == nil, sourceURL != nil {
            prefersStructuredPresentation = true
        }

        syncPresentationMode()
    }

    mutating func syncPresentationMode() {
        guard presentationMode != .binaryHex else {
            return
        }

        if let structuredPresentationMode = availableStructuredPresentationMode, prefersStructuredPresentation {
            presentationMode = structuredPresentationMode
        } else {
            presentationMode = .editor
        }
    }
}

struct DiskFingerprint: Equatable {
    let modificationDate: Date?
    let fileSize: Int64?
    let isReachable: Bool

    static func capture(for url: URL) -> DiskFingerprint? {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]) else {
            return DiskFingerprint(modificationDate: nil, fileSize: nil, isReachable: false)
        }

        return DiskFingerprint(
            modificationDate: values.contentModificationDate,
            fileSize: values.fileSize.map(Int64.init),
            isReachable: FileManager.default.fileExists(atPath: url.path)
        )
    }
}

enum LineEnding: String, CaseIterable, Codable {
    case lf
    case crlf
    case cr

    var label: String {
        switch self {
        case .lf:
            return "LF"
        case .crlf:
            return "CRLF"
        case .cr:
            return "CR"
        }
    }

    func applying(to text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        switch self {
        case .lf:
            return normalized
        case .crlf:
            return normalized.replacingOccurrences(of: "\n", with: "\r\n")
        case .cr:
            return normalized.replacingOccurrences(of: "\n", with: "\r")
        }
    }

    static func detect(in text: String) -> LineEnding {
        let utf16View = Array(text.utf16)
        var lfCount = 0
        var crlfCount = 0
        var crCount = 0
        var index = 0

        while index < utf16View.count {
            let value = utf16View[index]

            if value == 0x000D {
                if index + 1 < utf16View.count, utf16View[index + 1] == 0x000A {
                    crlfCount += 1
                    index += 2
                } else {
                    crCount += 1
                    index += 1
                }
                continue
            }

            if value == 0x000A {
                lfCount += 1
            }

            index += 1
        }

        if crlfCount >= lfCount, crlfCount >= crCount, crlfCount > 0 {
            return .crlf
        }

        if lfCount >= crCount, lfCount > 0 {
            return .lf
        }

        if crCount > 0 {
            return .cr
        }

        return .lf
    }
}

struct EditorMetrics {
    let lineCount: Int
    let wordCount: Int
    let characterCount: Int
    let selectionLength: Int
    let cursorLine: Int
    let cursorColumn: Int

    init(text: String, selectedRange: NSRange) {
        lineCount = Self.countLines(in: text)
        wordCount = text.split { $0.isWhitespace || $0.isNewline }.count
        characterCount = text.count
        selectionLength = selectedRange.length

        let position = Self.cursorPosition(in: text, location: selectedRange.location)
        cursorLine = position.line
        cursorColumn = position.column
    }

    private static func countLines(in text: String) -> Int {
        if text.isEmpty {
            return 1
        }

        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        return normalized.reduce(into: 1) { result, character in
            if character == "\n" {
                result += 1
            }
        }
    }

    private static func cursorPosition(in text: String, location: Int) -> (line: Int, column: Int) {
        let nsText = text as NSString
        let clampedLocation = min(max(location, 0), nsText.length)
        let prefix = nsText.substring(to: clampedLocation)
        let normalizedPrefix = prefix
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")

        var line = 1
        var column = 1

        for character in normalizedPrefix {
            if character == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
        }

        return (line, column)
    }
}

extension String.Encoding {
    static let commonSaveEncodings: [String.Encoding] = [
        .utf8,
        .utf16,
        .utf16LittleEndian,
        .utf16BigEndian,
        .utf32,
        .windowsCP1252,
        .isoLatin1,
        .macOSRoman,
    ]

    var displayName: String {
        switch self {
        case .utf8:
            return "UTF-8"
        case .utf16:
            return "UTF-16"
        case .utf16LittleEndian:
            return "UTF-16 LE"
        case .utf16BigEndian:
            return "UTF-16 BE"
        case .utf32:
            return "UTF-32"
        case .utf32LittleEndian:
            return "UTF-32 LE"
        case .utf32BigEndian:
            return "UTF-32 BE"
        case .windowsCP1252:
            return "Windows-1252"
        case .isoLatin1:
            return "ISO Latin 1"
        case .macOSRoman:
            return "Mac OS Roman"
        default:
            return "Text Encoding \(rawValue)"
        }
    }
}
