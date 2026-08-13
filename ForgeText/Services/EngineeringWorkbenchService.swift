import Foundation

enum EngineeringWorkbenchStore {
    private static let defaultsKey = "forgeText.engineeringWorkbench"
    private static let filename = "engineering-workbench.json"

    static func load() -> EngineeringWorkbenchStoredState {
        SensitiveDataStore.load(
            EngineeringWorkbenchStoredState.self,
            from: StoragePathService.dataFileURL(named: filename),
            defaultsKey: defaultsKey
        ) ?? EngineeringWorkbenchStoredState()
    }

    static func save(_ state: EngineeringWorkbenchStoredState) {
        SensitiveDataStore.save(
            state,
            to: StoragePathService.dataFileURL(named: filename),
            defaultsKey: defaultsKey
        )
    }
}

enum LanguageIntelligenceService {
    private struct ServerSpec {
        let id: String
        let displayName: String
        let executable: String
        let versionArguments: [String]
        let languages: [DocumentLanguage]
        let capabilities: [String]
    }

    private static let serverSpecs = [
        ServerSpec(
            id: "sourcekit-lsp",
            displayName: "SourceKit-LSP",
            executable: "sourcekit-lsp",
            versionArguments: ["--version"],
            languages: [.swift],
            capabilities: ["Completion", "Definitions", "References", "Rename", "Diagnostics"]
        ),
        ServerSpec(
            id: "typescript-language-server",
            displayName: "TypeScript Language Server",
            executable: "typescript-language-server",
            versionArguments: ["--version"],
            languages: [.javascript],
            capabilities: ["Completion", "Definitions", "References", "Rename", "Code actions"]
        ),
        ServerSpec(
            id: "pyright-langserver",
            displayName: "Pyright",
            executable: "pyright-langserver",
            versionArguments: ["--version"],
            languages: [.python],
            capabilities: ["Completion", "Definitions", "References", "Diagnostics"]
        ),
        ServerSpec(
            id: "bash-language-server",
            displayName: "Bash Language Server",
            executable: "bash-language-server",
            versionArguments: ["--version"],
            languages: [.shell],
            capabilities: ["Completion", "Definitions", "Diagnostics"]
        ),
        ServerSpec(
            id: "vscode-json-language-server",
            displayName: "JSON Language Server",
            executable: "vscode-json-language-server",
            versionArguments: ["--version"],
            languages: [.json],
            capabilities: ["Completion", "Schema validation", "Diagnostics"]
        ),
    ]

    static func serverStatuses(isEnabled: Bool) -> [LanguageServerStatus] {
        serverSpecs.map { spec in
            guard isEnabled else {
                return LanguageServerStatus(
                    id: spec.id,
                    displayName: spec.displayName,
                    executable: spec.executable,
                    languages: spec.languages,
                    availability: .disabled,
                    resolvedPath: nil,
                    version: nil,
                    capabilities: spec.capabilities
                )
            }

            guard let path = ToolchainService.trustedExecutablePath(named: spec.executable) else {
                return LanguageServerStatus(
                    id: spec.id,
                    displayName: spec.displayName,
                    executable: spec.executable,
                    languages: spec.languages,
                    availability: .unavailable,
                    resolvedPath: nil,
                    version: nil,
                    capabilities: spec.capabilities
                )
            }

            let version = try? CommandExecutionService.runString(
                path,
                arguments: spec.versionArguments,
                environment: ["NO_COLOR": "1"],
                limits: .gitRead
            )
            .split(whereSeparator: \.isNewline)
            .first
            .map(String.init)

            return LanguageServerStatus(
                id: spec.id,
                displayName: spec.displayName,
                executable: spec.executable,
                languages: spec.languages,
                availability: .ready,
                resolvedPath: path,
                version: version ?? "Available",
                capabilities: spec.capabilities
            )
        }
    }

