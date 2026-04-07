import Foundation

enum LogSeverity: String, CaseIterable, Codable, Identifiable {
    case trace
    case debug
    case info
    case notice
    case warning
    case error
    case critical
    case unknown

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .trace:
            return "Trace"
        case .debug:
            return "Debug"
        case .info:
            return "Info"
        case .notice:
            return "Notice"
        case .warning:
            return "Warning"
        case .error:
            return "Error"
        case .critical:
            return "Critical"
        case .unknown:
            return "Unknown"
        }
    }

    var rank: Int {
        switch self {
        case .trace:
            return 0
        case .debug:
            return 1
        case .info:
            return 2
        case .notice:
            return 3
        case .warning:
            return 4
        case .error:
            return 5
        case .critical:
            return 6
        case .unknown:
            return -1
        }
    }

    static func from(token: String) -> LogSeverity {
        switch token.uppercased() {
        case "TRACE":
            return .trace
        case "DEBUG":
            return .debug
        case "INFO":
            return .info
        case "NOTICE":
            return .notice
        case "WARN", "WARNING":
            return .warning
        case "ERROR":
            return .error
        case "FATAL", "CRITICAL":
            return .critical
        default:
            return .unknown
        }
    }
}

struct LogMetadataField: Identifiable, Hashable {
    let id: String
    let key: String
    let value: String
}

struct LogEntry: Identifiable, Hashable {
    let id: String
    let lineNumber: Int
    let timestamp: String?
    let timestampDate: Date?
    let severity: LogSeverity
    let source: String?
    let message: String
    let details: [String]
    let metadata: [LogMetadataField]
    let rawText: String
}

struct LogDocument {
    let entries: [LogEntry]
    let severityCounts: [LogSeverity: Int]
    let timestampedEntryCount: Int

    var entryCount: Int {
        entries.count
    }

    var warningCount: Int {
        severityCounts[.warning, default: 0]
    }

    var errorCount: Int {
        severityCounts[.error, default: 0] + severityCounts[.critical, default: 0]
    }
}

enum LogExplorerService {
    static func parse(_ text: String, requireLogSignals: Bool = false) -> LogDocument? {
        let lines = normalizedLines(in: text)
        guard lines.contains(where: { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else {
            return nil
        }

        var entries: [LogEntry] = []
        var signalCount = 0
        var timestampedEntryCount = 0

        for (index, line) in lines.enumerated() {
            let lineNumber = index + 1
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)

            if let parsedLine = parseEntryLine(line, lineNumber: lineNumber) {
                entries.append(parsedLine.entry)
                if parsedLine.hasStrongSignal {
                    signalCount += 1
                }
                if parsedLine.entry.timestamp != nil {
                    timestampedEntryCount += 1
                }
                continue
            }

            if shouldAppendAsContinuation(line), !entries.isEmpty {
                var lastEntry = entries.removeLast()
                let updatedDetails = lastEntry.details + [trimmedLine.isEmpty ? line : trimmedLine]
                let updatedRawText = lastEntry.rawText + "\n" + line
                lastEntry = LogEntry(
                    id: lastEntry.id,
                    lineNumber: lastEntry.lineNumber,
                    timestamp: lastEntry.timestamp,
                    timestampDate: lastEntry.timestampDate,
                    severity: lastEntry.severity,
                    source: lastEntry.source,
                    message: lastEntry.message,
                    details: updatedDetails,
                    metadata: lastEntry.metadata,
                    rawText: updatedRawText
                )
                entries.append(lastEntry)
                continue
            }

            guard !trimmedLine.isEmpty else {
                continue
            }

            entries.append(
                LogEntry(
                    id: "line-\(lineNumber)",
                    lineNumber: lineNumber,
                    timestamp: nil,
                    timestampDate: nil,
                    severity: .unknown,
                    source: nil,
                    message: trimmedLine,
                    details: [],
                    metadata: [],
                    rawText: line
                )
            )
        }

        if requireLogSignals, signalCount < max(2, min(4, lines.count / 4)) {
            return nil
        }

        guard !entries.isEmpty else {
            return nil
        }

        let severityCounts = Dictionary(entries.map { ($0.severity, 1) }, uniquingKeysWith: +)
        return LogDocument(entries: entries, severityCounts: severityCounts, timestampedEntryCount: timestampedEntryCount)
    }

    private static func normalizedLines(in text: String) -> [String] {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return normalized.components(separatedBy: "\n")
    }

    private static func parseEntryLine(_ line: String, lineNumber: Int) -> (entry: LogEntry, hasStrongSignal: Bool)? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLine.isEmpty else {
            return nil
        }

        var working = trimmedLine
        let timestamp = extractTimestamp(from: &working)
        let severity = extractSeverity(from: &working)
        let source = extractSource(from: &working)
        let metadata = extractMetadata(from: working)
        let message = cleanedMessage(from: working)

        let hasStrongSignal = timestamp != nil || severity != .unknown || source != nil || !metadata.isEmpty
        guard hasStrongSignal else {
            return nil
        }

        let finalMessage = message.isEmpty ? trimmedLine : message
        let id = "line-\(lineNumber)-\(severity.rawValue)-\(timestamp ?? "no-ts")"
        let timestampDate = parseDate(from: timestamp)
        return (
            LogEntry(
                id: id,
                lineNumber: lineNumber,
                timestamp: timestamp,
                timestampDate: timestampDate,
                severity: severity,
                source: source,
                message: finalMessage,
                details: [],
                metadata: metadata,
                rawText: line
            ),
            hasStrongSignal
        )
    }

