import SwiftUI

struct WorkspaceSessionsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState
    @State private var sessionName = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Workspace Sessions")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Spacer()
                Button("Done") {
                    dismiss()
                }
            }

            HStack(spacing: 10) {
                TextField("Session name", text: $sessionName)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Workspace session name")

                Button("Save Current") {
                    appState.saveCurrentWorkspaceSession(named: sessionName)
                    sessionName = ""
                }
                .buttonStyle(.borderedProminent)
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
                                .font(.system(size: 13, weight: .semibold))
                            Text("\(session.openFilePaths.count + session.openRemoteSpecs.count) files")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(session.savedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer(minLength: 0)

                        Button("Load") {
                            appState.loadWorkspaceSession(session)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Load workspace session \(session.name)")

                        Button("Delete", role: .destructive) {
                            appState.deleteWorkspaceSession(session)
                        }
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Delete workspace session \(session.name)")
                    }
                }
                .listStyle(.inset)
            }
        }
        .padding(18)
        .frame(minWidth: 700, minHeight: 420)
    }
}