    static func symbol(at selectedRange: NSRange, in text: String) -> String? {
        let nsText = text as NSString
        guard nsText.length > 0 else { return nil }

        if selectedRange.length > 0, selectedRange.length <= 128,
           NSMaxRange(selectedRange) <= nsText.length {
            let selected = nsText.substring(with: selectedRange)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if isValidSymbol(selected) {
                return selected
            }
        }

        let location = min(max(selectedRange.location, 0), max(0, nsText.length - 1))
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_$"))
        var lower = location
        var upper = location

        while lower > 0 {
            let scalar = UnicodeScalar(nsText.character(at: lower - 1))
            guard let scalar, allowed.contains(scalar) else { break }
            lower -= 1
        }
        while upper < nsText.length {
            let scalar = UnicodeScalar(nsText.character(at: upper))
            guard let scalar, allowed.contains(scalar) else { break }
            upper += 1
        }

        guard upper > lower else { return nil }
        let value = nsText.substring(with: NSRange(location: lower, length: upper - lower))
        return isValidSymbol(value) ? value : nil
    }

    static func navigationHits(
        for symbol: String,
        index: WorkspaceIndexSummary,
        maximumReferences: Int = 300
    ) -> [LanguageNavigationHit] {
        let trimmed = symbol.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isValidSymbol(trimmed) else { return [] }

        var hits: [LanguageNavigationHit] = index.symbols
            .filter { $0.title.caseInsensitiveCompare(trimmed) == .orderedSame }
            .prefix(100)
            .map {
                LanguageNavigationHit(
                    id: "definition:\($0.id)",
                    kind: .definition,
                    symbol: trimmed,
                    fileURL: $0.fileURL,
                    relativePath: $0.relativePath,
                    lineNumber: $0.lineNumber,
                    preview: $0.detail ?? $0.title
                )
            }

        guard let regex = try? NSRegularExpression(
            pattern: "(?<![A-Za-z0-9_$])\(NSRegularExpression.escapedPattern(for: trimmed))(?![A-Za-z0-9_$])"
        ) else {
            return hits
        }

        var remaining = maximumReferences
        for entry in index.entries where remaining > 0 && entry.byteCount <= 2 * 1_024 * 1_024 {
            guard let data = try? BoundedFileReadService.read(entry.url, maximumBytes: 2 * 1_024 * 1_024),
                  let text = String(data: data, encoding: .utf8)
            else {
                continue
            }

            let nsText = text as NSString
            let matches = regex.matches(in: text, range: NSRange(location: 0, length: nsText.length))
            for match in matches.prefix(remaining) {
                let lineRange = nsText.lineRange(for: match.range)
                let prefix = nsText.substring(to: lineRange.location)
                let lineNumber = prefix.reduce(into: 1) { count, character in
                    if character == "\n" { count += 1 }
                }
                let preview = nsText.substring(with: lineRange)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                hits.append(
                    LanguageNavigationHit(
                        id: "reference:\(entry.id):\(match.range.location)",
                        kind: .reference,
                        symbol: trimmed,
                        fileURL: entry.url,
                        relativePath: entry.relativePath,
                        lineNumber: lineNumber,
                        preview: preview
                    )
                )
                remaining -= 1
                if remaining == 0 { break }
            }
        }

        return hits
    }

    private static func isValidSymbol(_ value: String) -> Bool {
        guard !value.isEmpty, value.count <= 128 else { return false }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_$"))
        return value.unicodeScalars.allSatisfy(allowed.contains)
    }
}

enum TestDiscoveryService {
    static func discover(in index: WorkspaceIndexSummary) -> [DiscoveredTestCase] {
        var results: [DiscoveredTestCase] = []
        for entry in index.entries where entry.byteCount <= 2 * 1_024 * 1_024 {
            guard let framework = framework(for: entry),
                  let data = try? BoundedFileReadService.read(entry.url, maximumBytes: 2 * 1_024 * 1_024),
                  let text = String(data: data, encoding: .utf8)
            else {
                continue
            }

            results += discover(in: text, entry: entry, framework: framework)
            if results.count >= 5_000 { break }
        }
        return Array(results.prefix(5_000))
    }

