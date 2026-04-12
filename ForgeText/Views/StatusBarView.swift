import SwiftUI

struct StatusBarView: View {
    let document: EditorDocument
    let metrics: EditorMetrics
    let settings: AppSettings
    let pluginStatusItems: [PluginStatusItem]

    private var csvTable: DelimitedTableDocument? {
        guard document.language == .csv else {
            return nil
        }

        let preferredDelimiter: Character?
        switch document.fileURL?.pathExtension.lowercased() {
        case "tsv", "tab":
            preferredDelimiter = "\t"
        case "csv":
            preferredDelimiter = ","
        default:
            preferredDelimiter = nil
        }

        return DelimitedTextTableService.parse(document.text, preferredDelimiter: preferredDelimiter)
    }

    private var jsonTree: JSONTreeDocument? {
        guard document.language == .json else {
            return nil
        }

        return JSONTreeService.parse(document.text)
    }

    private var logDocument: LogDocument? {
        guard document.language == .log else {
            return nil
        }

        return LogExplorerService.parse(document.text)
    }

    private var httpRequestDocument: HTTPRequestDocument? {
        guard document.language == .http else {
            return nil
        }

        return HTTPRequestService.parse(document.text)
    }

    var body: some View {
        HStack(spacing: 12) {
            RetroSectionHeader(title: "Status", accent: RetroPalette.chromeBlue)
                .frame(width: 116)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
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

                    if let csvTable {
                        statusPill("\(csvTable.rowCount) rows")
                        statusPill("\(csvTable.columnCount) cols")
                    }

                    if let jsonTree {
                        statusPill(jsonTree.topLevelType.displayName)
                        statusPill("\(jsonTree.nodeCount) nodes")
                    }

                    if let logDocument {
                        statusPill("\(logDocument.entryCount) entries")

                        if logDocument.warningCount > 0 {
                            statusPill("\(logDocument.warningCount) warnings", tone: .warning)
                        }

                        if logDocument.errorCount > 0 {
                            statusPill("\(logDocument.errorCount) errors", tone: .danger)
                        }
                    }

                    if let httpRequestDocument {
                        statusPill("\(httpRequestDocument.requests.count) requests")
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
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .retroPanel(fill: RetroPalette.railFill, accent: RetroPalette.chromeBlue)
    }

    private func statusPill(_ text: String, tone: PluginStatusTone = .neutral) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .monospaced))
            .foregroundStyle(RetroPalette.ink)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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
