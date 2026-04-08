import SwiftUI

struct PluginDiagnosticsView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            RetroBackdropView()

            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Label("Diagnostics", systemImage: "stethoscope")
                        .font(.system(size: 22, weight: .black, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)

                    Spacer(minLength: 0)

                    Button("Re-Run") {
                        appState.runPluginDiagnostics()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .secondary))

                    Button("Close") {
                        dismiss()
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .primary))
                }
                .padding(16)
                .retroPanel(fill: RetroPalette.panelFill, accent: RetroPalette.chromePink)

                RetroRule()

                VStack(alignment: .leading, spacing: 8) {
                    Text(appState.pluginDiagnosticsState.statusMessage ?? "Run diagnostics on the active document.")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(RetroPalette.link)

                    if let lastRunAt = appState.pluginDiagnosticsState.lastRunAt {
                        Text("Last run: \(lastRunAt.formatted(date: .numeric, time: .standard))")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(RetroPalette.visited)
                    }
                }
                .padding(16)
                .retroPanel(fill: RetroPalette.panelFillMuted, accent: RetroPalette.chromeBlue)

                RetroRule()

                ScrollView {
                    VStack(spacing: 12) {
                        if appState.pluginDiagnosticsState.diagnostics.isEmpty {
                            Text("No diagnostics were reported for the current document.")
                                .font(.system(size: 12, weight: .medium, design: .monospaced))
                                .foregroundStyle(RetroPalette.link)
                                .padding(.top, 32)
                        } else {
                            ForEach(appState.pluginDiagnosticsState.diagnostics) { diagnostic in
                                diagnosticCard(diagnostic)
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .padding(14)
        }
        .frame(minWidth: 820, minHeight: 560)
    }

    private func diagnosticCard(_ diagnostic: PluginDiagnostic) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Label(diagnostic.severity.displayName, systemImage: diagnostic.severity.symbolName)
                            .font(.system(size: 12, weight: .bold, design: .monospaced))
                            .foregroundStyle(RetroPalette.ink)

                        RetroCapsuleLabel(text: diagnostic.source, accent: accent(for: diagnostic.severity))
                    }

                    Text(diagnostic.message)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(RetroPalette.ink)

                    if let detail = diagnostic.detail {
                        Text(detail)
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(RetroPalette.link)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                if let lineNumber = diagnostic.lineNumber {
                    Button("Line \(lineNumber)") {
                        appState.jumpToDiagnostic(diagnostic)
                    }
                    .buttonStyle(RetroActionButtonStyle(tone: .primary))
                }
            }
        }
        .padding(14)
        .retroPanel(fill: RetroPalette.panelFill, accent: accent(for: diagnostic.severity))
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
}