    private static func framework(for entry: WorkspaceIndexEntry) -> DiscoveredTestFramework? {
        let lowerPath = entry.relativePath.lowercased()
        switch entry.language {
        case .swift where lowerPath.contains("test"):
            return .xctest
        case .python where lowerPath.contains("test"):
            return .pytest
        case .javascript where lowerPath.contains("test") || lowerPath.contains("spec"):
            return .javascript
        default:
            return nil
        }
    }

    private static func discover(
        in text: String,
        entry: WorkspaceIndexEntry,
        framework: DiscoveredTestFramework
    ) -> [DiscoveredTestCase] {
        let pattern: String
        switch framework {
        case .xctest:
            pattern = #"\bfunc\s+(test[A-Za-z0-9_]+)\s*\("#
        case .pytest:
            pattern = #"\bdef\s+(test_[A-Za-z0-9_]+)\s*\("#
        case .javascript:
            pattern = #"\b(?:it|test)\s*\(\s*['\"]([^'\"]+)['\"]"#
        }

        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsText = text as NSString
        return regex.matches(in: text, range: NSRange(location: 0, length: nsText.length)).compactMap { match in
            guard match.numberOfRanges > 1 else { return nil }
            let name = nsText.substring(with: match.range(at: 1))
            let prefix = nsText.substring(to: match.range.location)
            let line = prefix.reduce(into: 1) { count, character in
                if character == "\n" { count += 1 }
            }
            return DiscoveredTestCase(
                id: "\(entry.id):\(line):\(name)",
                name: name,
                framework: framework,
                filePath: entry.url.path,
                relativePath: entry.relativePath,
                lineNumber: line
            )
        }
    }
}

enum CoverageReportService {
    static func loadLCOV(from workspaceRoots: [URL]) -> [CoverageFileSummary] {
        let candidates = workspaceRoots.flatMap { root in
            [
                root.appendingPathComponent("coverage/lcov.info"),
                root.appendingPathComponent("lcov.info"),
                root.appendingPathComponent(".coverage/lcov.info"),
            ]
        }

        guard let reportURL = candidates.first(where: { FileManager.default.fileExists(atPath: $0.path) }),
              let data = try? BoundedFileReadService.read(reportURL, maximumBytes: 16 * 1_024 * 1_024),
              let text = String(data: data, encoding: .utf8)
        else {
            return []
        }

        var currentPath: String?
        var covered = 0
        var executable = 0
        var summaries: [CoverageFileSummary] = []

        func appendCurrent() {
            guard let currentPath else { return }
            summaries.append(
                CoverageFileSummary(
                    id: currentPath,
                    relativePath: currentPath,
                    coveredLines: covered,
                    executableLines: executable
                )
            )
        }

        for line in text.split(whereSeparator: \.isNewline).map(String.init) {
            if line.hasPrefix("SF:") {
                appendCurrent()
                currentPath = String(line.dropFirst(3))
                covered = 0
                executable = 0
            } else if line.hasPrefix("DA:") {
                let fields = line.dropFirst(3).split(separator: ",")
                guard fields.count >= 2, let count = Int(fields[1]) else { continue }
                executable += 1
                if count > 0 { covered += 1 }
            } else if line == "end_of_record" {
                appendCurrent()
                currentPath = nil
                covered = 0
                executable = 0
            }
        }
        appendCurrent()
        return summaries.sorted { $0.percentage < $1.percentage }
    }
}

enum AIChangeSetService {
    enum ChangeSetError: LocalizedError {
        case patchMissing
        case patchTooLarge
        case unsupportedPatch
        case unsafePath(String)
        case noApprovedHunks

        var errorDescription: String? {
            switch self {
            case .patchMissing: return "The AI response does not contain a unified diff."
            case .patchTooLarge: return "The proposed patch exceeds ForgeText's 1 MB review limit."
            case .unsupportedPatch: return "The patch uses an unsupported binary, rename, creation, or deletion operation."
            case let .unsafePath(path): return "The patch contains an unsafe file path: \(path)"
            case .noApprovedHunks: return "Approve at least one hunk before applying this change set."
            }
        }
    }

