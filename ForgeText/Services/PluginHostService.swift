import Foundation

enum PluginHostService {
    static let builtInPlugins: [EditorPlugin] = [
        languageToolsPlugin,
        snippetLibraryPlugin,
        workspaceTasksPlugin,
        gitToolsPlugin,
    ]

    static var defaultEnabledPluginIDs: [String] {
        builtInPlugins
            .filter { $0.manifest.defaultEnabled }
            .map(\.id)
    }

    static func installedPlugins(workspaceRoot: URL?) -> [EditorPlugin] {
        builtInPlugins + ExternalPluginService.discoverPlugins(workspaceRoot: workspaceRoot)
    }

    static func enabledPlugins(using settings: AppSettings, workspaceRoot: URL?) -> [EditorPlugin] {
        let plugins = installedPlugins(workspaceRoot: workspaceRoot)
        let enabledIDs = normalizedEnabledPluginIDs(from: settings, installedPlugins: plugins)
        return plugins.filter { enabledIDs.contains($0.id) }
    }

    static func normalizedEnabledPluginIDs(from settings: AppSettings, installedPlugins: [EditorPlugin]) -> Set<String> {
        let persistedIDs = Set(settings.enabledPluginIDs)
        let installedIDs = Set(installedPlugins.map(\.id))
        let defaultIDs = Set(installedPlugins.filter { $0.manifest.defaultEnabled }.map(\.id))

        if persistedIDs.isEmpty {
            return defaultIDs
        }

        return persistedIDs.intersection(installedIDs)
    }

    static func snippets(
        for language: DocumentLanguage,
        using settings: AppSettings,
        workspaceRoot: URL?
    ) -> [EditorPluginSnippet] {
        enabledPlugins(using: settings, workspaceRoot: workspaceRoot)
            .flatMap(\.snippets)
            .filter { $0.languages.isEmpty || $0.languages.contains(language) }
    }

    private static let languageToolsPlugin = EditorPlugin(
        manifest: EditorPluginManifest(
            id: "forge.language-tools",
            name: "Language Tools",
            version: "1.0.0",
            author: "ForgeText",
            summary: "Adds format-aware document commands, structured diagnostics, and fast editor actions for known file types.",
            category: .languageTools,
            capabilities: [.commands, .diagnostics, .formatting],
            isBuiltIn: true,
            sourceDescription: "ForgeText",
            defaultEnabled: true
        ),
        commands: [
            EditorPluginCommand(
                id: "language-tools.format-document",
                title: "Format Document",
                subtitle: "Apply the built-in formatter for the current file type",
                symbolName: "wand.and.stars",
                action: .formatDocument
            ),
            EditorPluginCommand(
                id: "language-tools.run-diagnostics",
                title: "Run Diagnostics",
                subtitle: "Inspect the current document for parse and structure issues",
                symbolName: "stethoscope",
                action: .runDiagnostics
            ),
        ],
        snippets: [],
        tasks: []
    )

    private static let snippetLibraryPlugin = EditorPlugin(
        manifest: EditorPluginManifest(
            id: "forge.snippet-library",
            name: "Snippet Library",
            version: "1.0.0",
            author: "ForgeText",
            summary: "Provides language-aware starter snippets for configuration files, scripts, markdown, and source files.",
            category: .snippets,
            capabilities: [.commands, .snippets, .statusItems],
            isBuiltIn: true,
            sourceDescription: "ForgeText",
            defaultEnabled: true
        ),
        commands: [
            EditorPluginCommand(
                id: "snippet-library.open",
                title: "Snippet Library",
                subtitle: "Browse and insert snippets for the active document language",
                symbolName: "text.badge.plus",
                action: .showSnippetLibrary
            ),
        ],
        snippets: snippetCatalog,
        tasks: []
    )

