import SwiftUI

struct TerminalConsoleView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    private var isRestrictedWorkspace: Bool {
        appState.workspaceTrustMode == .restricted && !appState.workspaceRootURLs.isEmpty
    }

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Label("Embedded Terminal", systemImage: "terminal.fill")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)

                    Spacer(minLength: 0)

                    Button("Problems") {
                        appState.showProblemsPanelView()
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

                VStack(alignment: .leading, spacing: 12) {
                    Text(appState.activeWorkspaceURL?.path(percentEncoded: false) ?? "No workspace folder selected")
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(RetroPalette.link)

                    if isRestrictedWorkspace {
                        Text("Restricted mode is blocking terminal execution for this workspace. Trust it in Workspace Center to run commands.")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(RetroPalette.warning)
                    }

                    HStack(spacing: 10) {
                        TextField("Run a command in the current workspace", text: $appState.terminalPanelState.commandText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeBlue)

                        Button("Run") {
                            appState.runEmbeddedTerminalCommand()
                        }
                        .buttonStyle(RetroActionButtonStyle(tone: .primary))
                        .disabled(isRestrictedWorkspace)
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(EmbeddedTerminalService.suggestedCommands, id: \.self) { command in
                                Button(command) {
                                    appState.terminalPanelState.commandText = command
                                    appState.runEmbeddedTerminalCommand(command)
                                }
                                .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                                .disabled(isRestrictedWorkspace)
                            }

                            ForEach(appState.terminalPanelState.history, id: \.self) { command in
                                Button(command) {
                                    appState.terminalPanelState.commandText = command
                                }
                                .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                            }
                        }
                    }
                }
                .padding(16)
                .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)

                RetroRule()

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if let lastRun = appState.terminalPanelState.lastRun {
                            HStack(spacing: 8) {
                                RetroCapsuleLabel(text: lastRun.status.displayName, accent: accent(for: lastRun.status))

                                if let exitCode = lastRun.exitCode {
                                    RetroCapsuleLabel(text: "exit \(exitCode)", accent: RetroPalette.chromeTeal)
                                }
                            }

                            Text(lastRun.command)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundStyle(RetroPalette.ink)

                            Text(lastRun.output)
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(RetroPalette.ink)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(14)
                                .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeTeal)
                        } else {
                            Text("Run a command to capture shell output here.")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(RetroPalette.link)
                        }
                    }
                    .padding(16)
                }
            }
            .padding(14)
        }
        .frame(minWidth: 900, minHeight: 620)
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
