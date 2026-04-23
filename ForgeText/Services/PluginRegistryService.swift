import Foundation

enum PluginRegistryService {
    private struct RegistryFile: Codable {
        let entries: [PluginRegistryEntry]
    }

    enum RegistryError: LocalizedError {
        case invalidInstallFileName(String)

        var errorDescription: String? {
            switch self {
            case let .invalidInstallFileName(fileName):
                return "ForgeText rejected the plugin install file name '\(fileName)' because it is not a safe direct child of the user plugin folder."
            }
        }
    }

    static func catalog(using settings: AppSettings) async -> [PluginRegistryEntry] {
        var entries = curatedEntries

        for registry in settings.pluginRegistries where registry.isEnabled {
            entries.append(contentsOf: await loadRegistryEntries(from: registry.source))
        }

        var seenIDs = Set<String>()
        return entries.filter { seenIDs.insert($0.id).inserted }
    }

    static func install(_ entry: PluginRegistryEntry) throws -> URL {
        let manifestURL = try manifestURL(for: entry.installFileName)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(entry)
        try data.write(to: manifestURL, options: .atomic)
        return manifestURL
    }

    static func uninstall(plugin: EditorPlugin) throws {
        guard let sourceDescription = plugin.manifest.sourceDescription else {
            return
        }

        let sourceURL = URL(fileURLWithPath: sourceDescription).standardizedFileURL
        let userPluginRoot = StoragePathService.userPluginDirectoryURL().standardizedFileURL
        guard sourceURL.deletingLastPathComponent() == userPluginRoot else {
            return
        }

        try FileManager.default.removeItem(at: sourceURL)
    }

    static func isRegistrySourceAllowed(_ source: String) -> Bool {
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSource.isEmpty else {
            return false
        }

        guard let url = URL(string: trimmedSource),
              let scheme = url.scheme?.lowercased(),
              !scheme.isEmpty
        else {
            return true
        }

        return scheme == "https" || scheme == "file"
    }

    private static func loadRegistryEntries(from source: String) async -> [PluginRegistryEntry] {
        let trimmedSource = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isRegistrySourceAllowed(trimmedSource) else {
            return []
        }

        let sourceURL: URL
        let isRemoteRegistry: Bool
        if let parsedURL = URL(string: trimmedSource),
           let scheme = parsedURL.scheme?.lowercased(),
           !scheme.isEmpty {
            guard scheme == "https" || scheme == "file" else {
                return []
            }
            sourceURL = parsedURL
            isRemoteRegistry = scheme == "https"
        } else {
            sourceURL = URL(fileURLWithPath: trimmedSource)
            isRemoteRegistry = false
        }

        let data: Data?
        if sourceURL.isFileURL {
            data = try? Data(contentsOf: sourceURL)
        } else {
            let request = URLRequest(url: sourceURL, cachePolicy: .reloadIgnoringLocalCacheData, timeoutInterval: 8)
            let responseData = try? await URLSession.shared.data(for: request)
            if let (_, response) = responseData,
               let httpResponse = response as? HTTPURLResponse,
               (!(200 ..< 300).contains(httpResponse.statusCode) || httpResponse.url?.scheme?.lowercased() != "https")
            {
                data = nil
            } else {
                data = responseData?.0
            }
        }

        guard let data,
              let file = try? JSONDecoder().decode(RegistryFile.self, from: data)
        else {
            return []
        }

        guard isRemoteRegistry else {
            return file.entries
        }

        // Remote registries are unauthenticated, so never allow them to install executable tasks.
        return file.entries.filter { entry in
            entry.tasks.isEmpty && !entry.capabilities.contains(.tasks)
        }
    }

    private static func manifestURL(for installFileName: String) throws -> URL {
        let trimmedFileName = installFileName.trimmingCharacters(in: .whitespacesAndNewlines)
        let sanitizedFileName = URL(fileURLWithPath: trimmedFileName).lastPathComponent
        let isDirectChild = !trimmedFileName.isEmpty
            && sanitizedFileName == trimmedFileName
            && trimmedFileName != "."
            && trimmedFileName != ".."
            && !trimmedFileName.contains("/")
            && !trimmedFileName.contains("\\")

        guard isDirectChild else {
            throw RegistryError.invalidInstallFileName(installFileName)
        }

        return StoragePathService.userPluginDirectoryURL()
            .appendingPathComponent(sanitizedFileName, isDirectory: false)
            .standardizedFileURL
    }