    static func parse(response: String, title: String = "AI proposed changes") throws -> AIChangeSet {
        let patch = extractPatch(from: response)
        guard !patch.isEmpty else { throw ChangeSetError.patchMissing }
        guard patch.utf8.count <= 1_024 * 1_024 else { throw ChangeSetError.patchTooLarge }
        guard !patch.contains("GIT binary patch"),
              !patch.contains("rename from "),
              !patch.contains("new file mode "),
              !patch.contains("deleted file mode ")
        else {
            throw ChangeSetError.unsupportedPatch
        }

        let lines = patch.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var files: [AIFileChange] = []
        var oldPath: String?
        var newPath: String?
        var hunks: [AIChangeHunk] = []
        var currentHeader: String?
        var currentBody: [String] = []

        func finishHunk() {
            guard let currentHeader else { return }
            hunks.append(AIChangeHunk(header: currentHeader, body: ([currentHeader] + currentBody).joined(separator: "\n") + "\n"))
        }

        func finishFile() throws {
            finishHunk()
            guard let oldPath, let newPath else { return }
            try validate(path: oldPath)
            try validate(path: newPath)
            guard !hunks.isEmpty else { throw ChangeSetError.unsupportedPatch }
            files.append(AIFileChange(oldPath: oldPath, newPath: newPath, hunks: hunks))
        }

        for line in lines {
            if line.hasPrefix("diff --git ") {
                try finishFile()
                let fields = line.split(separator: " ")
                guard fields.count == 4 else { throw ChangeSetError.unsupportedPatch }
                oldPath = stripGitPrefix(String(fields[2]))
                newPath = stripGitPrefix(String(fields[3]))
                hunks = []
                currentHeader = nil
                currentBody = []
            } else if line.hasPrefix("@@") {
                finishHunk()
                currentHeader = line
                currentBody = []
            } else if currentHeader != nil {
                currentBody.append(line)
            }
        }
        try finishFile()

        guard !files.isEmpty else { throw ChangeSetError.patchMissing }
        return AIChangeSet(title: title, originalPatch: patch, files: files)
    }

    static func approvedPatch(for changeSet: AIChangeSet) throws -> String {
        let approvedFiles = changeSet.files.compactMap { file -> String? in
            let approved = file.hunks.filter(\.isApproved)
            guard !approved.isEmpty else { return nil }
            let header = [
                "diff --git a/\(file.oldPath) b/\(file.newPath)",
                "--- a/\(file.oldPath)",
                "+++ b/\(file.newPath)",
            ]
            return (header + approved.map(\.body)).joined(separator: "\n")
        }
        guard !approvedFiles.isEmpty else { throw ChangeSetError.noApprovedHunks }
        return approvedFiles.joined(separator: "\n") + "\n"
    }

    static func validateFiles(for changeSet: AIChangeSet, workspaceRoot: URL) throws {
        let root = workspaceRoot.resolvingSymlinksInPath().standardizedFileURL.path
        for path in changeSet.files.flatMap({ [$0.oldPath, $0.newPath] }) {
            try validate(path: path)
            let fileURL = workspaceRoot.appendingPathComponent(path).resolvingSymlinksInPath().standardizedFileURL
            guard fileURL.path.hasPrefix(root + "/"), FileManager.default.fileExists(atPath: fileURL.path) else {
                throw ChangeSetError.unsafePath(path)
            }
        }
    }

