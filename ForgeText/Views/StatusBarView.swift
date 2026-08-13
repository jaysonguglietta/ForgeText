import SwiftUI

struct StatusBarView: View {
    @Environment(\.retroChromeStyle) private var chromeStyle
    @ObservedObject var appState: AppState
    let document: EditorDocument
    let metrics: EditorMetrics
    let settings: AppSettings
    let insights: DocumentWorkbenchInsights
    let pluginStatusItems: [PluginStatusItem]

    var body: some View {
        HStack(spacing: 10) {
            if chromeStyle != .studio {
                Text("STATUS")
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .tracking(0.9)
                    .foregroundStyle(RetroPalette.mutedInk)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    statusPill("\(metrics.isApproximate ? "~" : "")Ln \(metrics.cursorLine), Col \(metrics.cursorColumn)", tone: .accent)
                    statusPill(document.language.displayName, tone: .accent)

                    if metrics.selectionLength > 0 {
                        statusPill("Sel \(metrics.selectionLength)")
                    }

                    if document.isReadOnly {
                        statusPill("Read Only", tone: .warning)
                    }

                    if document.isPartialPreview {
                        statusPill("Preview", tone: .warning)
                    }

                    if document.followModeEnabled {
                        statusPill("Follow", tone: .success)
                    }

                    if document.isLargeFileMode || appState.effectivePerformanceMode == .performance {
                        statusPill("Performance", tone: .warning)
                    }
                }
            }
            Spacer(minLength: 0)

            if let statusSummary = document.statusSummary {
                Text(statusSummary)
                    .foregroundStyle(RetroPalette.link)
                    .lineLimit(1)
                    .font(.system(size: 11, weight: .medium))
            }

            HStack(spacing: 6) {
                Menu {
                    Text("\(metrics.lineCount) lines, \(metrics.wordCount) words, \(metrics.characterCount) characters")
                    Text("\(document.encoding.displayName) • \(document.lineEnding.label) • \(settings.wrapLines ? "Wrap on" : "Wrap off")")
                    if let fileSize = document.fileSize {
                        Text(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                    }
                    if let csvInsight = insights.csv {
                        Text("CSV: \(csvInsight.rowCount) rows, \(csvInsight.columnCount) columns")
                    }
                    if let jsonInsight = insights.json {
                        Text("JSON: \(jsonInsight.topLevelType.displayName), \(jsonInsight.nodeCount) nodes")
                    }
                    if let logInsight = insights.log {
                        Text("Logs: \(logInsight.entryCount) entries, \(logInsight.warningCount) warnings, \(logInsight.errorCount) errors")
                    }
                    if let httpInsight = insights.http {
                        Text("HTTP: \(httpInsight.requestCount) requests")
                    }
                    if !pluginStatusItems.isEmpty {
                        Divider()
                        ForEach(pluginStatusItems) { item in
                            Text(item.text)
                        }
                    }
                } label: {
                    statusPill("Details")
                }
                .menuStyle(.borderlessButton)

                Button {
                    appState.showWorkspacePlatformPanel()
                } label: {
                    statusPill(appState.workspaceTrustMode == .trusted ? "Trusted" : "Restricted Folder", tone: appState.workspaceTrustMode == .trusted ? .success : .warning)
                }
                .buttonStyle(.plain)
                .help("Open Workspace Center")

                if appState.managedPolicyState.isManaged {
                    statusPill("Managed", tone: .accent)
                }

                Button {
                    appState.toggleBottomPanel()
                } label: {
                    statusPill(appState.isBottomPanelVisible ? appState.activeBottomPanel.title : "Panel", tone: .accent)
                }
                .buttonStyle(.plain)

                Button {
                    appState.showEngineeringWorkbench()
                } label: {
                    statusPill("Workbench", tone: .accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .retroPanel(
            fill: chromeStyle == .studio ? RetroPalette.studioPanelMuted : RetroPalette.railFill,
            accent: RetroPalette.chromeBlue
        )
    }

    private func statusPill(_ text: String, tone: PluginStatusTone = .neutral) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold, design: chromeStyle == .studio ? .default : .monospaced))
            .foregroundStyle(RetroPalette.ink)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .retroInsetPanel(fill: RetroPalette.fieldFill, accent: accent(for: tone))
    }

    private func accent(for tone: PluginStatusTone) -> Color {
        switch tone {
        case .neutral:
            return RetroPalette.chromeTeal
        case .accent:
            return RetroPalette.chromeBlue
        case .success:
            return RetroPalette.success
        case .warning:
            return RetroPalette.warning
        case .danger:
            return RetroPalette.danger
        }
    }
}
