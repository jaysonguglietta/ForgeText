import SwiftUI

struct TaskRunnerView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filteredTasks: [EditorPluginTask] {
        let tasks = appState.pluginTaskState.tasks
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return tasks
        }

        return tasks.filter { task in
            let candidate = [task.title, task.subtitle, task.commandDescription].joined(separator: " ")
            return candidate.localizedCaseInsensitiveContains(trimmedQuery)
        }
    }

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Label("Task Runner", systemImage: "play.square.stack")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)

                    Spacer(minLength: 0)

                    Button("Refresh") {
                        appState.showTaskRunnerPanel()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .primary))
                }
                .padding(16)
                .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)

                RetroRule()

                HSplitView {
                    VStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 12) {
                            if let workspaceURL = appState.activeWorkspaceURL {
                                Text(workspaceURL.path(percentEncoded: false))
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(RetroPalette.link)
                                    .lineLimit(2)
                            }

                            TextField("Search tasks", text: $query)
                                .textFieldStyle(.plain)
                                .font(.system(size: 13, weight: .medium, design: .monospaced))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeBlue)
                        }
                        .padding(16)
                        .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)

                        RetroRule()

                        ScrollView {
                            VStack(spacing: 10) {
                                if filteredTasks.isEmpty {
                                    Text("No workspace tasks were detected.")
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundStyle(RetroPalette.link)
                                        .padding(.top, 24)
                                } else {
                                    ForEach(filteredTasks) { task in
                                        taskRow(task)
                                    }
                                }
                            }
                            .padding(16)
                        }
                    }
                    .frame(minWidth: 300)

                    VStack(spacing: 0) {
                        if let task = appState.selectedPluginTask {
                            taskDetail(task)
                        } else {
                            VStack(spacing: 12) {
                                Text("Select a task to inspect or run it.")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(RetroPalette.link)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(24)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(14)
        }
        .frame(minWidth: 980, minHeight: 640)
    }

    private func taskRow(_ task: EditorPluginTask) -> some View {
        let isSelected = appState.pluginTaskState.selectedTaskID == task.id

        return Button {
            appState.selectPluginTask(task.id)
        } label: {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: task.symbolName)
                    .foregroundStyle(isSelected ? RetroPalette.chromePink : RetroPalette.link)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)

                    Text(task.subtitle)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(RetroPalette.link)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }
            .padding(10)
            .retroPanel(
                fill: isSelected ? RetroPalette.chromeCyan.opacity(0.35) : RetroPalette.panelFill,
                accent: isSelected ? RetroPalette.chromePink : RetroPalette.chromeTeal
            )
        }
        .buttonStyle(.plain)
    }

    private func taskDetail(_ task: EditorPluginTask) -> some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(task.title)
                            .font(.system(size: 18, weight: .black, design: .monospaced))
                            .foregroundStyle(RetroPalette.ink)

                        Text(task.subtitle)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(RetroPalette.link)
                    }

                    Spacer(minLength: 0)

                    Button("Run Task") {
                        appState.runWorkspaceTask(withID: task.id)
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .primary))
                }

                Text(task.commandDescription)
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.ink)
                    .padding(10)
                    .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeBlue)
            }
            .padding(16)
            .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)

            RetroRule()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let lastRun = appState.pluginTaskState.lastRun {
                        HStack(spacing: 8) {
                            RetroCapsuleLabel(text: lastRun.status.displayName, accent: accent(for: lastRun.status))

                            if let exitCode = lastRun.exitCode {
                                RetroCapsuleLabel(text: "exit \(exitCode)", accent: RetroPalette.chromeTeal)
                            }
                        }

                        Text(lastRun.output)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(RetroPalette.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                            .padding(14)
                            .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeTeal)
                    } else {
                        Text("Run a task to capture build or test output here.")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(RetroPalette.link)
                    }
                }
                .padding(16)
            }
        }
    }

    private func accent(for status: PluginExecutionStatus) -> Color {
        switch status {
        case .idle:
            return RetroPalette.chromeTeal
        case .running:
            return RetroPalette.chromeGold
        case .succeeded:
            return RetroPalette.success
        case .failed:
            return RetroPalette.danger
        }
    }
}
