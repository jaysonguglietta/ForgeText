import SwiftUI

struct CloneRepositoryView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var appState: AppState
    @State private var lastSuggestedDirectoryName = ""

    private var destinationPreview: String {
        let parent = appState.cloneRepositoryState.destinationParentPath.trimmingCharacters(in: .whitespacesAndNewlines)
        let name = appState.cloneRepositoryState.directoryName.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !parent.isEmpty, !name.isEmpty else {
            return "Choose a local folder and repository name."
        }

        return URL(fileURLWithPath: parent).appendingPathComponent(name, isDirectory: true).path(percentEncoded: false)
    }

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text("Clone Repository")
                        .font(.system(size: 20, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)

                    Spacer()

                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                }

                Text("Paste a GitHub HTTPS URL like `https://github.com/org/repo.git` or an SSH URL like `git@github.com:org/repo.git`.")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)

                TextField("https://github.com/org/repo.git", text: $appState.cloneRepositoryState.repositorySpecifier)
                    .textFieldStyle(.plain)
                    .retroTextField()
                    .onAppear {
                        let suggestion = GitCloneService.suggestedDirectoryName(for: appState.cloneRepositoryState.repositorySpecifier) ?? ""
                        lastSuggestedDirectoryName = suggestion
                        if appState.cloneRepositoryState.directoryName.isEmpty {
                            appState.cloneRepositoryState.directoryName = suggestion
                        }
                    }
                    .onChange(of: appState.cloneRepositoryState.repositorySpecifier) { _, newValue in
                        let suggestion = GitCloneService.suggestedDirectoryName(for: newValue) ?? ""
                        if appState.cloneRepositoryState.directoryName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || appState.cloneRepositoryState.directoryName == lastSuggestedDirectoryName {
                            appState.cloneRepositoryState.directoryName = suggestion
                        }
                        lastSuggestedDirectoryName = suggestion
                    }

                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Destination Folder")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(RetroPalette.visited)

                        TextField("Parent folder", text: $appState.cloneRepositoryState.destinationParentPath)
                            .textFieldStyle(.plain)
                            .retroTextField()
                    }

                    Button("Browse") {
                        appState.chooseCloneDestinationParent()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .primary))
                    .padding(.top, 18)
                }

                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Repository Folder Name")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(RetroPalette.visited)

                        TextField("repo-name", text: $appState.cloneRepositoryState.directoryName)
                            .textFieldStyle(.plain)
                            .retroTextField()
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Branch (Optional)")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(RetroPalette.visited)

                        TextField("main", text: $appState.cloneRepositoryState.branchName)
                            .textFieldStyle(.plain)
                            .retroTextField()
                    }
                }

                Toggle("Use shallow clone (`--depth 1`)", isOn: $appState.cloneRepositoryState.usesShallowClone)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)

                VStack(alignment: .leading, spacing: 6) {
                    Text("Clone Target")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroPalette.visited)

                    Text(destinationPreview)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeBlue)
                }

                if let statusMessage = appState.cloneRepositoryState.statusMessage {
                    Text(statusMessage)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(RetroPalette.link)
                }

                HStack {
                    Button(appState.cloneRepositoryState.isCloning ? "Cloning..." : "Clone and Open") {
                        appState.cloneRepository()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .accent))
                    .disabled(appState.cloneRepositoryState.isCloning)

                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                    .disabled(appState.cloneRepositoryState.isCloning)
                }
            }
            .padding(18)
            .frame(minWidth: 720, minHeight: 430)
            .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)
            .padding(18)
        }
    }
}
