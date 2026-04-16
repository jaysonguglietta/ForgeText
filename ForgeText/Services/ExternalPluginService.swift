import Foundation

enum ExternalPluginService {
    private struct PluginDirectory {
        let url: URL
        let workspaceRoot: URL?
    }

    private struct ManifestFile: Codable {
        struct SnippetRecord: Codable {
            let id: String
            let title: String
            let detail: String
            let symbolName: String
            let languages: [DocumentLanguage]
            let body: String
        }

        struct TaskRecord: Codable {
            let id: String
            let title: String
            let subtitle: String
            let symbolName: String
            let executable: String
            let arguments: [String]
            let workingDirectory: PluginTaskWorkingDirectory
            let role: PluginTaskRole
        }

        let id: String
        let name: String
        let version: String
        let author: String
        let summary: String
        let category: PluginCategory
        let capabilities: [PluginCapability]
        let defaultEnabled: Bool?
        let snippets: [SnippetRecord]?
        let tasks: [TaskRecord]?
    }

    static func discoverPlugins(workspaceRoots: [URL]) -> [EditorPlugin] {
        pluginDirectories(workspaceRoots: workspaceRoots)
            .flatMap(loadPlugins(in:))
            .sorted { $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending }
    }

    static func discoverPlugins(workspaceRoot: URL?) -> [EditorPlugin] {
        discoverPlugins(workspaceRoots: workspaceRoot.map { [$0] } ?? [])
    }

    private static func pluginDirectories(workspaceRoots: [URL]) -> [PluginDirectory] {
        var directories: [PluginDirectory] = []

        for workspaceRoot in workspaceRoots.map(\.standardizedFileURL) {
            directories.append(
                PluginDirectory(
                    url: workspaceRoot.appendingPathComponent(".forgetext", isDirectory: true).appendingPathComponent("plugins", isDirectory: true),
                    workspaceRoot: workspaceRoot
                )
            )
        }

        directories.append(PluginDirectory(url: StoragePathService.userPluginDirectoryURL(), workspaceRoot: nil))

        return directories
    }

    private static func loadPlugins(in directory: PluginDirectory) -> [EditorPlugin] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory.url, includingPropertiesForKeys: nil) else {
            return []
        }

        return files
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap { loadPlugin(at: $0, workspaceRoot: directory.workspaceRoot) }
    }

    private static func loadPlugin(at url: URL, workspaceRoot: URL?) -> EditorPlugin? {
        guard let data = try? Data(contentsOf: url),
              let manifestFile = try? JSONDecoder().decode(ManifestFile.self, from: data)
        else {
            return nil
        }

        let manifest = EditorPluginManifest(
            id: manifestFile.id,
            name: manifestFile.name,
            version: manifestFile.version,
            author: manifestFile.author,
            summary: manifestFile.summary,
            category: manifestFile.category,
            capabilities: manifestFile.capabilities,
            isBuiltIn: false,
            sourceDescription: url.path(percentEncoded: false),
            defaultEnabled: manifestFile.defaultEnabled ?? true
        )

        let snippets = (manifestFile.snippets ?? []).map { snippet in
            EditorPluginSnippet(
                id: snippet.id,
                pluginID: manifest.id,
                title: snippet.title,
                detail: snippet.detail,
                symbolName: snippet.symbolName,
                languages: snippet.languages,
                body: snippet.body
            )
        }

        let tasks = (manifestFile.tasks ?? []).map { task in
            EditorPluginTask(
                id: task.id,
                pluginID: manifest.id,
                pluginName: manifest.name,
                title: task.title,
                subtitle: task.subtitle,
                symbolName: task.symbolName,
                executable: task.executable,
                arguments: task.arguments,
                workingDirectory: task.workingDirectory,
                role: task.role,
                rootPath: workspaceRoot?.path,
                supportsCoverage: task.role == .test
            )
        }

        return EditorPlugin(
            manifest: manifest,
            commands: [],
            snippets: snippets,
            tasks: tasks
        )
    }
}
