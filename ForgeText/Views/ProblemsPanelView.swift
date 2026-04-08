import SwiftUI

struct ProblemsPanelView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(spacing: 0) {
                HStack {
                    Label("Problems", systemImage: "exclamationmark.bubble")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)

                    Spacer(minLength: 0)

                    Text(appState.problemsPanelState.sourceDescription)
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroPalette.link)

                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .primary))
                }
                .padding(16)
                .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)

                RetroRule()

                ScrollView {
                    VStack(spacing: 10) {
                        if appState.problemsPanelState.records.isEmpty {
                            Text("No matched problems are currently available.")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(RetroPalette.link)
                                .padding(.top, 24)
                        } else {
                            ForEach(appState.problemsPanelState.records) { record in
                                Button {
                                    appState.openProblem(record)
                                } label: {
                                    HStack(alignment: .top, spacing: 10) {
                                        Image(systemName: record.severity.symbolName)
                                            .foregroundStyle(accent(for: record.severity))
                                            .frame(width: 18)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(record.message)
                                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                                .foregroundStyle(RetroPalette.ink)
                                                .frame(maxWidth: .infinity, alignment: .leading)

                                            if let filePath = record.filePath {
                                                Text(locationText(filePath: filePath, line: record.lineNumber, column: record.columnNumber))
                                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                                    .foregroundStyle(RetroPalette.link)
                                            }

                                            if let detail = record.detail {
                                                Text(detail)
                                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                                    .foregroundStyle(RetroPalette.visited)
                                            }
                                        }
                                    }
                                    .padding(10)
                                    .retroPanel(fill: RetroPalette.panelFill, accent: accent(for: record.severity))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .padding(14)
        }
        .frame(minWidth: 880, minHeight: 560)
    }

    private func accent(for severity: PluginDiagnosticSeverity) -> Color {
        switch severity {
        case .info:
            return RetroPalette.chromeBlue
        case .warning:
            return RetroPalette.warning
        case .error:
            return RetroPalette.danger
        }
    }

    private func locationText(filePath: String, line: Int?, column: Int?) -> String {
        let location = [line.map(String.init), column.map(String.init)]
            .compactMap { $0 }
            .joined(separator: ":")
        return location.isEmpty ? filePath : "\(filePath):\(location)"
    }
}
