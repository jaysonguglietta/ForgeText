import Darwin
import Foundation

struct SecureNetworkPolicy: Sendable {
    enum DestinationScope: Sendable {
        case publicOnly
        case privateOnly
        case any
    }

    let destinationScope: DestinationScope
    let allowedHosts: [String]?
    let allowedSchemes: Set<String>
    let maximumResponseBytes: Int
    let timeout: TimeInterval

    static func publicInternet(allowedHosts: [String]? = nil, maximumResponseBytes: Int = 8 * 1_024 * 1_024) -> Self {
        SecureNetworkPolicy(
            destinationScope: .publicOnly,
            allowedHosts: allowedHosts,
            allowedSchemes: ["https"],
            maximumResponseBytes: maximumResponseBytes,
            timeout: 60
        )
    }

    static func localService(allowedHosts: [String]? = nil, maximumResponseBytes: Int = 8 * 1_024 * 1_024) -> Self {
        SecureNetworkPolicy(
            destinationScope: .privateOnly,
            allowedHosts: allowedHosts,
            allowedSchemes: ["http", "https"],
            maximumResponseBytes: maximumResponseBytes,
            timeout: 60
        )
    }
}

enum SecureNetworkService {
    enum NetworkError: LocalizedError, Equatable {
        case invalidURL
        case unsupportedScheme
        case credentialsInURL
        case hostNotAllowed(String)
        case privateNetworkRequiresConfirmation(String)
        case privateDestinationRequired(String)
        case destinationResolutionFailed(String)
        case redirectBlocked
        case responseTooLarge(Int)

        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "The request URL does not contain a valid host."
            case .unsupportedScheme:
                return "The request URL uses a network scheme that is not allowed."
            case .credentialsInURL:
                return "Credentials embedded in request URLs are not allowed. Use an explicit authorization header instead."
            case let .hostNotAllowed(host):
                return "Managed policy does not allow requests to \(host)."
            case let .privateNetworkRequiresConfirmation(host):
                return "\(host) resolves to a private or local network address. Confirm this request before allowing local-network access."
            case let .privateDestinationRequired(host):
                return "The local-model endpoint \(host) does not resolve exclusively to a private or loopback address."
            case let .destinationResolutionFailed(host):
                return "ForgeText could not safely resolve the destination host \(host)."
            case .redirectBlocked:
                return "ForgeText blocked a network redirect. Enter the final destination URL explicitly so its host can be reviewed."
            case let .responseTooLarge(limit):
                return "The response exceeded the \(ByteCountFormatter.string(fromByteCount: Int64(limit), countStyle: .file)) safety limit."
            }
        }
    }

    private final class RedirectRejectingDelegate: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
        private let lock = NSLock()
        private var didRejectRedirect = false

        var rejectedRedirect: Bool {
            lock.lock()
            defer { lock.unlock() }
            return didRejectRedirect
        }

        func urlSession(
            _ session: URLSession,
            task: URLSessionTask,
            willPerformHTTPRedirection response: HTTPURLResponse,
            newRequest request: URLRequest,
            completionHandler: @escaping @Sendable (URLRequest?) -> Void
        ) {
            lock.lock()
            didRejectRedirect = true
            lock.unlock()
            completionHandler(nil)
        }
    }

    static func data(for request: URLRequest, policy: SecureNetworkPolicy) async throws -> (Data, URLResponse) {
        guard let url = request.url else {
            throw NetworkError.invalidURL
        }

        try await Task.detached(priority: .utility) {
            try validate(url: url, policy: policy)
        }.value

        var boundedRequest = request
        boundedRequest.timeoutInterval = policy.timeout
        boundedRequest.setValue("identity", forHTTPHeaderField: "Accept-Encoding")

        let delegate = RedirectRejectingDelegate()
        let (bytes, response) = try await URLSession.shared.bytes(for: boundedRequest, delegate: delegate)
        if delegate.rejectedRedirect {
            throw NetworkError.redirectBlocked
        }

        if response.expectedContentLength > Int64(policy.maximumResponseBytes) {
            throw NetworkError.responseTooLarge(policy.maximumResponseBytes)
        }

        var data = Data()
        data.reserveCapacity(min(max(0, Int(response.expectedContentLength)), policy.maximumResponseBytes))
        for try await byte in bytes {
            guard data.count < policy.maximumResponseBytes else {
                throw NetworkError.responseTooLarge(policy.maximumResponseBytes)
            }
            data.append(byte)
        }

        return (data, response)
    }

    static func validate(url: URL, policy: SecureNetworkPolicy) throws {
        guard let scheme = url.scheme?.lowercased(),
              let host = url.host?.lowercased(),
              !host.isEmpty else {
            throw NetworkError.invalidURL
        }
        guard policy.allowedSchemes.contains(scheme) else {
            throw NetworkError.unsupportedScheme
        }
        guard url.user == nil, url.password == nil else {
            throw NetworkError.credentialsInURL
        }

        if let allowedHosts = policy.allowedHosts {
            let normalizedAllowedHosts = allowedHosts.map {
                $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            }
            guard normalizedAllowedHosts.contains(host) else {
                throw NetworkError.hostNotAllowed(host)
            }
        }

        let addressScopes = try resolvedAddressScopes(for: host)
        guard !addressScopes.isEmpty else {
            throw NetworkError.destinationResolutionFailed(host)
        }

        switch policy.destinationScope {
        case .publicOnly:
            if addressScopes.contains(.privateOrReserved) {
                throw NetworkError.privateNetworkRequiresConfirmation(host)
            }
        case .privateOnly:
            if addressScopes.contains(.publicInternet) {
                throw NetworkError.privateDestinationRequired(host)
            }
        case .any:
            break
        }
    }

    private enum AddressScope: Hashable {
        case publicInternet
        case privateOrReserved
    }

    private static func resolvedAddressScopes(for host: String) throws -> Set<AddressScope> {
        if host == "localhost" || host.hasSuffix(".localhost") {
            return [.privateOrReserved]
        }

        var hints = addrinfo(
            ai_flags: AI_ADDRCONFIG,
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: IPPROTO_TCP,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )
        var result: UnsafeMutablePointer<addrinfo>?
        let status = host.withCString { getaddrinfo($0, nil, &hints, &result) }
        guard status == 0, let firstResult = result else {
            throw NetworkError.destinationResolutionFailed(host)
        }
        defer { freeaddrinfo(firstResult) }

        var scopes: Set<AddressScope> = []
        var current: UnsafeMutablePointer<addrinfo>? = firstResult
        while let addressInfo = current?.pointee {
            if addressInfo.ai_family == AF_INET, let address = addressInfo.ai_addr {
                let ipv4 = address.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { pointer in
                    UInt32(bigEndian: pointer.pointee.sin_addr.s_addr)
                }
                scopes.insert(isPrivateOrReservedIPv4(ipv4) ? .privateOrReserved : .publicInternet)
            } else if addressInfo.ai_family == AF_INET6, let address = addressInfo.ai_addr {
                var ipv6 = address.withMemoryRebound(to: sockaddr_in6.self, capacity: 1) { $0.pointee.sin6_addr }
                let bytes = withUnsafeBytes(of: &ipv6) { Array($0) }
                scopes.insert(isPrivateOrReservedIPv6(bytes) ? .privateOrReserved : .publicInternet)
            }
            current = addressInfo.ai_next
        }
        return scopes
    }

    private static func isPrivateOrReservedIPv4(_ address: UInt32) -> Bool {
        let first = UInt8((address >> 24) & 0xff)
        let second = UInt8((address >> 16) & 0xff)
        return first == 0
            || first == 10
            || first == 127
            || (first == 100 && (64...127).contains(second))
            || (first == 169 && second == 254)
            || (first == 172 && (16...31).contains(second))
            || (first == 192 && second == 168)
            || first >= 224
    }

    private static func isPrivateOrReservedIPv6(_ bytes: [UInt8]) -> Bool {
        guard bytes.count == 16 else {
            return true
        }
        let isUnspecified = bytes.allSatisfy { $0 == 0 }
        let isLoopback = bytes.dropLast().allSatisfy { $0 == 0 } && bytes.last == 1
        let isUniqueLocal = bytes[0] & 0xfe == 0xfc
        let isLinkLocal = bytes[0] == 0xfe && bytes[1] & 0xc0 == 0x80
        let isMulticast = bytes[0] == 0xff
        return isUnspecified || isLoopback || isUniqueLocal || isLinkLocal || isMulticast
    }
}
