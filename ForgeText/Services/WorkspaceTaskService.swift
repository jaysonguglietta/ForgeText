import Foundation

enum WorkspaceTaskService {
    enum TaskValidationError: LocalizedError {
        case unsafeExecutable(String)

        var errorDescription: String? {
            switch self {
            case let .unsafeExecutable(executable):
                return "ForgeText blocked the task executable '\(executable)' because external tasks must use a safe command name without path separators, options, or control characters."
            }
        }
    }

    static func detectTasks(rootURL: URL?) -> [EditorPluginTask] {
        detectTasks(rootURLs: rootURL.map { [$0] } ?? [])
    }

    static func detectTasks(rootURLs: [URL]) -> [EditorPluginTask] {
        let standardizedRoots = rootURLs.map(\.standardizedFileURL)
        guard !standardizedRoots.isEmpty else {
            return []
        }

        let multipleRoots = standardizedRoots.count > 1
        var tasks: [EditorPluginTask] = []

        for rootURL in standardizedRoots {
            tasks += swiftPackageTasks(in: rootURL, multipleRoots: multipleRoots)
            tasks += nodeTasks(in: rootURL, multipleRoots: multipleRoots)
            tasks += pythonTasks(in: rootURL, multipleRoots: multipleRoots)
            tasks += makeTasks(in: rootURL, multipleRoots: multipleRoots)
        }

        var seenIDs = Set<String>()
        return tasks.filter { seenIDs.insert($0.id).inserted }
    }

