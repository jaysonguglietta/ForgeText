import Foundation

enum ExternalPluginService {
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

    static func discoverPlugins(workspaceRoot: URL?) -> [EditorPlugin] {
        pluginDirectories(workspaceRoot: workspaceRoot)
            .flatMap(loadPlugins(in:))
            .sorted { $0.manifest.name.localizedCaseInsensitiveCompare($1.manifest.name) == .orderedAscending }
    }

    static func pluginDirectories(workspaceRoot: URL?) -> [URL] {
        var directories: [URL] = []

        if let workspaceRoot {
            directories.append(workspaceRoot.appendingPathComponent(".forgetext", isDirectory: true).appendingPathComponent("plugins", isDirectory: true))
        }

        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        if let base {
            directories.append(base.appendingPathComponent("ForgeText", isDirectory: true).appendingPathComponent("Plugins", isDirectory: true))
        }

        return directories
    }

    private static func loadPlugins(in directory: URL) -> [EditorPlugin] {
        guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else {
            return []
        }

        return files
            .filter { $0.pathExtension.lowercased() == "json" }
            .compactMap(loadPlugin)
    }

    private static func loadPlugin(at url: URL) -> EditorPlugin? {
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
            sourceDescription: url.deletingLastPathComponent().path(percentEncoded: false),
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
                role: task.role
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
