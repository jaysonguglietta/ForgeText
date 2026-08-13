import SwiftUI

struct ChunkedTextView: View {
    let document: EditorDocument
    let theme: EditorTheme
    let fontSize: CGFloat

    @State private var window: ChunkedTextWindow?
    @State private var text = ""
    @State private var selection = NSRange(location: 0, length: 0)
    @State private var query = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var focusRequestToken = UUID()

    var body: some View {
        VStack(spacing: 0) {
            controls
            Divider()
            EditorContainerView(
                text: $text,
                selectedRange: $selection,
                theme: theme,
                language: document.language,
                sourceURL: document.fileURL,
                wrapLines: false,
                fontSize: fontSize,
                findState: FindState(),
                largeFileMode: true,
                isEditable: false,
                focusRequestToken: focusRequestToken,
                lineDecorations: []
            )
        }
        .task(id: document.fileURL) {
            let initialOffset = document.language == .log
                ? max(0, (document.fileSize ?? 0) - Int64(ChunkedTextFileService.defaultWindowBytes))
                : 0
            await load(offset: initialOffset)
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Button("Start") { Task { await load(offset: 0) } }
            Button("Previous") {
                Task { await load(offset: max(0, (window?.startOffset ?? 0) - Int64(ChunkedTextFileService.defaultWindowBytes))) }
            }
            Button("Next") { Task { await load(offset: window?.endOffset ?? 0) } }
            Button("End") {
                Task { await load(offset: max(0, (window?.fileSize ?? 0) - Int64(ChunkedTextFileService.defaultWindowBytes))) }
            }
            .disabled(isLoading)

            Divider().frame(height: 18)
            TextField("Find bytes", text: $query)
                .textFieldStyle(.roundedBorder)
                .frame(width: 180)
                .onSubmit { Task { await findNext() } }
            Button("Find Next") { Task { await findNext() } }
                .disabled(query.isEmpty || isLoading)
            Spacer()
            if let window {
                Text("\(ByteCountFormatter.string(fromByteCount: window.startOffset, countStyle: .file)) - \(ByteCountFormatter.string(fromByteCount: window.endOffset, countStyle: .file)) of \(ByteCountFormatter.string(fromByteCount: window.fileSize, countStyle: .file))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            if let errorMessage {
                Text(errorMessage).font(.caption).foregroundStyle(.red).lineLimit(1)
            }
            if isLoading { ProgressView().controlSize(.small) }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Large file chunk navigation")
    }

    @MainActor
    private func load(offset: Int64) async {
        guard let url = document.fileURL else { return }
        isLoading = true
        errorMessage = nil
        do {
            let loaded = try await Task.detached(priority: .userInitiated) {
                try ChunkedTextFileService.readWindow(from: url, offset: offset)
            }.value
            window = loaded
            text = loaded.text
            selection = NSRange(location: 0, length: 0)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    @MainActor
    private func findNext() async {
        guard let url = document.fileURL else { return }
        isLoading = true
        let searchQuery = query
        let startingOffset = window?.endOffset ?? 0
        do {
            let match = try await Task.detached(priority: .userInitiated) {
                try ChunkedTextFileService.find(searchQuery, in: url, startingAt: startingOffset)
            }.value
            if let match {
                await load(offset: match)
            } else {
                errorMessage = "No match in the next 512 MB."
                isLoading = false
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
        }
    }
}
