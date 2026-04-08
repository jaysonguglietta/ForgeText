import SwiftUI

struct GitWorkbenchView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Label("Git Workbench", systemImage: "point.topleft.down.curvedto.point.bottomright.up")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)

                    Spacer(minLength: 0)

                    Button("Refresh") {
                        appState.refreshGitStatus()
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
                        VStack(alignment: .leading, spacing: 10) {
                            if let summary = appState.gitRepositorySummary {
                                Text(summary.rootURL.path(percentEncoded: false))
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(RetroPalette.link)
                                    .lineLimit(2)
                            }

                            if let message = appState.gitPanelState.lastOperationMessage {
                                Text(message)
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(RetroPalette.link)
                            }
                        }
                        .padding(16)
                        .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)

                        RetroRule()

                        ScrollView {
                            VStack(spacing: 10) {
                                if appState.gitPanelState.changedFiles.isEmpty {
                                    Text("No changed files in the current repository.")
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundStyle(RetroPalette.link)
                                        .padding(.top, 24)
                                } else {
                                    ForEach(appState.gitPanelState.changedFiles) { file in
                                        changedFileCard(file)
                                    }
                                }
                            }
                            .padding(16)
                        }
                    }
                    .frame(minWidth: 360)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            gitActions
                            commitSection
                            branchSection
                            stashSection
                        }
                        .padding(16)
                    }
                }
            }
            .padding(14)
        }
        .frame(minWidth: 1080, minHeight: 720)
    }

    private var gitActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Repository Actions")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(RetroPalette.ink)

            HStack(spacing: 10) {
                Button("Fetch") {
                    appState.fetchGitRepository()
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                Button("Pull") {
                    appState.pullGitRepository()
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                Button("Push") {
                    appState.pushGitRepository()
                }
                .buttonStyle(RetroActionButtonStyle(tone: .primary))
            }
        }
        .padding(14)
        .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)
    }

    private var commitSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Commit")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(RetroPalette.ink)

            TextEditor(text: Binding(
                get: { appState.gitPanelState.commitMessage },
                set: { appState.gitPanelState.commitMessage = $0 }
            ))
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .frame(minHeight: 110)
            .padding(8)
            .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeBlue)

            HStack(spacing: 10) {
                Button("Commit Staged Changes") {
                    appState.commitGitChanges()
                }
                .buttonStyle(RetroActionButtonStyle(tone: .primary))

                Button("AI Draft Message") {
                    appState.runAIQuickAction(.draftCommitMessage)
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))
            }
        }
        .padding(14)
        .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeTeal)
    }

    private var branchSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Branch")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(RetroPalette.ink)

            TextField("feature/branch-name", text: Binding(
                get: { appState.gitPanelState.newBranchName },
                set: { appState.gitPanelState.newBranchName = $0 }
            ))
            .textFieldStyle(.plain)
            .retroTextField()

            Button("Create and Switch Branch") {
                appState.createGitBranch()
            }
            .buttonStyle(RetroActionButtonStyle(tone: .secondary))
        }
        .padding(14)
        .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeGold)
    }

    private var stashSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Stashes")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(RetroPalette.ink)

            TextField("Optional stash message", text: Binding(
                get: { appState.gitPanelState.stashMessage },
                set: { appState.gitPanelState.stashMessage = $0 }
            ))
            .textFieldStyle(.plain)
            .retroTextField()

            HStack(spacing: 10) {
                Button("Stash Changes") {
                    appState.stashGitChanges()
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                Button("Pop Latest") {
                    appState.popGitStash(nil)
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))
            }

            if appState.gitPanelState.stashes.isEmpty {
                Text("No stashes in this repository.")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)
            } else {
                ForEach(appState.gitPanelState.stashes) { stash in
                    HStack(spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(stash.id)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(RetroPalette.ink)
                            Text(stash.summary)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(RetroPalette.link)
                        }

                        Spacer(minLength: 0)

                        Button("Pop") {
                            appState.popGitStash(stash)
                        }
                        .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                    }
                    .padding(10)
                    .retroInsetPanel(fill: RetroPalette.fieldFill, accent: RetroPalette.chromeBlue)
                }
            }
        }
        .padding(14)
        .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromePink)
    }

    private func changedFileCard(_ file: GitChangedFile) -> some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                Text(file.displayName)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(RetroPalette.ink)

                Text(file.relativePath)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(RetroPalette.link)

                Text(file.statusSummary)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(file.isConflicted ? RetroPalette.danger : RetroPalette.visited)
            }

            Spacer(minLength: 0)

            VStack(spacing: 6) {
                Button("Open") {
                    appState.openGitChangedFile(file)
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                Button("Stage") {
                    appState.stageGitChangedFile(file)
                }
                .buttonStyle(RetroActionButtonStyle(tone: .primary))

                Button("Unstage") {
                    appState.unstageGitChangedFile(file)
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))
            }
        }
        .padding(10)
        .retroPanel(fill: RetroPalette.panelFill, accent: file.isConflicted ? RetroPalette.danger : RetroPalette.chromeTeal)
    }
}
