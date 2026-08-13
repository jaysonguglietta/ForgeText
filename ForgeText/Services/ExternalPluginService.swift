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

        struct LanguagePackRecord: Codable {
            let id: String
            let displayName: String
            let baseLanguage: DocumentLanguage
            let fileExtensions: [String]?
            let fileNames: [String]?
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
        let languagePacks: [LanguagePackRecord]?
        let signingPublicKey: String?
        let signature: String?
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
            .prefix(500)
            .compactMap { loadPlugin(at: $0, workspaceRoot: directory.workspaceRoot) }
    }

    private static func loadPlugin(at url: URL, workspaceRoot: URL?) -> EditorPlugin? {
        guard let values = try? url.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey]),
              values.isRegularFile == true,
              values.isSymbolicLink != true,
              (values.fileSize ?? 0) <= 1_024 * 1_024,
              let data = try? BoundedFileReadService.read(url, maximumBytes: 1_024 * 1_024),
              let manifestFile = try? JSONDecoder().decode(ManifestFile.self, from: data)
        else {
            return nil
        }
        let provenance = PluginSignatureService.provenance(for: data)

        let tasks = (manifestFile.tasks ?? []).compactMap { task -> EditorPluginTask? in
            guard WorkspaceTaskService.isUserSuppliedExecutableAllowed(task.executable) else {
                return nil
            }

            return EditorPluginTask(
                id: task.id,
                pluginID: manifestFile.id,
                pluginName: manifestFile.name,
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

        let languagePacks = (manifestFile.languagePacks ?? []).prefix(50).compactMap { pack -> EditorPluginLanguagePack? in
            let extensions = safeAliases(pack.fileExtensions ?? [], removesLeadingDot: true)
            let names = safeAliases(pack.fileNames ?? [], removesLeadingDot: false)
            guard !extensions.isEmpty || !names.isEmpty else { return nil }
            return EditorPluginLanguagePack(
                id: pack.id,
                pluginID: manifestFile.id,
                displayName: String(pack.displayName.prefix(100)),
                baseLanguage: pack.baseLanguage,
                fileExtensions: extensions,
                fileNames: names
            )
        }

        let capabilities = manifestFile.capabilities.filter { capability in
            switch capability {
            case .tasks: return !tasks.isEmpty
            case .languagePacks: return !languagePacks.isEmpty
            default: return true
            }
        }

        let manifest = EditorPluginManifest(
            id: manifestFile.id,
            name: manifestFile.name,
            version: manifestFile.version,
            author: manifestFile.author,
            summary: manifestFile.summary,
            category: manifestFile.category,
            capabilities: capabilities,
            isBuiltIn: false,
            sourceDescription: url.path(percentEncoded: false),
            defaultEnabled: manifestFile.defaultEnabled ?? false,
            canonicalSHA256: provenance?.canonicalSHA256,
            verifiedSigningKey: provenance?.verifiedSigningKey
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

        return EditorPlugin(
            manifest: manifest,
            commands: [],
            snippets: snippets,
            tasks: tasks,
            languagePacks: languagePacks
        )
    }

    private static func safeAliases(_ values: [String], removesLeadingDot: Bool) -> [String] {
        Array(Set(values.prefix(100).compactMap { value -> String? in
            var normalized = value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if removesLeadingDot { normalized = normalized.trimmingCharacters(in: CharacterSet(charactersIn: ".")) }
            guard !normalized.isEmpty,
                  normalized.count <= 128,
                  !normalized.contains("/"),
                  !normalized.contains("\\"),
                  !normalized.unicodeScalars.contains(where: CharacterSet.controlCharacters.contains)
            else { return nil }
            return normalized
        })).sorted()
    }
}
