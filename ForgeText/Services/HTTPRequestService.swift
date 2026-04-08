import Foundation

struct HTTPRequestHeader: Hashable, Identifiable {
    let id = UUID()
    let name: String
    let value: String
}

struct ParsedHTTPRequest: Identifiable, Hashable {
    let id: String
    let name: String
    let method: String
    let urlString: String
    let headers: [HTTPRequestHeader]
    let body: String
}

struct HTTPRequestDocument: Hashable {
    let requests: [ParsedHTTPRequest]
}

struct HTTPResponseRecord: Hashable {
    let requestName: String
    let urlString: String
    let statusCode: Int
    let statusText: String
    let headers: [HTTPRequestHeader]
    let bodyText: String
    let elapsedTime: TimeInterval
}

enum HTTPRequestService {
    enum HTTPRequestError: LocalizedError {
        case invalidURL(String)
        case malformedRequest(String)
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case let .invalidURL(urlString):
                return "ForgeText couldn’t build a request URL from \(urlString)."
            case let .malformedRequest(message):
                return message
            case .invalidResponse:
                return "The remote server did not return a valid HTTP response."
            }
        }
    }

    static func parse(_ text: String) -> HTTPRequestDocument? {
        let blocks = splitBlocks(text)
        let requests = blocks.compactMap(parseRequestBlock)
        return requests.isEmpty ? nil : HTTPRequestDocument(requests: requests)
    }

    static func execute(_ requestDefinition: ParsedHTTPRequest) async throws -> HTTPResponseRecord {
        guard let url = URL(string: requestDefinition.urlString) else {
            throw HTTPRequestError.invalidURL(requestDefinition.urlString)
        }

        var request = URLRequest(url: url)
        request.httpMethod = requestDefinition.method

        for header in requestDefinition.headers {
            request.setValue(header.value, forHTTPHeaderField: header.name)
        }

        if !requestDefinition.body.isEmpty {
            request.httpBody = requestDefinition.body.data(using: .utf8)
        }

        let startedAt = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        let elapsedTime = Date().timeIntervalSince(startedAt)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPRequestError.invalidResponse
        }

        let bodyText = String(data: data, encoding: .utf8) ?? data.base64EncodedString()
        let headers = httpResponse.allHeaderFields.compactMap { key, value -> HTTPRequestHeader? in
            guard let name = key as? String else {
                return nil
            }

            return HTTPRequestHeader(name: name, value: String(describing: value))
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        return HTTPResponseRecord(
            requestName: requestDefinition.name,
            urlString: requestDefinition.urlString,
            statusCode: httpResponse.statusCode,
            statusText: HTTPURLResponse.localizedString(forStatusCode: httpResponse.statusCode),
            headers: headers,
            bodyText: bodyText,
            elapsedTime: elapsedTime
        )
    }

    private static func splitBlocks(_ text: String) -> [String] {
        var blocks: [String] = []
        var currentLines: [String] = []

        for line in text.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false).map(String.init) {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("###") {
                if !currentLines.joined().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    blocks.append(currentLines.joined(separator: "\n"))
                    currentLines.removeAll()
                }
            }

            currentLines.append(line)
        }

        if !currentLines.joined().trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            blocks.append(currentLines.joined(separator: "\n"))
        }

        return blocks
    }

    private static func parseRequestBlock(_ block: String) -> ParsedHTTPRequest? {
        let normalizedLines = block.replacingOccurrences(of: "\r\n", with: "\n").split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var lines = normalizedLines[...]
        var explicitName: String?

        while let firstLine = lines.first {
            let trimmed = firstLine.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.hasPrefix("###") {
                explicitName = trimmed.replacingOccurrences(of: "###", with: "").trimmingCharacters(in: .whitespacesAndNewlines)
                lines = lines.dropFirst()
                continue
            }

            if trimmed.isEmpty || trimmed.hasPrefix("#") {
                lines = lines.dropFirst()
                continue
            }

            break
        }

        guard let requestLine = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines), !requestLine.isEmpty else {
            return nil
        }

        let parts = requestLine.split(whereSeparator: \.isWhitespace)
        guard parts.count >= 2 else {
            return nil
        }

        let method = String(parts[0]).uppercased()
        let urlString = String(parts[1])

        var headers: [HTTPRequestHeader] = []
        var bodyLines: [String] = []
        var inBody = false

        for line in lines.dropFirst() {
            if !inBody {
                if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    inBody = true
                    continue
                }

                if line.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("#") {
                    continue
                }

                if let separator = line.firstIndex(of: ":") {
                    let name = line[..<separator].trimmingCharacters(in: .whitespaces)
                    let value = line[line.index(after: separator)...].trimmingCharacters(in: .whitespaces)
                    headers.append(HTTPRequestHeader(name: name, value: value))
                    continue
                }

                inBody = true
            }

            bodyLines.append(line)
        }

        let name = explicitName?.isEmpty == false ? explicitName! : "\(method) \(urlString)"
        return ParsedHTTPRequest(
            id: "\(name)-\(method)-\(urlString)",
            name: name,
            method: method,
            urlString: urlString,
            headers: headers,
            body: bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