    private static let curatedEntries: [PluginRegistryEntry] = [
        PluginRegistryEntry(
            id: "forge.ops-snippets",
            name: "Ops Snippets Pack",
            version: "1.0.0",
            author: "ForgeText",
            summary: "Adds practical snippets for shell, systemd, env files, and incident notes.",
            category: .snippets,
            capabilities: [.snippets],
            defaultEnabled: true,
            sourceDescription: "ForgeText Curated Registry",
            snippets: [
                PluginRegistrySnippetRecord(
                    id: "ops.shell.journalctl",
                    title: "journalctl Tail",
                    detail: "Tail recent systemd logs for a specific unit.",
                    symbolName: "waveform.path.ecg",
                    languages: [.shell],
                    body: "journalctl -u $0 -n 200 -f\n"
                ),
                PluginRegistrySnippetRecord(
                    id: "ops.env.block",
                    title: ".env Block",
                    detail: "Insert a grouped .env configuration block.",
                    symbolName: "key",
                    languages: [.config],
                    body: "# $0\nKEY=value\nANOTHER_KEY=value\n"
                ),
                PluginRegistrySnippetRecord(
                    id: "ops.systemd.service",
                    title: "systemd Service",
                    detail: "Create a basic systemd unit scaffold.",
                    symbolName: "gearshape.2",
                    languages: [.config],
                    body: "[Unit]\nDescription=$0\nAfter=network.target\n\n[Service]\nType=simple\nExecStart=/usr/bin/env bash -lc ''\nRestart=on-failure\n\n[Install]\nWantedBy=multi-user.target\n"
                ),
            ],
            tasks: [],
            installFileName: "forge-ops-snippets.json"
        ),
        PluginRegistryEntry(
            id: "forge.http-collections",
            name: "HTTP Collections",
            version: "1.0.0",
            author: "ForgeText",
            summary: "Adds runnable HTTP snippets for API smoke tests and authenticated requests.",
            category: .languageTools,
            capabilities: [.snippets],
            defaultEnabled: true,
            sourceDescription: "ForgeText Curated Registry",
            snippets: [
                PluginRegistrySnippetRecord(
                    id: "http.get.health",
                    title: "Health Check Request",
                    detail: "Start a simple GET request against a health endpoint.",
                    symbolName: "heart.text.square",
                    languages: [.http],
                    body: "GET https://example.com/health\nAccept: application/json\n\n"
                ),
                PluginRegistrySnippetRecord(
                    id: "http.auth.bearer",
                    title: "Bearer Token Request",
                    detail: "Insert an authenticated request scaffold.",
                    symbolName: "lock.doc",
                    languages: [.http],
                    body: "POST https://example.com/$0\nAuthorization: Bearer {{TOKEN}}\nContent-Type: application/json\n\n{\n  \"ok\": true\n}\n"
                ),
            ],
            tasks: [],
            installFileName: "forge-http-collections.json"
        ),
        PluginRegistryEntry(
            id: "forge.workspace-tools",
            name: "Workspace Tools Pack",
            version: "1.0.0",
            author: "ForgeText",
            summary: "Adds lightweight local tasks for repository hygiene and quick diagnostics.",
            category: .workspaceAutomation,
            capabilities: [.tasks],
            defaultEnabled: false,
            sourceDescription: "ForgeText Curated Registry",
            snippets: [],
            tasks: [
                PluginRegistryTaskRecord(
                    id: "workspace.git.status",
                    title: "git status",
                    subtitle: "Show concise repository status for the active workspace",
                    symbolName: "point.topleft.down.curvedto.point.bottomright.up",
                    executable: "git",
                    arguments: ["status", "--short", "--branch"],
                    workingDirectory: .workspaceRoot,
                    role: .custom
                ),
                PluginRegistryTaskRecord(
                    id: "workspace.tree",
                    title: "tree -L 2",
                    subtitle: "Print a shallow directory tree for the active workspace",
                    symbolName: "list.bullet.rectangle",
                    executable: "tree",
                    arguments: ["-L", "2"],
                    workingDirectory: .workspaceRoot,
                    role: .custom
                ),
            ],
            installFileName: "forge-workspace-tools.json"
        ),
    ]
}
