import Foundation

struct ContentLengthMessageFramer: Sendable {
    enum FramingError: LocalizedError, Equatable {
        case headerTooLarge
        case malformedHeader
        case invalidContentLength
        case messageTooLarge(Int)

        var errorDescription: String? {
            switch self {
            case .headerTooLarge:
                return "The protocol header exceeded the safety limit."
            case .malformedHeader:
                return "The protocol message header is malformed."
            case .invalidContentLength:
                return "The protocol message has an invalid Content-Length header."
            case let .messageTooLarge(length):
                return "The protocol message size of \(length) bytes exceeds the safety limit."
            }
        }
    }

    private static let delimiter = Data("\r\n\r\n".utf8)
    private let maximumHeaderBytes: Int
    private let maximumMessageBytes: Int
    private var buffer = Data()

    init(maximumHeaderBytes: Int = 16 * 1_024, maximumMessageBytes: Int = 8 * 1_024 * 1_024) {
        self.maximumHeaderBytes = maximumHeaderBytes
        self.maximumMessageBytes = maximumMessageBytes
    }

    mutating func append(_ data: Data) throws -> [Data] {
        buffer.append(data)
        var messages: [Data] = []

        while true {
            guard let delimiterRange = buffer.range(of: Self.delimiter) else {
                if buffer.count > maximumHeaderBytes {
                    throw FramingError.headerTooLarge
                }
                return messages
            }

            guard delimiterRange.lowerBound <= maximumHeaderBytes else {
                throw FramingError.headerTooLarge
            }

            let headerData = Data(buffer[..<delimiterRange.lowerBound])
            guard let header = String(data: headerData, encoding: .utf8) else {
                throw FramingError.malformedHeader
            }

            let contentLengthValues = header
                .components(separatedBy: "\r\n")
                .compactMap { line -> Int? in
                    let fields = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                    guard fields.count == 2,
                          fields[0].trimmingCharacters(in: .whitespaces).caseInsensitiveCompare("Content-Length") == .orderedSame
                    else {
                        return nil
                    }
                    return Int(fields[1].trimmingCharacters(in: .whitespaces))
                }

            guard contentLengthValues.count == 1, let contentLength = contentLengthValues.first, contentLength >= 0 else {
                throw FramingError.invalidContentLength
            }
            guard contentLength <= maximumMessageBytes else {
                throw FramingError.messageTooLarge(contentLength)
            }

            let bodyStart = delimiterRange.upperBound
            let bodyEnd = bodyStart + contentLength
            guard buffer.count >= bodyEnd else {
                return messages
            }

            messages.append(buffer.subdata(in: bodyStart..<bodyEnd))
            buffer.removeSubrange(0..<bodyEnd)
        }
    }

    static func frame(_ payload: Data, maximumMessageBytes: Int = 8 * 1_024 * 1_024) throws -> Data {
        guard payload.count <= maximumMessageBytes else {
            throw FramingError.messageTooLarge(payload.count)
        }
        var framed = Data("Content-Length: \(payload.count)\r\n\r\n".utf8)
        framed.append(payload)
        return framed
    }
}

final class SupervisedProtocolProcess: @unchecked Sendable {
    enum RuntimeError: LocalizedError {
        case alreadyRunning
        case notRunning
        case unsafeExecutable
        case launchFailed(String)
        case invalidResponse
        case timedOut(method: String)
        case processTerminated(Int32)
        case protocolFailure(String)

        var errorDescription: String? {
            switch self {
            case .alreadyRunning:
                return "The protocol process is already running."
            case .notRunning:
                return "The protocol process is not running."
            case .unsafeExecutable:
                return "The protocol executable is outside ForgeText's trusted tool locations."
            case let .launchFailed(message):
                return "The protocol process could not start: \(message)"
            case .invalidResponse:
                return "The protocol process returned an invalid response."
            case let .timedOut(method):
                return "The protocol request '\(method)' timed out."
            case let .processTerminated(status):
                return "The protocol process exited with status \(status)."
            case let .protocolFailure(message):
                return message
            }
        }
    }