    private static let workspaceTasksPlugin = EditorPlugin(
        manifest: EditorPluginManifest(
            id: "forge.workspace-tasks",
            name: "Workspace Tasks",
            version: "1.0.0",
            author: "ForgeText",
            summary: "Detects common build, test, and lint tasks from Swift, Node, Python, and Make-based workspaces.",
            category: .workspaceAutomation,
            capabilities: [.commands, .tasks, .statusItems],
            isBuiltIn: true,
            sourceDescription: "ForgeText",
            defaultEnabled: true
        ),
        commands: [
            EditorPluginCommand(
                id: "workspace-tasks.open",
                title: "Task Runner",
                subtitle: "Inspect and run detected build, test, and lint tasks",
                symbolName: "play.square.stack",
                action: .showTaskRunner
            ),
            EditorPluginCommand(
                id: "workspace-tasks.build",
                title: "Run Build Task",
                subtitle: "Run the primary build command for the current workspace",
                symbolName: "hammer",
                action: .runPrimaryTask(.build)
            ),
            EditorPluginCommand(
                id: "workspace-tasks.test",
                title: "Run Test Task",
                subtitle: "Run the primary test command for the current workspace",
                symbolName: "checkmark.circle",
                action: .runPrimaryTask(.test)
            ),
            EditorPluginCommand(
                id: "workspace-tasks.lint",
                title: "Run Lint Task",
                subtitle: "Run the primary lint command for the current workspace",
                symbolName: "checklist",
                action: .runPrimaryTask(.lint)
            ),
        ],
        snippets: [],
        tasks: []
    )

    private static let gitToolsPlugin = EditorPlugin(
        manifest: EditorPluginManifest(
            id: "forge.git-tools",
            name: "Git Tools",
            version: "1.0.0",
            author: "ForgeText",
            summary: "Surfaces branch state, quick compare-to-HEAD, and lightweight source-control awareness for file work.",
            category: .sourceControl,
            capabilities: [.commands, .statusItems],
            isBuiltIn: true,
            sourceDescription: "ForgeText",
            defaultEnabled: true
        ),
        commands: [
            EditorPluginCommand(
                id: "git-tools.refresh",
                title: "Refresh Git Status",
                subtitle: "Reload branch and working tree details for the active workspace",
                symbolName: "arrow.clockwise",
                action: .refreshGitStatus
            ),
            EditorPluginCommand(
                id: "git-tools.compare-head",
                title: "Compare with Git HEAD",
                subtitle: "Review the current file against the last committed revision",
                symbolName: "arrow.left.arrow.right.square",
                action: .compareWithGitHead
            ),
        ],
        snippets: [],
        tasks: []
    )

