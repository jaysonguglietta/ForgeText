import SwiftUI

struct ProjectSearchView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Label("Project Search", systemImage: "magnifyingglass.circle")
                        .font(.system(size: 22, weight: .bold, design: .rounded))

                    Spacer(minLength: 0)

                    Button("Choose Folder") {
                        appState.chooseWorkspaceRoot()
                    }
                    .accessibilityLabel("Choose search folder")

                    Button("Search") {
                        appState.runProjectSearch()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(appState.projectSearchState.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .accessibilityLabel("Run project search")
                }

                TextField("Search files in a folder", text: $appState.projectSearchState.query)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14, design: .monospaced))
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

                VStack(alignment: .leading, spacing: 6) {
                    Text("Root Folder")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(appState.projectSearchState.rootURL?.path(percentEncoded: false) ?? "No folder selected")
                        .font(.system(size: 12, design: .monospaced))
                        .textSelection(.enabled)
                }

                HStack(spacing: 12) {
                    Text(appState.projectSearchState.summary)
                        .foregroundStyle(.secondary)

                    if !appState.projectSearchState.isSearching, appState.projectSearchState.elapsedTime > 0 {
                        Text(String(format: "%.2fs", appState.projectSearchState.elapsedTime))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .font(.caption)
            }
            .padding(20)
            .background(Color(nsColor: .windowBackgroundColor))

            Divider()

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
                                    .foregroundStyle(.secondary)
                                Text(hit.fileURL.lastPathComponent)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.primary)
                                Spacer(minLength: 0)
                                Text("Ln \(hit.lineNumber), Col \(hit.columnNumber)")
                                    .font(.system(size: 11, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }

                            Text(hit.fileURL.path(percentEncoded: false))
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)

                            Text(hit.lineText)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open search result \(hit.fileURL.lastPathComponent) line \(hit.lineNumber)")
                }
                .listStyle(.inset)
            }
        }
        .frame(minWidth: 860, minHeight: 560)
    }
}