    private static func extractTimestamp(from text: inout String) -> String? {
        let patterns = [
            #"^\d{4}-\d{2}-\d{2}[ T]\d{2}:\d{2}:\d{2}(?:[.,]\d+)?(?:Z|[+-]\d{2}:?\d{2})?"#,
            #"^[A-Z][a-z]{2}\s+\d{1,2}\s+\d{2}:\d{2}:\d{2}"#,
            #"^\d{2}:\d{2}:\d{2}(?:[.,]\d+)?"#,
        ]

        for pattern in patterns {
            guard let match = firstMatch(pattern: pattern, in: text) else {
                continue
            }

            let timestamp = matchedString(in: text, range: match.range)
            text = stripPrefix(match.range, from: text)
            return timestamp
        }

        return nil
    }

    private static func extractSeverity(from text: inout String) -> LogSeverity {
        let patterns = [
            #"^(?:\[(TRACE|DEBUG|INFO|NOTICE|WARN|WARNING|ERROR|FATAL|CRITICAL)\])"#,
            #"^(TRACE|DEBUG|INFO|NOTICE|WARN|WARNING|ERROR|FATAL|CRITICAL)\b"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }

            let range = NSRange(location: 0, length: (text as NSString).length)
            guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 else {
                continue
            }

            let token = matchedString(in: text, range: match.range(at: 1))
            text = stripPrefix(match.range, from: text)
            return LogSeverity.from(token: token)
        }

        return .unknown
    }

    private static func extractSource(from text: inout String) -> String? {
        let patterns = [
            #"^\[([^\]]+)\]"#,
            #"^([A-Za-z0-9_.-]+):"#,
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                continue
            }

            let range = NSRange(location: 0, length: (text as NSString).length)
            guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1 else {
                continue
            }

            let source = matchedString(in: text, range: match.range(at: 1))
            if source.caseInsensitiveCompare(LogSeverity.from(token: source).displayName) == .orderedSame {
                continue
            }

            text = stripPrefix(match.range, from: text)
            return source
        }

        if let componentField = extractMetadataField(named: "component", from: text) ?? extractMetadataField(named: "service", from: text) ?? extractMetadataField(named: "module", from: text) {
            return componentField
        }

        return nil
    }

    private static func extractMetadata(from text: String) -> [LogMetadataField] {
        guard let regex = try? NSRegularExpression(pattern: #"\b([A-Za-z_][A-Za-z0-9_.-]{1,31})=(\"[^\"]*\"|\S+)"#) else {
            return []
        }

        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.matches(in: text, range: range).enumerated().compactMap { index, match in
            guard match.numberOfRanges > 2 else {
                return nil
            }

            let key = matchedString(in: text, range: match.range(at: 1))
            let rawValue = matchedString(in: text, range: match.range(at: 2))
            let value = rawValue.trimmingCharacters(in: CharacterSet(charactersIn: "\""))
            return LogMetadataField(id: "\(index)-\(key)", key: key, value: value)
        }
    }

    private static func extractMetadataField(named name: String, from text: String) -> String? {
        extractMetadata(from: text).first(where: { $0.key.caseInsensitiveCompare(name) == .orderedSame })?.value
    }

    private static func cleanedMessage(from text: String) -> String {
        var cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: #"^[\-\:\|]+"#, with: "", options: .regularExpression)
        cleaned = cleaned.replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func shouldAppendAsContinuation(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedLine.isEmpty else {
            return false
        }

        if line.hasPrefix(" ") || line.hasPrefix("\t") {
            return true
        }

        let prefixes = ["at ", "Caused by:", "Traceback", "File \"", "... "]
        return prefixes.contains { trimmedLine.hasPrefix($0) }
    }

    private static func stripPrefix(_ range: NSRange, from text: String) -> String {
        let nsText = text as NSString
        let suffixRange = NSRange(location: range.location + range.length, length: max(0, nsText.length - range.location - range.length))
        let stripped = nsText.substring(with: suffixRange)
        return stripped.trimmingCharacters(in: CharacterSet(charactersIn: " \t:-|"))
    }

    private static func matchedString(in text: String, range: NSRange) -> String {
        (text as NSString).substring(with: range)
    }

    private static func firstMatch(pattern: String, in text: String) -> NSTextCheckingResult? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }

        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.firstMatch(in: text, range: range)
    }

    private static func parseDate(from timestamp: String?) -> Date? {
        guard let timestamp else {
            return nil
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: timestamp) {
            return date
        }

        let fallbackISOFormatter = ISO8601DateFormatter()
        fallbackISOFormatter.formatOptions = [.withInternetDateTime]
        if let date = fallbackISOFormatter.date(from: timestamp.replacingOccurrences(of: ",", with: ".")) {
            return date
        }

        let locale = Locale(identifier: "en_US_POSIX")

        let syslogFormatter = DateFormatter()
        syslogFormatter.locale = locale
        syslogFormatter.dateFormat = "MMM d HH:mm:ss"
        if let date = syslogFormatter.date(from: timestamp) {
            let calendar = Calendar.current
            let currentYear = calendar.component(.year, from: Date())
            return calendar.date(bySetting: .year, value: currentYear, of: date)
        }

        let timeOnlyFormatter = DateFormatter()
        timeOnlyFormatter.locale = locale
        timeOnlyFormatter.dateFormat = "HH:mm:ss"
        if let date = timeOnlyFormatter.date(from: timestamp.replacingOccurrences(of: ",", with: ".")) {
            return Calendar.current.date(
                bySettingHour: Calendar.current.component(.hour, from: date),
                minute: Calendar.current.component(.minute, from: date),
                second: Calendar.current.component(.second, from: date),
                of: Date()
            )
        }

        return nil
    }
}