    private final class PendingResponse: @unchecked Sendable {
        let semaphore = DispatchSemaphore(value: 0)
        var result: Result<[String: Any], Error>?
    }

    private let lock = NSLock()
    private var process: Process?
    private var inputHandle: FileHandle?
    private var outputHandle: FileHandle?
    private var errorHandle: FileHandle?
    private var framer = ContentLengthMessageFramer()
    private var nextIdentifier = 1
    private var pendingResponses: [Int: PendingResponse] = [:]
    private var recentErrorOutput = Data()
    private var notificationHandler: (([String: Any]) -> Void)?
    private let maximumErrorBytes = 512 * 1_024

    var isRunning: Bool {
        lock.withLock { process?.isRunning == true }
    }

    func setNotificationHandler(_ handler: (([String: Any]) -> Void)?) {
        lock.withLock { notificationHandler = handler }
    }

    func start(executablePath: String, arguments: [String], workspaceRoot: URL?) throws {
        let executableURL = URL(fileURLWithPath: executablePath).resolvingSymlinksInPath().standardizedFileURL
        guard ToolchainService.isTrustedAbsoluteExecutablePath(executableURL.path)
        else {
            throw RuntimeError.unsafeExecutable
        }

        lock.lock()
        guard process?.isRunning != true else {
            lock.unlock()
            throw RuntimeError.alreadyRunning
        }
        lock.unlock()

        let process = Process()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = workspaceRoot?.standardizedFileURL
        process.environment = Self.sanitizedEnvironment()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        process.terminationHandler = { [weak self] terminatedProcess in
            self?.handleTermination(status: terminatedProcess.terminationStatus)
        }

        outputPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.consume(data)
        }
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            self?.consumeError(data)
        }

        do {
            try process.run()
        } catch {
            outputPipe.fileHandleForReading.readabilityHandler = nil
            errorPipe.fileHandleForReading.readabilityHandler = nil
            throw RuntimeError.launchFailed(error.localizedDescription)
        }

        lock.withLock {
            self.process = process
            inputHandle = inputPipe.fileHandleForWriting
            outputHandle = outputPipe.fileHandleForReading
            errorHandle = errorPipe.fileHandleForReading
            framer = ContentLengthMessageFramer()
            recentErrorOutput = Data()
        }
    }

    func request(method: String, params: Any, timeout: TimeInterval = 8) throws -> [String: Any] {
        let identifier = reserveIdentifier()
        let envelope: [String: Any] = [
            "jsonrpc": "2.0",
            "id": identifier,
            "method": method,
            "params": params,
        ]
        return try request(envelope: envelope, identifier: identifier, method: method, timeout: timeout)
    }

    func requestDAP(command: String, arguments: Any, timeout: TimeInterval = 8) throws -> [String: Any] {
        let identifier = reserveIdentifier()
        let envelope: [String: Any] = [
            "seq": identifier,
            "type": "request",
            "command": command,
            "arguments": arguments,
        ]
        return try request(envelope: envelope, identifier: identifier, method: command, timeout: timeout)
    }

    func notify(method: String, params: Any) throws {
        try send([
            "jsonrpc": "2.0",
            "method": method,
            "params": params,
        ])
    }

    func stop() {
        let runningProcess: Process? = lock.withLock {
            let value = process
            process = nil
            inputHandle = nil
            outputHandle?.readabilityHandler = nil
            errorHandle?.readabilityHandler = nil
            outputHandle = nil
            errorHandle = nil
            return value
        }

        if runningProcess?.isRunning == true {
            runningProcess?.terminate()
        }
        failPending(with: RuntimeError.notRunning)
    }

    private func request(
        envelope: [String: Any],
        identifier: Int,
        method: String,
        timeout: TimeInterval
    ) throws -> [String: Any] {
        let pending = PendingResponse()
        lock.withLock { pendingResponses[identifier] = pending }

        do {
            try send(envelope)
        } catch {
            _ = lock.withLock { pendingResponses.removeValue(forKey: identifier) }
            throw error
        }

        guard pending.semaphore.wait(timeout: .now() + timeout) == .success else {
            _ = lock.withLock { pendingResponses.removeValue(forKey: identifier) }
            try? notify(method: "$/cancelRequest", params: ["id": identifier])
            throw RuntimeError.timedOut(method: method)
        }

        guard let result = pending.result else {
            throw RuntimeError.invalidResponse
        }
        let response = try result.get()
        if let error = response["error"] as? [String: Any] {
            let message = error["message"] as? String ?? "The protocol request failed."
            throw RuntimeError.protocolFailure(message)
        }
        if response["success"] as? Bool == false {
            throw RuntimeError.protocolFailure(response["message"] as? String ?? "The debug adapter request failed.")
        }
        return response
    }

    private func reserveIdentifier() -> Int {
        lock.withLock {
            defer { nextIdentifier += 1 }
            return nextIdentifier
        }
    }

    private func send(_ envelope: [String: Any]) throws {
        guard JSONSerialization.isValidJSONObject(envelope) else {
            throw RuntimeError.invalidResponse
        }
        let payload = try JSONSerialization.data(withJSONObject: envelope)
        let framed = try ContentLengthMessageFramer.frame(payload)
        let handle = lock.withLock { inputHandle }
        guard let handle, isRunning else {
            throw RuntimeError.notRunning
        }
        try handle.write(contentsOf: framed)
    }

    private func consume(_ data: Data) {
        let messages: [Data]
        do {
            messages = try lock.withLock { try framer.append(data) }
        } catch {
            failPending(with: error)
            stop()
            return
        }

        for message in messages {
            guard let object = try? JSONSerialization.jsonObject(with: message) as? [String: Any] else {
                continue
            }
            let identifier = Self.integer(object["id"]) ?? Self.integer(object["request_seq"])
            if let identifier {
                let pending = lock.withLock { pendingResponses.removeValue(forKey: identifier) }
                if let pending {
                    pending.result = .success(object)
                    pending.semaphore.signal()
                    continue
                }
                if let method = object["method"] as? String {
                    respondSafely(toServerRequest: identifier, method: method)
                }
            }
            if object["method"] != nil {
                let handler = lock.withLock { notificationHandler }
                handler?(object)
            }
        }
    }

    private func respondSafely(toServerRequest identifier: Int, method: String) {
        let result: Any
        switch method {
        case "workspace/configuration":
            result = []
        case "workspace/workspaceFolders":
            result = NSNull()
        case "workspace/applyEdit":
            result = ["applied": false, "failureReason": "ForgeText requires explicit edit review."]
        default:
            result = NSNull()
        }
        try? send(["jsonrpc": "2.0", "id": identifier, "result": result])
    }

    private func consumeError(_ data: Data) {
        lock.withLock {
            let remaining = max(0, maximumErrorBytes - recentErrorOutput.count)
            recentErrorOutput.append(data.prefix(remaining))
        }
    }

    private func handleTermination(status: Int32) {
        lock.withLock {
            process = nil
            inputHandle = nil
        }
        failPending(with: RuntimeError.processTerminated(status))
    }

    private func failPending(with error: Error) {
        let pending: [PendingResponse] = lock.withLock {
            let values = Array(pendingResponses.values)
            pendingResponses.removeAll()
            return values
        }
        for response in pending {
            response.result = .failure(error)
            response.semaphore.signal()
        }
    }

    private static func integer(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private static func sanitizedEnvironment() -> [String: String] {
        let source = ProcessInfo.processInfo.environment
        let allowedKeys = ["HOME", "LANG", "LC_ALL", "TMPDIR", "DEVELOPER_DIR", "SDKROOT"]
        var environment = allowedKeys.reduce(into: [String: String]()) { result, key in
            result[key] = source[key]
        }
        environment["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin:/opt/homebrew/bin:/Applications/Xcode.app/Contents/Developer/usr/bin"
        environment["NO_COLOR"] = "1"
        environment["GIT_TERMINAL_PROMPT"] = "0"
        return environment
    }
}

private final class LanguageRuntimeStore: @unchecked Sendable {
    let lock = NSLock()
    var sessions: [String: SupervisedProtocolProcess] = [:]
    var documentVersions: [String: [String: Int]] = [:]
}

enum LanguageProtocolRuntimeService {
    enum SessionError: LocalizedError {
        case unavailable
        case noWorkspace

        var errorDescription: String? {
            switch self {
            case .unavailable: return "The selected language server is not available from a trusted tool location."
            case .noWorkspace: return "Open a workspace folder before starting language intelligence."
            }
        }
    }

    private static let store = LanguageRuntimeStore()

    static func start(
        server: LanguageServerStatus,
        workspaceRoot: URL?,
        notificationHandler: ((String, [String: Any]) -> Void)? = nil
    ) throws -> LanguageProtocolSessionStatus {
        guard let workspaceRoot else { throw SessionError.noWorkspace }
        guard server.availability == .ready, let executablePath = server.resolvedPath else {
            throw SessionError.unavailable
        }

        stop(serverID: server.id)
        let process = SupervisedProtocolProcess()
        process.setNotificationHandler { message in
            notificationHandler?(server.id, message)
        }
        try process.start(
            executablePath: executablePath,
            arguments: arguments(for: server.id),
            workspaceRoot: workspaceRoot
        )

        do {
            let response = try process.request(
                method: "initialize",
                params: [
                    "processId": ProcessInfo.processInfo.processIdentifier,
                    "clientInfo": ["name": "ForgeText", "version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"],
                    "rootUri": workspaceRoot.absoluteString,
                    "capabilities": [
                        "textDocument": [
                            "completion": ["completionItem": ["snippetSupport": false]],
                            "definition": [:],
                            "references": [:],
                            "rename": [:],
                            "codeAction": [:],
                            "publishDiagnostics": ["relatedInformation": true],
                            "synchronization": ["dynamicRegistration": false, "willSave": false, "didSave": true],
                        ],
                        "workspace": ["workspaceFolders": true],
                    ],
                    "workspaceFolders": [["uri": workspaceRoot.absoluteString, "name": workspaceRoot.lastPathComponent]],
                ],
                timeout: 10
            )
            try process.notify(method: "initialized", params: [:])
            store.lock.withLock {
                store.sessions[server.id] = process
                store.documentVersions[server.id] = [:]
            }

            let capabilities = ((response["result"] as? [String: Any])?["capabilities"] as? [String: Any])?.keys.sorted() ?? []
            return LanguageProtocolSessionStatus(
                serverID: server.id,
                state: .running,
                startedAt: Date(),
                negotiatedCapabilities: capabilities,
                lastError: nil
            )
        } catch {
            process.stop()
            throw error
        }
    }

    static func stop(serverID: String) {
        let process = store.lock.withLock {
            store.documentVersions.removeValue(forKey: serverID)
            return store.sessions.removeValue(forKey: serverID)
        }
        guard let process else { return }
        _ = try? process.request(method: "shutdown", params: NSNull(), timeout: 2)
        try? process.notify(method: "exit", params: [:])
        process.stop()
    }

    static func stopAll() {
        let identifiers = store.lock.withLock { Array(store.sessions.keys) }
        identifiers.forEach(stop(serverID:))
    }

    static func terminateAllImmediately() {
        let processes = store.lock.withLock {
            let values = Array(store.sessions.values)
            store.sessions.removeAll()
            store.documentVersions.removeAll()
            return values
        }
        processes.forEach { $0.stop() }
    }

    static func isRunning(serverID: String) -> Bool {
        store.lock.withLock { store.sessions[serverID]?.isRunning == true }
    }

    static func openDocument(
        serverID: String,
        uri: String,
        languageID: String,
        text: String
    ) throws {
        let process = try runningProcess(serverID: serverID)
        try process.notify(
            method: "textDocument/didOpen",
            params: [
                "textDocument": [
                    "uri": uri,
                    "languageId": languageID,
                    "version": 1,
                    "text": text,
                ],
            ]
        )
        store.lock.withLock { store.documentVersions[serverID, default: [:]][uri] = 1 }
    }

    static func changeDocument(serverID: String, uri: String, text: String) throws {
        let process = try runningProcess(serverID: serverID)
        let version = store.lock.withLock { () -> Int in
            let next = (store.documentVersions[serverID]?[uri] ?? 0) + 1
            store.documentVersions[serverID, default: [:]][uri] = next
            return next
        }
        try process.notify(
            method: "textDocument/didChange",
            params: [
                "textDocument": ["uri": uri, "version": version],
                "contentChanges": [["text": text]],
            ]
        )
    }

    static func synchronizeDocument(
        serverID: String,
        uri: String,
        languageID: String,
        text: String
    ) throws {
        let isOpen = store.lock.withLock { store.documentVersions[serverID]?[uri] != nil }
        if isOpen {
            try changeDocument(serverID: serverID, uri: uri, text: text)
        } else {
            try openDocument(serverID: serverID, uri: uri, languageID: languageID, text: text)
        }
    }

    static func saveDocument(serverID: String, uri: String, text: String? = nil) throws {
        let process = try runningProcess(serverID: serverID)
        var params: [String: Any] = ["textDocument": ["uri": uri]]
        if let text { params["text"] = text }
        try process.notify(method: "textDocument/didSave", params: params)
    }

    static func closeDocument(serverID: String, uri: String) throws {
        let isOpen = store.lock.withLock { store.documentVersions[serverID]?[uri] != nil }
        guard isOpen else { return }
        let process = try runningProcess(serverID: serverID)
        try process.notify(method: "textDocument/didClose", params: ["textDocument": ["uri": uri]])
        store.lock.withLock { store.documentVersions[serverID]?[uri] = nil }
    }

    static func completions(
        serverID: String,
        uri: String,
        position: LanguageTextPosition
    ) throws -> [LanguageProtocolCompletion] {
        let response = try textDocumentRequest(serverID: serverID, method: "textDocument/completion", uri: uri, position: position)
        let result = response["result"]
        let records = result as? [[String: Any]] ?? (result as? [String: Any])?["items"] as? [[String: Any]] ?? []
        return records.prefix(500).enumerated().compactMap { index, record in
            guard let label = record["label"] as? String else { return nil }
            return LanguageProtocolCompletion(
                id: "\(index)-\(label)",
                label: label,
                detail: record["detail"] as? String,
                insertText: record["insertText"] as? String,
                kind: Self.integer(record["kind"])
            )
        }
    }

    static func locations(
        serverID: String,
        method: String,
        uri: String,
        position: LanguageTextPosition
    ) throws -> [LanguageProtocolLocation] {
        var params: [String: Any] = [
            "textDocument": ["uri": uri],
            "position": position.dictionary,
        ]
        if method == "textDocument/references" {
            params["context"] = ["includeDeclaration": true]
        }
        let response = try runningProcess(serverID: serverID).request(method: method, params: params, timeout: 8)
        let records: [[String: Any]]
        if let values = response["result"] as? [[String: Any]] {
            records = values
        } else if let value = response["result"] as? [String: Any] {
            records = [value]
        } else {
            records = []
        }
        return records.prefix(1_000).compactMap(location(from:))
    }

    static func codeActions(
        serverID: String,
        uri: String,
        range: LanguageTextRange,
        diagnostics: [LanguageProtocolDiagnostic]
    ) throws -> [LanguageProtocolCodeAction] {
        let process = try runningProcess(serverID: serverID)
        let response = try process.request(
            method: "textDocument/codeAction",
            params: [
                "textDocument": ["uri": uri],
                "range": range.dictionary,
                "context": ["diagnostics": diagnostics.map(\.dictionary)],
            ],
            timeout: 8
        )
        let records = response["result"] as? [[String: Any]] ?? []
        return records.prefix(200).enumerated().compactMap { index, record in
            guard let title = record["title"] as? String else { return nil }
            let command = (record["command"] as? [String: Any])?["command"] as? String
                ?? record["command"] as? String
            let edits = workspaceEdits(from: record["edit"])
            return LanguageProtocolCodeAction(
                id: "\(index)-\(title)",
                title: title,
                kind: record["kind"] as? String,
                isPreferred: record["isPreferred"] as? Bool ?? false,
                command: command,
                edits: edits
            )
        }
    }

    static func rename(
        serverID: String,
        uri: String,
        position: LanguageTextPosition,
        newName: String
    ) throws -> [LanguageProtocolTextEdit] {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, trimmedName.count <= 512 else { return [] }
        let response = try runningProcess(serverID: serverID).request(
            method: "textDocument/rename",
            params: [
                "textDocument": ["uri": uri],
                "position": position.dictionary,
                "newName": trimmedName,
            ],
            timeout: 10
        )
        guard let result = response["result"] as? [String: Any],
              let changes = result["changes"] as? [String: [[String: Any]]]
        else { return [] }
        return changes.flatMap { documentURI, records in
            records.compactMap { record in
                guard let range = Self.range(from: record["range"]), let newText = record["newText"] as? String else { return nil }
                return LanguageProtocolTextEdit(documentURI: documentURI, range: range, newText: newText)
            }
        }.prefix(5_000).map { $0 }
    }

    static func diagnostics(serverID: String, notification: [String: Any]) -> [LanguageProtocolDiagnostic]? {
        guard notification["method"] as? String == "textDocument/publishDiagnostics",
              let params = notification["params"] as? [String: Any],
              let uri = params["uri"] as? String,
              let records = params["diagnostics"] as? [[String: Any]]
        else { return nil }
        return records.prefix(2_000).enumerated().compactMap { index, record in
            guard let range = range(from: record["range"]), let message = record["message"] as? String else { return nil }
            return LanguageProtocolDiagnostic(
                id: "\(serverID)-\(uri)-\(index)-\(range.start.line)-\(range.start.character)",
                serverID: serverID,
                documentURI: uri,
                range: range,
                severity: integer(record["severity"]) ?? 3,
                message: String(message.prefix(8_000)),
                source: record["source"] as? String
            )
        }
    }

    private static func textDocumentRequest(
        serverID: String,
        method: String,
        uri: String,
        position: LanguageTextPosition
    ) throws -> [String: Any] {
        try runningProcess(serverID: serverID).request(
            method: method,
            params: ["textDocument": ["uri": uri], "position": position.dictionary],
            timeout: 8
        )
    }

    private static func runningProcess(serverID: String) throws -> SupervisedProtocolProcess {
        guard let process = store.lock.withLock({ store.sessions[serverID] }), process.isRunning else {
            throw SupervisedProtocolProcess.RuntimeError.notRunning
        }
        return process
    }

    private static func location(from record: [String: Any]) -> LanguageProtocolLocation? {
        let uri = record["uri"] as? String ?? record["targetUri"] as? String
        let rangeValue = record["range"] ?? record["targetSelectionRange"] ?? record["targetRange"]
        guard let uri, let range = range(from: rangeValue) else { return nil }
        return LanguageProtocolLocation(documentURI: uri, range: range)
    }

    private static func workspaceEdits(from value: Any?) -> [LanguageProtocolTextEdit] {
        guard let edit = value as? [String: Any],
              let changes = edit["changes"] as? [String: [[String: Any]]]
        else { return [] }
        return changes.flatMap { documentURI, records in
            records.compactMap { record in
                guard let range = range(from: record["range"]), let newText = record["newText"] as? String else { return nil }
                return LanguageProtocolTextEdit(documentURI: documentURI, range: range, newText: newText)
            }
        }.prefix(5_000).map { $0 }
    }

    private static func range(from value: Any?) -> LanguageTextRange? {
        guard let record = value as? [String: Any],
              let start = position(from: record["start"]),
              let end = position(from: record["end"])
        else { return nil }
        return LanguageTextRange(start: start, end: end)
    }

    private static func position(from value: Any?) -> LanguageTextPosition? {
        guard let record = value as? [String: Any],
              let line = integer(record["line"]),
              let character = integer(record["character"]),
              line >= 0, character >= 0
        else { return nil }
        return LanguageTextPosition(line: line, character: character)
    }

    private static func integer(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        return (value as? NSNumber)?.intValue
    }

    private static func arguments(for serverID: String) -> [String] {
        switch serverID {
        case "typescript-language-server", "pyright-langserver", "vscode-json-language-server":
            return ["--stdio"]
        case "bash-language-server":
            return ["start"]
        default:
            return []
        }
    }
}

private extension LanguageTextPosition {
    var dictionary: [String: Any] {
        ["line": line, "character": character]
    }
}

private extension LanguageTextRange {
    var dictionary: [String: Any] {
        ["start": start.dictionary, "end": end.dictionary]
    }
}

private extension LanguageProtocolDiagnostic {
    var dictionary: [String: Any] {
        var result: [String: Any] = [
            "range": range.dictionary,
            "severity": severity,
            "message": message,
        ]
        if let source { result["source"] = source }
        return result
    }
}

enum DebugAdapterDiscoveryService {
    private static let specs: [(id: String, name: String, executable: String, languages: [DocumentLanguage])] = [
        ("lldb-dap", "LLDB Debug Adapter", "lldb-dap", [.swift]),
        ("debugpy-adapter", "Python Debug Adapter", "debugpy-adapter", [.python]),
    ]

    static func statuses(isEnabled: Bool) -> [DebugAdapterStatus] {
        specs.map { spec in
            guard isEnabled else {
                return DebugAdapterStatus(id: spec.id, displayName: spec.name, languages: spec.languages, availability: .disabled, resolvedPath: nil)
            }
            let path = ToolchainService.trustedExecutablePath(named: spec.executable)
            return DebugAdapterStatus(
                id: spec.id,
                displayName: spec.name,
                languages: spec.languages,
                availability: path == nil ? .unavailable : .ready,
                resolvedPath: path
            )
        }
    }

    static func probe(_ adapter: DebugAdapterStatus, workspaceRoot: URL?) throws -> DebugAdapterProbeResult {
        guard adapter.availability == .ready, let executablePath = adapter.resolvedPath else {
            throw SupervisedProtocolProcess.RuntimeError.unsafeExecutable
        }
        let process = SupervisedProtocolProcess()
        try process.start(executablePath: executablePath, arguments: [], workspaceRoot: workspaceRoot)
        defer { process.stop() }
        let response = try process.requestDAP(
            command: "initialize",
            arguments: [
                "clientID": "forgetext",
                "clientName": "ForgeText",
                "adapterID": adapter.id,
                "pathFormat": "path",
                "linesStartAt1": true,
                "columnsStartAt1": true,
                "supportsRunInTerminalRequest": false,
            ],
            timeout: 8
        )
        _ = try? process.requestDAP(command: "disconnect", arguments: ["terminateDebuggee": false], timeout: 2)
        let body = response["body"] as? [String: Any]
        return DebugAdapterProbeResult(
            adapterID: adapter.id,
            supportsConfigurationDoneRequest: body?["supportsConfigurationDoneRequest"] as? Bool ?? false,
            supportsFunctionBreakpoints: body?["supportsFunctionBreakpoints"] as? Bool ?? false,
            checkedAt: Date()
        )
    }
}
