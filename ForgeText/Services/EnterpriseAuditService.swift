import CryptoKit
import Foundation

struct EnterpriseAuditEvent: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let title: String
    let detail: String
    let status: ActivityStatus
    let createdAt: Date
    let workspaceTrustMode: String
    let managedPolicyDigest: String?
}

struct EnterpriseAuditExportSummary: Hashable {
    let url: URL
    let eventCount: Int
}

enum EnterpriseAuditService {
    private static let maximumStoredEvents = 5_000
    private static let fileName = "enterprise-audit.json"
    private static let writerQueue = DispatchQueue(
        label: "com.jaysonguglietta.ForgeText.enterprise-audit",
        qos: .utility
    )

    static func events() -> [EnterpriseAuditEvent] {
        writerQueue.sync {
            loadEvents()
        }
    }

    static func append(
        title: String,
        detail: String,
        status: ActivityStatus,
        trustMode: WorkspaceTrustMode,
        policyState: ManagedPolicyState
    ) {
        let policy = policyState.policy
        let retentionDays = EnterprisePolicyService.effectiveAuditRetentionDays(policy: policy)
        let cutoff = Calendar.current.date(byAdding: .day, value: -retentionDays, to: Date()) ?? .distantPast
        let safeDetail = policy?.support.includeActivityDetailsInAudit == false
            ? "Details withheld by managed policy."
            : privacySafeDetail(detail)
        let event = EnterpriseAuditEvent(
            id: UUID(),
            title: String(title.prefix(160)),
            detail: String(safeDetail.prefix(4_096)),
            status: status,
            createdAt: Date(),
            workspaceTrustMode: trustMode.displayName,
            managedPolicyDigest: policyState.canonicalSHA256
        )
        writerQueue.async {
            var retained = loadEvents().filter { $0.createdAt >= cutoff }
            retained.insert(event, at: 0)
            SensitiveDataStore.save(
                Array(retained.prefix(maximumStoredEvents)),
                to: StoragePathService.dataFileURL(named: fileName)
            )
        }
    }

    static func export(to parentDirectory: URL, policy: EnterpriseManagedPolicy?) throws -> EnterpriseAuditExportSummary {
        if let reason = EnterprisePolicyService.auditExportRestrictionReason(policy: policy) {
            throw AuditError.blocked(reason)
        }
        let retained = events().filter {
            let days = EnterprisePolicyService.effectiveAuditRetentionDays(policy: policy)
            let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? .distantPast
            return $0.createdAt >= cutoff
        }
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let url = parentDirectory.appendingPathComponent("ForgeText-Audit-\(timestamp).jsonl")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let lines = try retained.map { event in
            String(decoding: try encoder.encode(event), as: UTF8.self)
        }.joined(separator: "\n") + (retained.isEmpty ? "" : "\n")
        try Data(lines.utf8).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        return EnterpriseAuditExportSummary(url: url, eventCount: retained.count)
    }

    private static func privacySafeDetail(_ detail: String) -> String {
        var value = detail.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path,
            with: "~"
        )
        let patterns = [
            #"(?i)(authorization\s*[:=]\s*(?:bearer|basic)\s+)[^\s,;]+"#,
            #"(?i)((?:api[_-]?key|token|secret|password)\s*[:=]\s*)[^\s,;]+"#,
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(value.startIndex..<value.endIndex, in: value)
            value = regex.stringByReplacingMatches(in: value, range: range, withTemplate: "$1<redacted>")
        }
        return value
    }

    private static func loadEvents() -> [EnterpriseAuditEvent] {
        SensitiveDataStore.load(
            [EnterpriseAuditEvent].self,
            from: StoragePathService.dataFileURL(named: fileName)
        ) ?? []
    }

    enum AuditError: LocalizedError {
        case blocked(String)

        var errorDescription: String? {
            switch self {
            case let .blocked(reason): return reason
            }
        }
    }
}
