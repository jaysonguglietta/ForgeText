import SwiftUI

struct DocumentTabStripView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(appState.documents) { document in
                    let isSelected = appState.selectedDocumentID == document.id

                    HStack(spacing: 7) {
                        Label(document.displayName, systemImage: document.language.symbolName)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                            .foregroundStyle(isSelected ? RetroPalette.ink : RetroPalette.mutedInk)

                        if document.isDirty {
                            Circle()
                                .fill(RetroPalette.warning)
                                .frame(width: 7, height: 7)
                        }

                        Button {
                            appState.closeDocument(id: document.id)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .buttonStyle(RetroIconButtonStyle(accent: isSelected ? RetroPalette.chromeBlue : RetroPalette.chromeTeal))
                    }
                    .padding(.horizontal, 11)
                    .padding(.vertical, 7)
                    .frame(minWidth: 150, alignment: .leading)
                    .background(
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(isSelected ? RetroPalette.chromeGold.opacity(0.72) : RetroPalette.chromeTeal.opacity(0.28))
                                .frame(height: 2)

                            RetroPanelBackground(
                                fill: isSelected ? RetroPalette.panelFill : RetroPalette.panelFillMuted,
                                accent: isSelected ? RetroPalette.chromeBlue : RetroPalette.chromeBlue.opacity(0.72)
                            )
                        }
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
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
        .retroPanel(fill: RetroPalette.railFill, accent: RetroPalette.chromeBlue)
    }
}
