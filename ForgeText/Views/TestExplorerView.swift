import SwiftUI

struct TestExplorerView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Label("Test Explorer", systemImage: "checklist.checked")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)

                    Spacer(minLength: 0)

                    Button("Run Selected Test") {
                        appState.runSelectedTestTask()
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
                    ScrollView {
                        VStack(spacing: 10) {
                            if appState.availableTestTasks.isEmpty {
                                Text("No test tasks were detected in the current workspace.")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(RetroPalette.link)
                                    .padding(.top, 24)
                            } else {
                                ForEach(appState.availableTestTasks) { task in
                                    Button {
                                        appState.testExplorerState.selectedTaskID = task.id
                                    } label: {
                                        HStack(spacing: 10) {
                                            Image(systemName: task.symbolName)
                                                .foregroundStyle(RetroPalette.chromePink)

                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(task.title)
                                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                                                    .foregroundStyle(RetroPalette.ink)
                                                Text(task.commandDescription)
                                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                                    .foregroundStyle(RetroPalette.link)
                                            }

                                            Spacer(minLength: 0)
                                        }
                                        .padding(10)
                                        .retroPanel(
                                            fill: appState.testExplorerState.selectedTaskID == task.id ? RetroPalette.chromeCyan.opacity(0.35) : RetroPalette.panelFill,
                                            accent: appState.testExplorerState.selectedTaskID == task.id ? RetroPalette.chromePink : RetroPalette.chromeTeal
                                        )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(16)
                    }
                    .frame(minWidth: 320)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if let lastRun = appState.testExplorerState.lastRun {
                                HStack(spacing: 8) {
                                    RetroCapsuleLabel(text: lastRun.status.displayName, accent: accent(for: lastRun.status))
                                    if let exitCode = lastRun.exitCode {
                                        RetroCapsuleLabel(text: "exit \(exitCode)", accent: RetroPalette.chromeBlue)
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
                                Text("Run a detected test task to inspect test output here.")
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(RetroPalette.link)
                            }
                        }
                        .padding(16)
                    }
                }
            }
            .padding(14)
        }
        .frame(minWidth: 980, minHeight: 620)
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