    private static let snippetCatalog: [EditorPluginSnippet] = [
        EditorPluginSnippet(
            id: "snippet.json.object",
            pluginID: "forge.snippet-library",
            title: "JSON Object",
            detail: "Start a JSON object with a cursor-ready key/value pair.",
            symbolName: "curlybraces",
            languages: [.json],
            body: "{\n  \"$0\": \"\"\n}\n"
        ),
        EditorPluginSnippet(
            id: "snippet.json.array",
            pluginID: "forge.snippet-library",
            title: "JSON Array",
            detail: "Insert an empty JSON array scaffold.",
            symbolName: "list.bullet",
            languages: [.json],
            body: "[\n  $0\n]\n"
        ),
        EditorPluginSnippet(
            id: "snippet.markdown.heading",
            pluginID: "forge.snippet-library",
            title: "Markdown Heading",
            detail: "Create a section heading with body copy below it.",
            symbolName: "number",
            languages: [.markdown],
            body: "# $0\n\n$SELECTION"
        ),
        EditorPluginSnippet(
            id: "snippet.markdown.checklist",
            pluginID: "forge.snippet-library",
            title: "Checklist",
            detail: "Insert a short markdown task list.",
            symbolName: "checklist",
            languages: [.markdown],
            body: "- [ ] $0\n- [ ] \n- [ ] \n"
        ),
        EditorPluginSnippet(
            id: "snippet.swift.struct",
            pluginID: "forge.snippet-library",
            title: "Swift Struct",
            detail: "Create a Codable Swift struct scaffold.",
            symbolName: "swift",
            languages: [.swift],
            body: "struct $0: Codable {\n    let id: UUID\n}\n"
        ),
        EditorPluginSnippet(
            id: "snippet.swift.guard",
            pluginID: "forge.snippet-library",
            title: "Swift Guard",
            detail: "Insert a guard statement with an early return.",
            symbolName: "shield",
            languages: [.swift],
            body: "guard $0 else {\n    return\n}\n"
        ),
        EditorPluginSnippet(
            id: "snippet.shell.script",
            pluginID: "forge.snippet-library",
            title: "Shell Script",
            detail: "Start an executable shell script with safe defaults.",
            symbolName: "terminal",
            languages: [.shell],
            body: "#!/usr/bin/env bash\nset -euo pipefail\n\n$0\n"
        ),
        EditorPluginSnippet(
            id: "snippet.shell.loop",
            pluginID: "forge.snippet-library",
            title: "For Loop",
            detail: "Insert a shell loop over positional items.",
            symbolName: "repeat",
            languages: [.shell],
            body: "for item in $0; do\n    echo \"$item\"\ndone\n"
        ),
        EditorPluginSnippet(
            id: "snippet.python.main",
            pluginID: "forge.snippet-library",
            title: "Python Main Guard",
            detail: "Create a Python entrypoint scaffold.",
            symbolName: "chevron.left.forwardslash.chevron.right",
            languages: [.python],
            body: "def main() -> None:\n    $0\n\n\nif __name__ == \"__main__\":\n    main()\n"
        ),
        EditorPluginSnippet(
            id: "snippet.python.function",
            pluginID: "forge.snippet-library",
            title: "Python Function",
            detail: "Insert a typed Python function definition.",
            symbolName: "function",
            languages: [.python],
            body: "def $0() -> None:\n    pass\n"
        ),
        EditorPluginSnippet(
            id: "snippet.javascript.function",
            pluginID: "forge.snippet-library",
            title: "JavaScript Function",
            detail: "Insert a modern JavaScript function block.",
            symbolName: "curlybraces.square",
            languages: [.javascript],
            body: "function $0() {\n  \n}\n"
        ),
        EditorPluginSnippet(
            id: "snippet.javascript.fetch",
            pluginID: "forge.snippet-library",
            title: "Fetch Request",
            detail: "Insert an async fetch example.",
            symbolName: "network",
            languages: [.javascript],
            body: "const response = await fetch(\"$0\");\nconst data = await response.json();\n"
        ),
        EditorPluginSnippet(
            id: "snippet.xml.node",
            pluginID: "forge.snippet-library",
            title: "XML Element",
            detail: "Insert a nested XML element scaffold.",
            symbolName: "chevron.left.forwardslash.chevron.right",
            languages: [.xml],
            body: "<$0>\n    $SELECTION\n</>\n"
        ),
        EditorPluginSnippet(
            id: "snippet.http.get",
            pluginID: "forge.snippet-library",
            title: "HTTP GET Request",
            detail: "Insert a simple GET request block for the HTTP runner.",
            symbolName: "network",
            languages: [.http],
            body: "### Request\nGET https://$0\nAccept: application/json\n"
        ),
        EditorPluginSnippet(
            id: "snippet.http.post-json",
            pluginID: "forge.snippet-library",
            title: "HTTP POST JSON",
            detail: "Insert a JSON POST request scaffold.",
            symbolName: "arrow.up.circle",
            languages: [.http],
            body: "### Create Resource\nPOST https://$0\nContent-Type: application/json\nAccept: application/json\n\n{\n  \"id\": \"\"\n}\n"
        ),
        EditorPluginSnippet(
            id: "snippet.sql.select",
            pluginID: "forge.snippet-library",
            title: "SELECT Query",
            detail: "Insert a simple SQL query scaffold.",
            symbolName: "cylinder.split.1x2",
            languages: [.sql],
            body: "SELECT\n    $0\nFROM table_name\nWHERE 1 = 1;\n"
        ),
        EditorPluginSnippet(
            id: "snippet.css.rule",
            pluginID: "forge.snippet-library",
            title: "CSS Rule",
            detail: "Insert a CSS rule block.",
            symbolName: "paintbrush.pointed",
            languages: [.css],
            body: "$0 {\n  \n}\n"
        ),
        EditorPluginSnippet(
            id: "snippet.config.env",
            pluginID: "forge.snippet-library",
            title: "Environment Variable",
            detail: "Insert a dotenv-style key/value pair.",
            symbolName: "slider.horizontal.3",
            languages: [.config],
            body: "$0=\n"
        ),
        EditorPluginSnippet(
            id: "snippet.config.yaml-service",
            pluginID: "forge.snippet-library",
            title: "YAML Service Block",
            detail: "Insert a small service-style YAML block.",
            symbolName: "server.rack",
            languages: [.config],
            body: "service:\n  name: $0\n  enabled: true\n"
        ),
    ]
}
