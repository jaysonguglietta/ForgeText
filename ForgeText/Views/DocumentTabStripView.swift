import SwiftUI

struct DocumentTabStripView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(appState.documents) { document in
                    let isSelected = appState.selectedDocumentID == document.id

                    HStack(spacing: 8) {
                        Label(document.displayName, systemImage: document.language.symbolName)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .lineLimit(1)
                            .foregroundStyle(isSelected ? RetroPalette.ink : RetroPalette.mutedInk)

                        if document.isDirty {
                            RetroCapsuleLabel(text: "edit", accent: RetroPalette.warning)
                        }

                        Button {
                            appState.closeDocument(id: document.id)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .buttonStyle(RetroIconButtonStyle(accent: isSelected ? RetroPalette.chromePink : RetroPalette.chromeTeal))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .frame(minWidth: 170, alignment: .leading)
                    .background(
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(isSelected ? RetroPalette.chromeGold : RetroPalette.chromeTeal.opacity(0.55))
                                .frame(height: 4)

                            RetroPanelBackground(
                                fill: isSelected ? RetroPalette.panelFill : RetroPalette.panelFillMuted,
                                accent: isSelected ? RetroPalette.chromePink : RetroPalette.chromeBlue
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
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(RetroActionButtonStyle(tone: .accent))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .retroPanel(fill: RetroPalette.railFill, accent: RetroPalette.chromeTeal)
    }
}