    static func run(
        _ task: EditorPluginTask,
        workspaceRoot: URL?,
        currentDocument: EditorDocument?,
        enableCoverage: Bool = false
    ) async -> PluginTaskRun {
        let startedAt = Date()

        do {
            let workingDirectory = resolveWorkingDirectory(for: task, workspaceRoot: workspaceRoot, currentDocument: currentDocument)
            let execution = executionPlan(for: task, enableCoverage: enableCoverage)
            guard isUserSuppliedExecutableAllowed(execution.executable) else {
                throw TaskValidationError.unsafeExecutable(execution.executable)
            }
            let result = try CommandExecutionService.execute(
                "/usr/bin/env",
                arguments: [execution.executable] + execution.arguments,
                currentDirectoryURL: workingDirectory
            )

            let output = mergedOutput(from: result)
            return PluginTaskRun(
                taskID: task.id,
                taskTitle: task.title,
                commandDescription: ([execution.executable] + execution.arguments).joined(separator: " "),
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

    static func isUserSuppliedExecutableAllowed(_ executable: String) -> Bool {
        let trimmed = executable.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              trimmed == executable,
              trimmed != ".",
              trimmed != "..",
              !trimmed.hasPrefix("."),
              !trimmed.hasPrefix("-"),
              !trimmed.contains("/"),
              !trimmed.contains("\\"),
              trimmed.rangeOfCharacter(from: .controlCharacters) == nil
        else {
            return false
        }

        return true
    }

    private static func swiftPackageTasks(in rootURL: URL, multipleRoots: Bool) -> [EditorPluginTask] {
        guard FileManager.default.fileExists(atPath: rootURL.appendingPathComponent("Package.swift").path) else {
            return []
        }

        let scope = taskScopePrefix(for: rootURL, multipleRoots: multipleRoots)

        return [
            EditorPluginTask(
                id: "task.swift.build.\(rootURL.path)",
                pluginID: "forge.workspace-tasks",
                pluginName: "Workspace Tasks",
                title: "\(scope)Swift Build",
                subtitle: "Run swift build for this package",
                symbolName: "hammer",
                executable: "swift",
                arguments: ["build"],
                workingDirectory: .workspaceRoot,
                role: .build,
                rootPath: rootURL.path,
                supportsCoverage: false
            ),
            EditorPluginTask(
                id: "task.swift.test.\(rootURL.path)",
                pluginID: "forge.workspace-tasks",
                pluginName: "Workspace Tasks",
                title: "\(scope)Swift Test",
                subtitle: "Run swift test for this package",
                symbolName: "checkmark.circle",
                executable: "swift",
                arguments: ["test"],
                workingDirectory: .workspaceRoot,
                role: .test,
                rootPath: rootURL.path,
                supportsCoverage: true
            ),
        ]
    }

    private static func nodeTasks(in rootURL: URL, multipleRoots: Bool) -> [EditorPluginTask] {
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
        let scope = taskScopePrefix(for: rootURL, multipleRoots: multipleRoots)
        return sortedScripts.map { name in
            EditorPluginTask(
                id: "task.node.\(name).\(rootURL.path)",
                pluginID: "forge.workspace-tasks",
                pluginName: "Workspace Tasks",
                title: "\(scope)npm \(name)",
                subtitle: "Run the '\(name)' package.json script",
                symbolName: symbolName(forNodeScript: name),
                executable: "npm",
                arguments: ["run", name],
                workingDirectory: .workspaceRoot,
                role: role(forNodeScript: name),
                rootPath: rootURL.path,
                supportsCoverage: role(forNodeScript: name) == .test
            )
        }
    }

    private static func pythonTasks(in rootURL: URL, multipleRoots: Bool) -> [EditorPluginTask] {
        let hasPythonProject = [
            "pyproject.toml",
            "requirements.txt",
            "setup.py",
        ]
        .contains { FileManager.default.fileExists(atPath: rootURL.appendingPathComponent($0).path) }

        guard hasPythonProject else {
            return []
        }

        let scope = taskScopePrefix(for: rootURL, multipleRoots: multipleRoots)

        return [
            EditorPluginTask(
                id: "task.python.test.\(rootURL.path)",
                pluginID: "forge.workspace-tasks",
                pluginName: "Workspace Tasks",
                title: "\(scope)Python Test",
                subtitle: "Run pytest for this workspace",
                symbolName: "checkmark.circle",
                executable: "python3",
                arguments: ["-m", "pytest"],
                workingDirectory: .workspaceRoot,
                role: .test,
                rootPath: rootURL.path,
                supportsCoverage: true
            ),
            EditorPluginTask(
                id: "task.python.lint.\(rootURL.path)",
                pluginID: "forge.workspace-tasks",
                pluginName: "Workspace Tasks",
                title: "\(scope)Python Lint",
                subtitle: "Run Ruff checks for this workspace",
                symbolName: "checklist",
                executable: "python3",
                arguments: ["-m", "ruff", "check", "."],
                workingDirectory: .workspaceRoot,
                role: .lint,
                rootPath: rootURL.path,
                supportsCoverage: false
            ),
        ]
    }

    private static func makeTasks(in rootURL: URL, multipleRoots: Bool) -> [EditorPluginTask] {
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
        let hasCoverageTarget = targetNames.contains { $0.caseInsensitiveCompare("coverage") == .orderedSame }
        let scope = taskScopePrefix(for: rootURL, multipleRoots: multipleRoots)

        return preferredTargets.map { target in
            EditorPluginTask(
                id: "task.make.\(target).\(rootURL.path)",
                pluginID: "forge.workspace-tasks",
                pluginName: "Workspace Tasks",
                title: "\(scope)make \(target)",
                subtitle: "Run the '\(target)' make target",
                symbolName: symbolName(forMakeTarget: target),
                executable: "make",
                arguments: [target],
                workingDirectory: .workspaceRoot,
                role: role(forMakeTarget: target),
                rootPath: rootURL.path,
                supportsCoverage: role(forMakeTarget: target) == .test && hasCoverageTarget
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
            return task.rootPath.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? workspaceRoot
        case .documentDirectory:
            return currentDocument?.fileURL?.deletingLastPathComponent() ?? task.rootPath.map { URL(fileURLWithPath: $0, isDirectory: true) } ?? workspaceRoot
        }
    }

    private static func executionPlan(for task: EditorPluginTask, enableCoverage: Bool) -> (executable: String, arguments: [String]) {
        guard enableCoverage, task.supportsCoverage else {
            return (task.executable, task.arguments)
        }

        if task.executable == "swift", task.arguments == ["test"] {
            return ("swift", ["test", "--enable-code-coverage"])
        }

        if task.executable == "python3", task.arguments == ["-m", "pytest"] {
            return ("python3", ["-m", "pytest", "--cov=."])
        }

        if task.executable == "npm", task.arguments == ["run", "test"] {
            return ("npm", ["run", "test", "--", "--coverage"])
        }

        if task.executable == "make", task.arguments == ["test"] {
            return ("make", ["coverage"])
        }

        return (task.executable, task.arguments)
    }

    private static func taskScopePrefix(for rootURL: URL, multipleRoots: Bool) -> String {
        multipleRoots ? "[\(rootURL.lastPathComponent)] " : ""
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
