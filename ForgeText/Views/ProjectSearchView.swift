import SwiftUI

struct ProjectSearchView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(spacing: 0) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Label("Project Search", systemImage: "magnifyingglass.circle")
                            .font(.system(size: 22, weight: .black, design: .monospaced))
                            .foregroundStyle(RetroPalette.ink)

                        Spacer(minLength: 0)

                        Button("Choose Folder") {
                            appState.chooseWorkspaceRoot()
                        }
                        .buttonStyle(RetroActionButtonStyle(tone: .primary))
                        .accessibilityLabel("Choose search folder")

                        Button("Search") {
                            appState.runProjectSearch()
                        }
                        .buttonStyle(RetroActionButtonStyle(tone: .accent))
                        .disabled(appState.projectSearchState.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .accessibilityLabel("Run project search")
                    }

                    TextField("Search files in a folder", text: $appState.projectSearchState.query)
                        .textFieldStyle(.plain)
                        .retroTextField()
                        .onSubmit {
                            appState.runProjectSearch()
                        }
                        .accessibilityLabel("Project search query")

                    HStack(spacing: 12) {
                        Toggle("Case Sensitive", isOn: $appState.projectSearchState.isCaseSensitive)
                        Toggle("Regex", isOn: $appState.projectSearchState.usesRegularExpression)
                        Toggle("Include Hidden", isOn: $appState.projectSearchState.includeHiddenFiles)
                    }
                    .toggleStyle(.checkbox)
                    .tint(RetroPalette.chromePink)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Root Folder")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundStyle(RetroPalette.visited)
                        Text(appState.projectSearchState.rootURL?.path(percentEncoded: false) ?? "No folder selected")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(RetroPalette.link)
                            .textSelection(.enabled)
                    }

                    HStack(spacing: 12) {
                        Text(appState.projectSearchState.summary)
                            .foregroundStyle(RetroPalette.link)

                        if !appState.projectSearchState.isSearching, appState.projectSearchState.elapsedTime > 0 {
                            Text(String(format: "%.2fs", appState.projectSearchState.elapsedTime))
                                .foregroundStyle(RetroPalette.visited)
                        }

                        Spacer(minLength: 0)
                    }
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                }
                .padding(20)
                .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)

                RetroRule()

                if appState.projectSearchState.hits.isEmpty {
                    ContentUnavailableView(
                        "No Results Yet",
                        systemImage: "doc.text.magnifyingglass",
                        description: Text("Choose a folder and search for text across your project files.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List(appState.projectSearchState.hits) { hit in
                        Button {
                            appState.openProjectSearchHit(hit)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 8) {
                                    Image(systemName: "doc.text")
                                        .foregroundStyle(RetroPalette.chromePink)
                                    Text(hit.fileURL.lastPathComponent)
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundStyle(RetroPalette.ink)
                                    Spacer(minLength: 0)
                                    Text("Ln \(hit.lineNumber), Col \(hit.columnNumber)")
                                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                                        .foregroundStyle(RetroPalette.link)
                                }

                                Text(hit.fileURL.path(percentEncoded: false))
                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                    .foregroundStyle(RetroPalette.visited)
                                    .lineLimit(1)

                                Text(hit.lineText)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(RetroPalette.ink)
                                    .lineLimit(2)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(RetroPalette.panelFillMuted)
                        .accessibilityLabel("Open search result \(hit.fileURL.lastPathComponent) line \(hit.lineNumber)")
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .background(RetroPalette.panelFillMuted)
                }
            }
            .frame(minWidth: 860, minHeight: 560)
            .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromeBlue)
            .padding(18)
        }
    }
}
