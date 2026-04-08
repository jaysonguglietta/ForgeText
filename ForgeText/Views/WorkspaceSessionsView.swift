import SwiftUI

struct WorkspaceSessionsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState
    @State private var sessionName = ""

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Workspace Sessions")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                }

                HStack(spacing: 10) {
                    TextField("Session name", text: $sessionName)
                        .textFieldStyle(.plain)
                        .retroTextField()
                        .accessibilityLabel("Workspace session name")

                    Button("Save Current") {
                        appState.saveCurrentWorkspaceSession(named: sessionName)
                        sessionName = ""
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .accent))
                    .accessibilityLabel("Save current workspace session")
                }

                if appState.workspaceSessions.isEmpty {
                    ContentUnavailableView(
                        "No Saved Sessions",
                        systemImage: "square.stack.3d.up",
                        description: Text("Save the current workspace to reopen groups of files and editor settings later.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(appState.workspaceSessions) { session in
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 5) {
                                Text(session.name)
                                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                                    .foregroundStyle(RetroPalette.ink)
                                Text("\(session.openFilePaths.count + session.openRemoteSpecs.count) files")
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(RetroPalette.link)
                                Text(session.savedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(RetroPalette.visited)
                            }

                            Spacer(minLength: 0)

                            Button("Load") {
                                appState.loadWorkspaceSession(session)
                                dismiss()
                            }
                            .buttonStyle(RetroActionButtonStyle(tone: .accent))
                            .accessibilityLabel("Load workspace session \(session.name)")

                            Button("Delete", role: .destructive) {
                                appState.deleteWorkspaceSession(session)
                            }
                            .buttonStyle(RetroActionButtonStyle(tone: .danger))
                            .accessibilityLabel("Delete workspace session \(session.name)")
                        }
                        .listRowBackground(RetroPalette.panelFillMuted)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(RetroPalette.panelFillMuted)
                }
            }
            .padding(18)
            .frame(minWidth: 700, minHeight: 420)
            .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)
            .padding(18)
        }
    }
}
