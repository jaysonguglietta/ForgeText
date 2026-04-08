import SwiftUI

struct DocumentTabStripView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ZStack {
            RetroBackdropView()

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(appState.documents) { document in
                        HStack(spacing: 8) {
                            Label(document.displayName, systemImage: document.language.symbolName)
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .lineLimit(1)
                                .foregroundStyle(appState.selectedDocumentID == document.id ? RetroPalette.ink : RetroPalette.link)

                            if document.isDirty {
                                RetroCapsuleLabel(text: "edit", accent: RetroPalette.warning)
                            }

                            Button {
                                appState.closeDocument(id: document.id)
                            } label: {
                                Image(systemName: "xmark")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .buttonStyle(RetroActionButtonStyle(tone: .secondary))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .retroPanel(
                            fill: appState.selectedDocumentID == document.id ? RetroPalette.chromeCyan.opacity(0.35) : RetroPalette.panelFill,
                            accent: appState.selectedDocumentID == document.id ? RetroPalette.chromePink : RetroPalette.chromeBlue
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            appState.selectDocument(document.id)
                        }
                    }

                    Button {
                        appState.newDocument()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                            Text("NEW")
                        }
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .accent))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
        }
        .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeTeal)
    }
}
