import SwiftUI

struct DocumentTabStripView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(appState.documents) { document in
                    HStack(spacing: 8) {
                        Label(document.displayName, systemImage: document.language.symbolName)
                            .font(.system(size: 12, weight: .semibold))
                            .lineLimit(1)
                            .foregroundStyle(appState.selectedDocumentID == document.id ? .primary : .secondary)

                        if document.isDirty {
                            Circle()
                                .fill(Color.orange)
                                .frame(width: 7, height: 7)
                        }

                        Button {
                            appState.closeDocument(id: document.id)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(appState.selectedDocumentID == document.id ? Color.accentColor.opacity(0.14) : Color.clear)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .onTapGesture {
                        appState.selectDocument(document.id)
                    }
                }

                Button {
                    appState.newDocument()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .bold))
                        .padding(8)
                        .background(
                            Circle()
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

