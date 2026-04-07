import SwiftUI

struct CompareView: View {
    let state: DocumentComparisonState

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(state.title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))

                HStack(spacing: 12) {
                    comparisonBadge(state.leftTitle, systemImage: "square.split.2x1")
                    comparisonBadge(state.rightTitle, systemImage: "square.split.2x1.fill")
                    comparisonBadge("\(state.changedLineCount) changed", systemImage: "arrow.left.arrow.right")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)

            Divider()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(state.lines) { line in
                        HStack(spacing: 0) {
                            diffCell(number: line.leftLineNumber, text: line.leftText, alignment: .leading)
                            diffCell(number: line.rightLineNumber, text: line.rightText, alignment: .leading)
                        }
                        .background(backgroundColor(for: line.kind))
                    }
                }
            }
        }
        .frame(minWidth: 960, minHeight: 620)
    }

    private func comparisonBadge(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
    }

    private func diffCell(number: Int?, text: String?, alignment: Alignment) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number.map(String.init) ?? "")
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .trailing)
                .accessibilityHidden(true)

            Text(text ?? "")
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: alignment)
                .textSelection(.enabled)
        }
        .font(.system(size: 12, design: .monospaced))
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: alignment)
    }

    private func backgroundColor(for kind: DiffLineKind) -> Color {
        switch kind {
        case .unchanged:
            return Color.clear
        case .inserted:
            return Color.green.opacity(0.12)
        case .deleted:
            return Color.orange.opacity(0.12)
        }
    }
}
