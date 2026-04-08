import Foundation

enum WorkspaceTaskService {
    static func detectTasks(rootURL: URL?) -> [EditorPluginTask] {
        guard let rootURL else {
            return []
        }

        var tasks: [EditorPluginTask] = []
        tasks += swiftPackageTasks(in: rootURL)
        tasks += nodeTasks(in: rootURL)
        tasks += pythonTasks(in: rootURL)
        tasks += makeTasks(in: rootURL)

        var seenIDs = Set<String>()
        return tasks.filter { seenIDs.insert($0.id).inserted }
    }

    static func run(
        _ task: EditorPluginTask,
        workspaceRoot: URL?,
        currentDocument: EditorDocument?
    ) async -> PluginTaskRun {
        let startedAt = Date()

        do {
            let workingDirectory = resolveWorkingDirectory(for: task, workspaceRoot: workspaceRoot, currentDocument: currentDocument)
            let result = try CommandExecutionService.execute(
                "/usr/bin/env",
                arguments: [task.executable] + task.arguments,
                currentDirectoryURL: workingDirectory
            )

            let output = mergedOutput(from: result)
            return PluginTaskRun(
                taskID: task.id,
                taskTitle: task.title,
                commandDescription: task.commandDescription,
                startedAt: startedAt,
                endedAt: Date(),
                output: output.isEmpty ? "Task finished without output." : output,
                status: result.terminationStatus == 0 ? .succeeded : .failed,
                exitCode: result.terminationStatus
            )
        } catch {
            return PluginTaskRun(
                taskID: task.id,
                taskTitle: task.title,
                commandDescription: task.commandDescription,
                startedAt: startedAt,
                endedAt: Date(),
                output: error.localizedDescription,
                status: .failed,
                exitCode: nil
            )
        }
    }

    private static func swiftPackageTasks(in rootURL: URL) -> [EditorPluginTask] {
        guard FileManager.default.fileExists(atPath: rootURL.appendingPathComponent("Package.swift").path) else {
            return []
        }

        return [
            EditorPluginTask(
                id: "task.swift.build",
                pluginID: "forge.workspace-tasks",
                pluginName: "Workspace Tasks",
                title: "Swift Build",
                subtitle: "Run swift build for this package",
                symbolName: "hammer",
                executable: "swift",
                arguments: ["build"],
                workingDirectory: .workspaceRoot,
                role: .build
            ),
            EditorPluginTask(
                id: "task.swift.test",
                pluginID: "forge.workspace-tasks",
                pluginName: "Workspace Tasks",
                title: "Swift Test",
                subtitle: "Run swift test for this package",
                symbolName: "checkmark.circle",
                executable: "swift",
                arguments: ["test"],
                workingDirectory: .workspaceRoot,
                role: .test
            ),
        ]
    }

    private static func nodeTasks(in rootURL: URL) -> [EditorPluginTask] {
        let packageURL = rootURL.appendingPathComponent("package.json")
        guard
            FileManager.default.fileExists(atPath: packageURL.path),
            let data = try? Data(contentsOf: packageURL),
            let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let scripts = object["scripts"] as? [String: String]
        else {
            return []
        }

        let sortedScripts = scripts.keys.sorted()
        return sortedScripts.map { name in
            EditorPluginTask(
                id: "task.node.\(name)",
                pluginID: "forge.workspace-tasks",
                pluginName: "Workspace Tasks",
                title: "npm \(name)",
                subtitle: "Run the '\(name)' package.json script",
                symbolName: symbolName(forNodeScript: name),
                executable: "npm",
                arguments: ["run", name],
                workingDirectory: .workspaceRoot,
                role: role(forNodeScript: name)
            )
        }
    }

