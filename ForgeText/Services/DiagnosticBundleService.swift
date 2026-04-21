import Foundation

enum DiagnosticBundleService {
    static func export(
        to parentDirectory: URL,
        documents: [EditorDocument],
        workspaceRoots: [URL],
        settings: AppSettings,
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
            workspaceIndex: workspaceIndex,
            releaseReadiness: releaseReadiness,
            gitSummary: gitSummary
        )
        try overview.write(to: bundleURL.appendingPathComponent("overview.txt"), atomically: true, encoding: .utf8)

        let activity = activityRecords
            .prefix(80)
            .map { "\($0.createdAt.formatted(date: .abbreviated, time: .standard)) [\($0.status.displayName)] \($0.title) - \($0.detail)" }
            .joined(separator: "\n")
        try activity.write(to: bundleURL.appendingPathComponent("activity.txt"), atomically: true, encoding: .utf8)

        let index = workspaceIndex.entries.prefix(300).map {
            "\($0.relativePath)\t\($0.language.displayName)\tlines:\($0.lineCount)\tsymbols:\($0.symbolCount)\ttodos:\($0.todoCount)\twarnings:\($0.warningCount)"
        }.joined(separator: "\n")
        try index.write(to: bundleURL.appendingPathComponent("workspace-index.txt"), atomically: true, encoding: .utf8)

        return DiagnosticBundleSummary(url: bundleURL, createdAt: Date(), fileCount: 3)
    }

    private static func diagnosticOverview(
        documents: [EditorDocument],
        workspaceRoots: [URL],
        settings: AppSettings,
        workspaceIndex: WorkspaceIndexSummary,
        releaseReadiness: ReleaseReadinessState,
        gitSummary: GitRepositorySummary?
    ) -> String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        let openDocs = documents.map { document in
            "- \(document.displayName) | \(document.language.displayName) | dirty:\(document.isDirty) | \(document.pathDescription)"
        }.joined(separator: "\n")
        let roots = workspaceRoots.map { "- \($0.path)" }.joined(separator: "\n")
        let enabledProviderNames = settings.aiProviders
            .filter(\.isEnabled)
            .map(\.name)
            .joined(separator: ", ")
        let git = gitSummary.map {
            "Git: \($0.rootURL.path) branch:\($0.branchName) staged:\($0.stagedCount) modified:\($0.modifiedCount) untracked:\($0.untrackedCount) conflicts:\($0.conflictedCount)"
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
        This bundle intentionally excludes document contents and AI provider keys. It lists paths, settings names, and local status only.
        """
    }
}
