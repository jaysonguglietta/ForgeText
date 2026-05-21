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
                    statusPill("Ln \(metrics.cursorLine), Col \(metrics.cursorColumn)", tone: .accent)
                    statusPill("\(metrics.lineCount) lines")
                    statusPill("\(metrics.wordCount) words")
                    statusPill("\(metrics.characterCount) chars")
                    statusPill(document.language.displayName, tone: .accent)
                    statusPill(document.encoding.displayName + (document.includesByteOrderMark ? " BOM" : ""))
                    statusPill(document.lineEnding.label)
                    statusPill(settings.wrapLines ? "Wrap On" : "Wrap Off")
                    statusPill(settings.theme.displayName)

                    if document.isLargeFileMode {
                        statusPill("Large File", tone: .warning)
                    }

                    if appState.effectivePerformanceMode == .performance {
                        statusPill("Performance Mode", tone: .warning)
                    }

                    if appState.isSafeModeActive {
                        statusPill("Safe Mode", tone: .warning)
                    }

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

                    if let fileSize = document.fileSize {
                        statusPill(ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file))
                    }

                    if let csvInsight = insights.csv {
                        statusPill("\(csvInsight.rowCount) rows")
                        statusPill("\(csvInsight.columnCount) cols")
                    }

                    if let jsonInsight = insights.json {
                        statusPill(jsonInsight.topLevelType.displayName)
                        statusPill("\(jsonInsight.nodeCount) nodes")
                    }

                    if let logInsight = insights.log {
                        statusPill("\(logInsight.entryCount) entries")

                        if logInsight.warningCount > 0 {
                            statusPill("\(logInsight.warningCount) warnings", tone: .warning)
                        }

                        if logInsight.errorCount > 0 {
                            statusPill("\(logInsight.errorCount) errors", tone: .danger)
                        }
                    }

                    if let httpInsight = insights.http {
                        statusPill("\(httpInsight.requestCount) requests")
                    }

                    ForEach(pluginStatusItems) { item in
                        statusPill(item.text, tone: item.tone)
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
                    appState.toggleSidebar()
                } label: {
                    statusPill(appState.isSidebarVisible ? "Sidebar On" : "Sidebar Off")
                }
                .buttonStyle(.plain)

                Button {
                    appState.toggleBottomPanel()
                } label: {
                    statusPill(appState.isBottomPanelVisible ? "Panel \(appState.activeBottomPanel.title)" : "Panel Off", tone: .accent)
                }
                .buttonStyle(.plain)

                statusPill(appState.activeWorkbenchPresetLabel, tone: .neutral)
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