    private static func pythonTasks(in rootURL: URL) -> [EditorPluginTask] {
        let hasPythonProject = [
            "pyproject.toml",
            "requirements.txt",
            "setup.py",
        ]
        .contains { FileManager.default.fileExists(atPath: rootURL.appendingPathComponent($0).path) }

        guard hasPythonProject else {
            return []
        }

        return [
            EditorPluginTask(
                id: "task.python.test",
                pluginID: "forge.workspace-tasks",
                pluginName: "Workspace Tasks",
                title: "Python Test",
                subtitle: "Run pytest for this workspace",
                symbolName: "checkmark.circle",
                executable: "python3",
                arguments: ["-m", "pytest"],
                workingDirectory: .workspaceRoot,
                role: .test
            ),
            EditorPluginTask(
                id: "task.python.lint",
                pluginID: "forge.workspace-tasks",
                pluginName: "Workspace Tasks",
                title: "Python Lint",
                subtitle: "Run Ruff checks for this workspace",
                symbolName: "checklist",
                executable: "python3",
                arguments: ["-m", "ruff", "check", "."],
                workingDirectory: .workspaceRoot,
                role: .lint
            ),
        ]
    }

    private static func makeTasks(in rootURL: URL) -> [EditorPluginTask] {
        let makefileCandidates = ["Makefile", "makefile"]
        guard let makefileName = makefileCandidates.first(where: {
            FileManager.default.fileExists(atPath: rootURL.appendingPathComponent($0).path)
        }) else {
            return []
        }

        let makefileURL = rootURL.appendingPathComponent(makefileName)
        let targetNames = parseMakeTargets(from: makefileURL)
        let preferredTargets = targetNames.filter { target in
            ["build", "test", "lint", "run"].contains(target.lowercased())
        }

        return preferredTargets.map { target in
            EditorPluginTask(
                id: "task.make.\(target)",
                pluginID: "forge.workspace-tasks",
                pluginName: "Workspace Tasks",
                title: "make \(target)",
                subtitle: "Run the '\(target)' make target",
                symbolName: symbolName(forMakeTarget: target),
                executable: "make",
                arguments: [target],
                workingDirectory: .workspaceRoot,
                role: role(forMakeTarget: target)
            )
        }
    }

    private static func parseMakeTargets(from url: URL) -> [String] {
        guard let content = try? String(contentsOf: url) else {
            return []
        }

        return content
            .split(whereSeparator: \.isNewline)
            .compactMap { line in
                let value = String(line)
                guard !value.hasPrefix("\t"), !value.hasPrefix("#"), let separator = value.firstIndex(of: ":") else {
                    return nil
                }

                let target = value[..<separator].trimmingCharacters(in: .whitespaces)
                guard !target.isEmpty, !target.contains(" ") else {
                    return nil
                }

                return target
            }
    }

    private static func resolveWorkingDirectory(
        for task: EditorPluginTask,
        workspaceRoot: URL?,
        currentDocument: EditorDocument?
    ) -> URL? {
        switch task.workingDirectory {
        case .workspaceRoot:
            return workspaceRoot
        case .documentDirectory:
            return currentDocument?.fileURL?.deletingLastPathComponent() ?? workspaceRoot
        }
    }

    private static func mergedOutput(from result: CommandExecutionService.CommandResult) -> String {
        let stdout = String(data: result.stdout, encoding: .utf8) ?? ""
        let stderr = String(data: result.stderr, encoding: .utf8) ?? ""

        let combined = [stdout, stderr]
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: stdout.isEmpty || stderr.isEmpty ? "" : "\n\n")

        return combined
    }

    private static func role(forNodeScript name: String) -> PluginTaskRole {
        switch name.lowercased() {
        case "build":
            return .build
        case "test":
            return .test
        case "lint":
            return .lint
        case "start", "dev", "serve":
            return .run
        default:
            return .custom
        }
    }

    private static func symbolName(forNodeScript name: String) -> String {
        switch role(forNodeScript: name) {
        case .build:
            return "hammer"
        case .test:
            return "checkmark.circle"
        case .lint:
            return "checklist"
        case .run:
            return "play.circle"
        case .custom:
            return "terminal"
        }
    }

    private static func role(forMakeTarget target: String) -> PluginTaskRole {
        switch target.lowercased() {
        case "build":
            return .build
        case "test":
            return .test
        case "lint":
            return .lint
        case "run":
            return .run
        default:
            return .custom
        }
    }

    private static func symbolName(forMakeTarget target: String) -> String {
        switch role(forMakeTarget: target) {
        case .build:
            return "hammer"
        case .test:
            return "checkmark.circle"
        case .lint:
            return "checklist"
        case .run:
            return "play.circle"
        case .custom:
            return "terminal"
        }
    }
}
