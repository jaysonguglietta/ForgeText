import SwiftUI

struct DocumentTabStripView: View {
    @Environment(\.retroChromeStyle) private var chromeStyle
    @ObservedObject var appState: AppState

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(appState.documents) { document in
                    let isSelected = appState.selectedDocumentID == document.id

                    HStack(spacing: 7) {
                        Label(document.displayName, systemImage: document.language.symbolName)
                            .font(.system(size: 12, weight: .medium))
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
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .frame(minWidth: 132, alignment: .leading)
                    .background(
                        VStack(spacing: 0) {
                            Rectangle()
                                .fill(
                                    isSelected
                                        ? (chromeStyle == .studio ? RetroPalette.chromeBlue.opacity(0.72) : RetroPalette.chromeGold.opacity(0.72))
                                        : (chromeStyle == .studio ? RetroPalette.studioDivider : RetroPalette.chromeTeal.opacity(0.28))
                                )
                                .frame(height: 2)

                            RetroPanelBackground(
                                fill: isSelected
                                    ? (chromeStyle == .studio ? RetroPalette.studioPanel : RetroPalette.panelFill)
                                    : (chromeStyle == .studio ? RetroPalette.studioPanelMuted : RetroPalette.panelFillMuted),
                                accent: isSelected ? RetroPalette.chromeBlue : RetroPalette.chromeBlue.opacity(0.42)
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
                        Text("New")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                }
                .buttonStyle(RetroActionButtonStyle(tone: .secondary))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .retroPanel(fill: chromeStyle == .studio ? RetroPalette.studioPanelMuted : RetroPalette.railFill, accent: RetroPalette.chromeBlue)
    }
}
