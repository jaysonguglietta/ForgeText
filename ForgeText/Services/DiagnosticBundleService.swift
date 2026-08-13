import CryptoKit
import Foundation

enum DiagnosticBundleService {
    static func export(
        to parentDirectory: URL,
        documents: [EditorDocument],
        workspaceRoots: [URL],
        settings: AppSettings,
        managedPolicyState: ManagedPolicyState,
        workspaceIndex: WorkspaceIndexSummary,
        releaseReadiness: ReleaseReadinessState,
        activityRecords: [ActivityRecord],
        gitSummary: GitRepositorySummary?
    ) throws -> DiagnosticBundleSummary {
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let bundleURL = parentDirectory.appendingPathComponent("ForgeText-Diagnostics-\(timestamp)", isDirectory: true)
        try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)

        let overview = diagnosticOverview(
            documents: documents,
            workspaceRoots: workspaceRoots,
            settings: settings,
            managedPolicyState: managedPolicyState,
            workspaceIndex: workspaceIndex,
            releaseReadiness: releaseReadiness,
            gitSummary: gitSummary
        )
        try overview.write(to: bundleURL.appendingPathComponent("overview.txt"), atomically: true, encoding: .utf8)

        let activity = activityRecords
            .prefix(80)
            .map {
                let detail = redactedText($0.detail, workspaceRoots: workspaceRoots)
                return "\($0.createdAt.formatted(date: .abbreviated, time: .standard)) [\($0.status.displayName)] \($0.title) - \(detail)"
            }
            .joined(separator: "\n")
        try activity.write(to: bundleURL.appendingPathComponent("activity.txt"), atomically: true, encoding: .utf8)

        let index = workspaceIndex.entries.prefix(300).map {
            "\(redactedPathLabel($0.relativePath))\t\($0.language.displayName)\tlines:\($0.lineCount)\tsymbols:\($0.symbolCount)\ttodos:\($0.todoCount)\twarnings:\($0.warningCount)"
        }.joined(separator: "\n")
        try index.write(to: bundleURL.appendingPathComponent("workspace-index.txt"), atomically: true, encoding: .utf8)

        let policySummary = managedPolicySummary(state: managedPolicyState)
        try policySummary.write(to: bundleURL.appendingPathComponent("managed-policy.txt"), atomically: true, encoding: .utf8)

        return DiagnosticBundleSummary(url: bundleURL, createdAt: Date(), fileCount: 4)
    }

    private static func diagnosticOverview(
        documents: [EditorDocument],
        workspaceRoots: [URL],
        settings: AppSettings,
        managedPolicyState: ManagedPolicyState,
        workspaceIndex: WorkspaceIndexSummary,
        releaseReadiness: ReleaseReadinessState,
        gitSummary: GitRepositorySummary?
    ) -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let openDocs = documents.map { document in
            let sourceKind = document.isRemote ? "remote" : (document.fileURL == nil ? "untitled" : "local")
            return "- \(redactedPathLabel(document.displayName)) | \(document.language.displayName) | dirty:\(document.isDirty) | \(sourceKind)"
        }.joined(separator: "\n")
        let roots = workspaceRoots.map { "- \(redactedURLLabel($0))" }.joined(separator: "\n")
        let enabledProviderNames = settings.aiProviders
            .filter(\.isEnabled)
            .map(\.name)
            .joined(separator: ", ")
        let git = gitSummary.map {
            "Git: \(redactedURLLabel($0.rootURL)) branch:\($0.branchName) staged:\($0.stagedCount) modified:\($0.modifiedCount) untracked:\($0.untrackedCount) conflicts:\($0.conflictedCount)"
        } ?? "Git: no active repository summary"

        return """
        ForgeText Diagnostic Bundle
        Generated: \(Date().formatted(date: .complete, time: .standard))
        App: \(version) (\(build))

        Workspace Roots
        \(roots.isEmpty ? "- none" : roots)

        Open Documents
        \(openDocs.isEmpty ? "- none" : openDocs)

        Settings Snapshot
        Theme: \(settings.theme.displayName)
        Chrome: \(settings.chromeStyle.displayName)
        Density: \(settings.interfaceDensity.displayName)
        Wrap Lines: \(settings.wrapLines)
        Focus Mode: \(settings.focusModeEnabled)
        Inspector: \(settings.showsInspector)
        AI Providers Enabled: \(enabledProviderNames.isEmpty ? "none" : enabledProviderNames)
        Managed Policy: \(managedPolicyState.isManaged ? "active" : "none")
        Managed Policy Source: \(managedPolicyState.sourcePath.map(redactedPathLabel) ?? "not configured")

        Workspace Index
        Files: \(workspaceIndex.entries.count)
        Symbols: \(workspaceIndex.symbols.count)
        TODO/FIXME/HACK markers: \(workspaceIndex.todoCount)
        Potential secret warnings: \(workspaceIndex.warningCount)
        Last Indexed: \(workspaceIndex.indexedAt?.formatted(date: .abbreviated, time: .standard) ?? "never")

        Release Readiness
        Passing: \(releaseReadiness.passCount)
        Warnings: \(releaseReadiness.warningCount)
        Failures: \(releaseReadiness.failureCount)

        \(git)

        Privacy Note
        This bundle intentionally excludes document contents, AI provider keys, and absolute paths. File and workspace labels use short, non-reversible hashes for correlation.
        """
    }

    private static func managedPolicySummary(state: ManagedPolicyState) -> String {
        let lines = EnterprisePolicyService.summaryLines(for: state)
        let source = state.sourcePath.map(redactedPathLabel) ?? "not configured"

        return """
        ForgeText Managed Policy
        Generated: \(Date().formatted(date: .complete, time: .standard))
        Source: \(source)

        \(lines.joined(separator: "\n"))
        """
    }

    private static func redactedURLLabel(_ url: URL) -> String {
        redactedPathLabel(url.path)
    }

    private static func redactedPathLabel(_ path: String) -> String {
        let name = URL(fileURLWithPath: path).lastPathComponent
        let digest = SHA256.hash(data: Data(path.utf8)).prefix(4).map { String(format: "%02x", $0) }.joined()
        return "\(name.isEmpty ? "item" : name) [\(digest)]"
    }

    private static func redactedText(_ text: String, workspaceRoots: [URL]) -> String {
        var redacted = text
        for root in workspaceRoots {
            redacted = redacted.replacingOccurrences(of: root.path, with: "<workspace:\(redactedURLLabel(root))>")
        }
        redacted = redacted.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")

        let sensitivePatterns = [
            #"(?i)(authorization\s*[:=]\s*(?:bearer|basic)\s+)[^\s,;]+"#,
            #"(?i)((?:api[_-]?key|token|secret|password)\s*[:=]\s*)[^\s,;]+"#,
        ]
        for pattern in sensitivePatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(redacted.startIndex..<redacted.endIndex, in: redacted)
            redacted = regex.stringByReplacingMatches(in: redacted, range: range, withTemplate: "$1<redacted>")
        }
        return redacted
    }
}