    private static func extractPatch(from response: String) -> String {
        if let startRange = response.range(of: "```diff") {
            let afterStart = response[startRange.upperBound...]
            if let endRange = afterStart.range(of: "```") {
                return String(afterStart[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        if let startRange = response.range(of: "diff --git ") {
            return String(response[startRange.lowerBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return ""
    }

    private static func stripGitPrefix(_ value: String) -> String {
        if value.hasPrefix("a/") || value.hasPrefix("b/") {
            return String(value.dropFirst(2))
        }
        return value
    }

    private static func validate(path: String) throws {
        let components = path.split(separator: "/", omittingEmptySubsequences: false)
        guard !path.isEmpty,
              !path.hasPrefix("/"),
              !path.hasPrefix("-"),
              !path.contains("\\"),
              !components.contains(".."),
              !components.contains("."),
              path.rangeOfCharacter(from: .controlCharacters) == nil
        else {
            throw ChangeSetError.unsafePath(path)
        }
    }
}

enum WorkspaceHealthService {
    static func snapshot(
        trustMode: WorkspaceTrustMode,
        policyState: ManagedPolicyState,
        index: WorkspaceIndexSummary,
        gitSummary: GitRepositorySummary?,
        problems: ProblemsPanelState,
        tests: [DiscoveredTestCase],
        testResults: [DiscoveredTestResult],
        languageServers: [LanguageServerStatus],
        enabledPluginCount: Int,
        workspaceRootCount: Int
    ) -> WorkspaceHealthSnapshot {
        var findings: [WorkspaceHealthFinding] = []

        findings.append(
            WorkspaceHealthFinding(
                id: "trust",
                title: trustMode == .trusted ? "Workspace trusted" : "Restricted workspace",
                detail: trustMode == .trusted
                    ? "Workspace-scoped tools can run within policy boundaries."
                    : "Tasks, AI context, remote commands, and external plugins remain restricted.",
                tone: trustMode == .trusted ? .healthy : .attention,
                systemImage: trustMode == .trusted ? "checkmark.shield" : "lock.shield",
                section: .enterprise
            )
        )

        if let loadError = policyState.loadError {
            findings.append(
                WorkspaceHealthFinding(
                    id: "policy",
                    title: "Managed policy invalid",
                    detail: loadError,
                    tone: .blocked,
                    systemImage: "exclamationmark.shield",
                    section: .enterprise
                )
            )
        } else if policyState.isManaged {
            findings.append(
                WorkspaceHealthFinding(
                    id: "policy",
                    title: "Managed controls active",
                    detail: "Organization policy is loaded and enforcing protected capabilities.",
                    tone: .healthy,
                    systemImage: "building.2.crop.circle",
                    section: .enterprise
                )
            )
        }

        if workspaceRootCount == 0 {
            findings.append(
                WorkspaceHealthFinding(
                    id: "root",
                    title: "No workspace folder",
                    detail: "Open a folder to enable indexing, language navigation, Git review, and tests.",
                    tone: .attention,
                    systemImage: "folder.badge.questionmark",
                    section: .overview
                )
            )
        } else {
            findings.append(
                WorkspaceHealthFinding(
                    id: "index",
                    title: "\(index.entries.count) files indexed",
                    detail: "\(index.symbols.count) symbols, \(index.todoCount) TODO markers, and \(index.warningCount) likely warnings.",
                    tone: index.warningCount > 0 ? .attention : .healthy,
                    systemImage: "magnifyingglass.circle",
                    section: .intelligence
                )
            )
        }

        let errorCount = problems.records.filter { $0.severity == .error }.count
        findings.append(
            WorkspaceHealthFinding(
                id: "problems",
                title: errorCount == 0 ? "No blocking diagnostics" : "\(errorCount) error diagnostics",
                detail: "\(problems.records.count) total problem records are currently available.",
                tone: errorCount == 0 ? .healthy : .blocked,
                systemImage: errorCount == 0 ? "checkmark.circle" : "xmark.octagon",
                section: .overview
            )
        )

        if let gitSummary {
            findings.append(
                WorkspaceHealthFinding(
                    id: "git",
                    title: "Git branch \(gitSummary.branchName)",
                    detail: "\(gitSummary.modifiedCount) modified, \(gitSummary.stagedCount) staged, \(gitSummary.conflictedCount) conflicted.",
                    tone: gitSummary.conflictedCount > 0 ? .blocked : (gitSummary.modifiedCount > 0 ? .attention : .healthy),
                    systemImage: "arrow.triangle.branch",
                    section: .review
                )
            )
        }

        let readyServers = languageServers.filter { $0.availability == .ready }.count
        findings.append(
            WorkspaceHealthFinding(
                id: "languages",
                title: "\(readyServers) language servers ready",
                detail: "ForgeText falls back to its local index when a language server is unavailable.",
                tone: readyServers > 0 ? .healthy : .informational,
                systemImage: "chevron.left.forwardslash.chevron.right",
                section: .intelligence
            )
        )

        let failedTests = testResults.filter { $0.status == .failed }.count
        findings.append(
            WorkspaceHealthFinding(
                id: "tests",
                title: "\(tests.count) tests discovered",
                detail: failedTests == 0 ? "No recorded test failures." : "\(failedTests) recorded test failures need attention.",
                tone: failedTests == 0 ? .healthy : .blocked,
                systemImage: "checkmark.circle",
                section: .tests
            )
        )

        findings.append(
            WorkspaceHealthFinding(
                id: "plugins",
                title: "\(enabledPluginCount) plugins enabled",
                detail: "Plugin provenance and executable capabilities remain subject to local and managed policy.",
                tone: .informational,
                systemImage: "puzzlepiece.extension",
                section: .enterprise
            )
        )

        let penalty = findings.reduce(0) { partial, finding in
            switch finding.tone {
            case .healthy, .informational: return partial
            case .attention: return partial + 5
            case .blocked: return partial + 18
            }
        }
        return WorkspaceHealthSnapshot(score: max(0, 100 - penalty), findings: findings, checkedAt: Date())
    }
}

enum EnterpriseFleetService {
    static func checks(
        policyState: ManagedPolicyState,
        releaseState: ReleaseReadinessState,
        portableMode: Bool,
        signedPluginCount: Int,
        totalExternalPluginCount: Int
    ) -> [EnterpriseFleetCheck] {
        var checks: [EnterpriseFleetCheck] = []
        checks.append(
            EnterpriseFleetCheck(
                id: "policy",
                title: policyState.isManaged ? "Managed policy detected" : "Unmanaged installation",
                detail: policyState.loadError
                    ?? (policyState.hasVerifiedSignature
                        ? "Signature verified. \(policyState.sourcePath ?? "Managed source")"
                        : (policyState.sourcePath ?? "No local or MDM-delivered managed policy is active.")),
                tone: policyState.loadError != nil ? .blocked : (policyState.isManaged ? .healthy : .attention)
            )
        )
        if policyState.isManaged {
            checks.append(
                EnterpriseFleetCheck(
                    id: "policy-signature",
                    title: policyState.hasVerifiedSignature ? "Policy provenance verified" : "Unsigned managed policy",
                    detail: policyState.hasVerifiedSignature
                        ? "The policy signature matches an administrator-configured Ed25519 trust root."
                        : "Filesystem ownership and permissions are validated, but cryptographic provenance is not configured.",
                    tone: policyState.hasVerifiedSignature ? .healthy : .attention
                )
            )
        }
        checks.append(
            EnterpriseFleetCheck(
                id: "release",
                title: releaseState.failureCount == 0 ? "Release gates configured" : "Release blockers detected",
                detail: "\(releaseState.passCount) passed, \(releaseState.warningCount) warnings, \(releaseState.failureCount) blockers.",
                tone: releaseState.failureCount == 0 ? .healthy : .blocked
            )
        )
        checks.append(
            EnterpriseFleetCheck(
                id: "audit",
                title: "Encrypted operational audit",
                detail: "Local audit retention is \(EnterprisePolicyService.effectiveAuditRetentionDays(policy: policyState.policy)) days with privacy filtering and a 5,000-event cap.",
                tone: .healthy
            )
        )
        checks.append(
            EnterpriseFleetCheck(
                id: "plugins",
                title: "Plugin provenance",
                detail: "\(signedPluginCount) of \(totalExternalPluginCount) external plugins report verified signatures.",
                tone: totalExternalPluginCount == 0 || signedPluginCount == totalExternalPluginCount ? .healthy : .attention
            )
        )
        checks.append(
            EnterpriseFleetCheck(
                id: "storage",
                title: portableMode ? "Portable data mode" : "Device-protected data mode",
                detail: portableMode
                    ? "Portable mode is active; deployment owners should verify media custody and backup controls."
                    : "Sensitive local state uses device-bound Keychain protection.",
                tone: portableMode ? .attention : .healthy
            )
        )
        return checks
    }
}
