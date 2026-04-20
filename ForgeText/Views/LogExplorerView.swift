import SwiftUI

struct LogExplorerView: View {
    let document: EditorDocument
    let theme: EditorTheme
    let savedFilters: [SavedLogFilter]
    let onShowRawText: () -> Void
    let onToggleFollowMode: () -> Void
    let onSaveFilter: (String?, String, LogSeverityFilterMode, String, String, LogGroupingMode) -> Void
    let onDeleteSavedFilter: (SavedLogFilter) -> Void

    @State private var query = ""
    @State private var severityFilter: LogSeverityFilterMode = .all
    @State private var grouping: LogGroupingMode = .none
    @State private var startTimestamp = ""
    @State private var endTimestamp = ""
    @State private var filterName = ""

    private let logDocument: LogDocument?

    init(
        document: EditorDocument,
        theme: EditorTheme,
        savedFilters: [SavedLogFilter],
        onShowRawText: @escaping () -> Void,
        onToggleFollowMode: @escaping () -> Void,
        onSaveFilter: @escaping (String?, String, LogSeverityFilterMode, String, String, LogGroupingMode) -> Void,
        onDeleteSavedFilter: @escaping (SavedLogFilter) -> Void
    ) {
        self.document = document
        self.theme = theme
        self.savedFilters = savedFilters
        self.onShowRawText = onShowRawText
        self.onToggleFollowMode = onToggleFollowMode
        self.onSaveFilter = onSaveFilter
        self.onDeleteSavedFilter = onDeleteSavedFilter
        logDocument = LogExplorerService.parse(document.text)
    }

    private var filteredEntries: [LogEntry] {
        guard let logDocument else {
            return []
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let startDate = Self.parseFilterDate(startTimestamp)
        let endDate = Self.parseFilterDate(endTimestamp)

        return logDocument.entries.filter { entry in
            guard severityFilter.includes(entry.severity) else {
                return false
            }

            if let startDate, let entryDate = entry.timestampDate, entryDate < startDate {
                return false
            }

            if let endDate, let entryDate = entry.timestampDate, entryDate > endDate {
                return false
            }

            guard !trimmedQuery.isEmpty else {
                return true
            }

            let searchableFragments: [String?] = [
                entry.timestamp,
                entry.source,
                entry.message,
                entry.rawText,
                entry.details.joined(separator: "\n"),
            ]

            let haystack = searchableFragments
                .compactMap { $0?.lowercased() }
                .joined(separator: "\n")

            if haystack.contains(trimmedQuery) {
                return true
            }

            return entry.metadata.contains {
                $0.key.lowercased().contains(trimmedQuery) || $0.value.lowercased().contains(trimmedQuery)
            }
        }
    }

    private var groupedEntries: [(String, [LogEntry])] {
        switch grouping {
        case .none:
            return [("Entries", filteredEntries)]
        case .severity:
            let grouped = Dictionary(grouping: filteredEntries, by: { $0.severity.displayName })
            return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
        case .source:
            let grouped = Dictionary(grouping: filteredEntries, by: { $0.source ?? "Unknown Source" })
            return grouped.keys.sorted().map { ($0, grouped[$0] ?? []) }
        }
    }

    var body: some View {
        Group {
            if let logDocument {
                VStack(spacing: 0) {
                    summaryBar(logDocument)
                    Divider()
                    filterBar

                    if !savedFilters.isEmpty {
                        Divider()
                        savedFiltersBar
                    }

                    Divider()

                    if filteredEntries.isEmpty {
                        ContentUnavailableView(
                            "No Matching Log Entries",
                            systemImage: "line.3.horizontal.decrease.circle",
                            description: Text("Adjust the severity, time range, or search text to widen the results.")
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(nsColor: theme.backgroundColor))
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 16) {
                                    ForEach(groupedEntries, id: \.0) { group in
                                        if grouping != .none {
                                            Text(group.0)
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundStyle(Color(nsColor: theme.secondaryTextColor))
                                                .padding(.horizontal, 18)
                                                .padding(.top, 6)
                                        }

                                        ForEach(group.1) { entry in
                                            entryCard(entry)
                                                .id(entry.id)
                                                .padding(.horizontal, 18)
                                        }
                                    }
                                }
                                .padding(.vertical, 18)
                            }
                            .background(
                                StructuredScrollViewConfigurator(
                                    theme: theme,
                                    showsHorizontal: false,
                                    showsVertical: true
                                )
                            )
                            .background(Color(nsColor: theme.backgroundColor))
                            .onChange(of: filteredEntries.last?.id) { _, latestID in
                                guard document.followModeEnabled, let latestID else {
                                    return
                                }

                                withAnimation(.easeInOut(duration: 0.18)) {
                                    proxy.scrollTo(latestID, anchor: .bottom)
                                }
                            }
                            .overlay(alignment: .bottomTrailing) {
                                Button {
                                    if let latestID = filteredEntries.last?.id {
                                        withAnimation(.easeInOut(duration: 0.18)) {
                                            proxy.scrollTo(latestID, anchor: .bottom)
                                        }
                                    }
                                } label: {
                                    Label("Latest", systemImage: "arrow.down.to.line")
                                }
                                .buttonStyle(.borderedProminent)
                                .padding(18)
                                .accessibilityLabel("Jump to latest log entry")
                            }
                        }
                    }
                }
            } else {
                ContentUnavailableView(
                    "Couldn’t Structure This Log",
                    systemImage: "list.bullet.rectangle.portrait",
                    description: Text("ForgeText couldn’t confidently parse this file into log events. The raw text view is still available.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: theme.backgroundColor))
                .overlay(alignment: .bottom) {
                    Button("Open Raw Text") {
                        onShowRawText()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.bottom, 28)
                    .accessibilityLabel("Open raw log text")
                }
            }
        }
    }

    private func summaryBar(_ logDocument: LogDocument) -> some View {
        HStack(spacing: 12) {
            Label("Log Explorer", systemImage: "list.bullet.rectangle.portrait")
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color(nsColor: theme.textColor))

            summaryPill("\(logDocument.entryCount) entries")
            summaryPill("\(logDocument.timestampedEntryCount) timestamped")

            if logDocument.warningCount > 0 {
                summaryPill("\(logDocument.warningCount) warnings")
            }

            if logDocument.errorCount > 0 {
                summaryPill("\(logDocument.errorCount) errors")
            }

            Spacer(minLength: 0)

            Button(document.followModeEnabled ? "Pause Tail" : "Follow Tail") {
                onToggleFollowMode()
            }
            .buttonStyle(.bordered)
            .accessibilityLabel(document.followModeEnabled ? "Pause log follow mode" : "Enable log follow mode")

            Button("Save Filter") {
                onSaveFilter(filterName.isEmpty ? nil : filterName, query, severityFilter, startTimestamp, endTimestamp, grouping)
                filterName = ""
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Save current log filter")

            Button("Raw Text") {
                onShowRawText()
            }
            .buttonStyle(.bordered)
            .accessibilityLabel("Switch to raw log text")
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(nsColor: theme.gutterBackgroundColor))
    }

    private var filterBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color(nsColor: theme.secondaryTextColor))

                TextField("Filter messages, sources, and metadata", text: $query)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Filter log entries")

                TextField("Filter name", text: $filterName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 170)
                    .accessibilityLabel("Saved log filter name")
            }

            HStack(spacing: 10) {
                TextField("From time", text: $startTimestamp)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Log start time filter")

                TextField("To time", text: $endTimestamp)
                    .textFieldStyle(.roundedBorder)
                    .accessibilityLabel("Log end time filter")

                Picker("Severity", selection: $severityFilter) {
                    ForEach(LogSeverityFilterMode.allCases) { filter in
                        Text(filter.displayName).tag(filter)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 170)
                .accessibilityLabel("Log severity filter")

                Picker("Group", selection: $grouping) {
                    ForEach(LogGroupingMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .frame(maxWidth: 170)
                .accessibilityLabel("Log grouping mode")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color(nsColor: theme.backgroundColor))
    }

    private var savedFiltersBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(savedFilters) { filter in
                    HStack(spacing: 6) {
                        Button {
                            apply(filter)
                        } label: {
                            Text(filter.name)
                                .font(.system(size: 11, weight: .semibold))
                        }
                        .buttonStyle(.plain)

                        Button {
                            onDeleteSavedFilter(filter)
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .buttonStyle(.plain)
                    }
                    .foregroundStyle(Color(nsColor: theme.secondaryTextColor))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 6)
                    .background(
                        Capsule()
                            .fill(Color(nsColor: theme.gutterBackgroundColor))
                    )
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Saved log filter \(filter.name)")
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .background(Color(nsColor: theme.backgroundColor))
    }

    private func apply(_ filter: SavedLogFilter) {
        filterName = filter.name
        query = filter.query
        severityFilter = filter.severity
        startTimestamp = filter.startTimestamp
        endTimestamp = filter.endTimestamp
        grouping = filter.grouping
    }

    private func entryCard(_ entry: LogEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                severityBadge(entry.severity)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        if let timestamp = entry.timestamp {
                            Text(timestamp)
                                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                                .foregroundStyle(Color(nsColor: theme.textColor))
                        }

                        if let source = entry.source {
                            metadataPill(source, color: Color(nsColor: theme.gutterBackgroundColor))
                        }

                        metadataPill("Line \(entry.lineNumber)", color: Color(nsColor: theme.gutterBackgroundColor).opacity(0.75))

                        Spacer(minLength: 0)
                    }

                    Text(entry.message)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(nsColor: theme.textColor))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            if !entry.metadata.isEmpty {
                FlowingMetadataRow(fields: Array(entry.metadata.prefix(8)), theme: theme)
            }

            if !entry.details.isEmpty {
                DisclosureGroup("Details (\(entry.details.count) lines)") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Array(entry.details.enumerated()), id: \.offset) { _, detailLine in
                            Text(detailLine)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundStyle(Color(nsColor: theme.secondaryTextColor))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.top, 6)
                }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color(nsColor: theme.secondaryTextColor))
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(nsColor: theme.gutterBackgroundColor).opacity(0.48))
        )
    }

    private func summaryPill(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color(nsColor: theme.secondaryTextColor))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(Color(nsColor: theme.backgroundColor).opacity(0.55))
            )
    }

    private func severityBadge(_ severity: LogSeverity) -> some View {
        Text(severity.displayName.uppercased())
            .font(.system(size: 10, weight: .bold))
            .foregroundStyle(severityTextColor(for: severity))
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(severityColor(for: severity).opacity(0.18))
            )
    }

    private func metadataPill(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(Color(nsColor: theme.secondaryTextColor))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(color)
            )
    }

    private func severityColor(for severity: LogSeverity) -> Color {
        switch severity {
        case .trace, .debug:
            return .gray
        case .info, .notice:
            return .blue
        case .warning:
            return .orange
        case .error, .critical:
            return .red
        case .unknown:
            return Color(nsColor: theme.secondaryTextColor)
        }
    }

    private func severityTextColor(for severity: LogSeverity) -> Color {
        switch severity {
        case .trace, .debug:
            return .gray
        case .info, .notice:
            return .blue
        case .warning:
            return .orange
        case .error, .critical:
            return .red
        case .unknown:
            return Color(nsColor: theme.secondaryTextColor)
        }
    }

    private static func parseFilterDate(_ value: String) -> Date? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFormatter.date(from: trimmed) {
            return date
        }

        let fallbackISOFormatter = ISO8601DateFormatter()
        fallbackISOFormatter.formatOptions = [.withInternetDateTime]
        if let date = fallbackISOFormatter.date(from: trimmed) {
            return date
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d HH:mm:ss"
        return formatter.date(from: trimmed)
    }
}

private struct FlowingMetadataRow: View {
    let fields: [LogMetadataField]
    let theme: EditorTheme

    var body: some View {
        HStack(spacing: 8) {
            ForEach(fields) { field in
                Text("\(field.key)=\(field.value)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(nsColor: theme.secondaryTextColor))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(Color(nsColor: theme.backgroundColor).opacity(0.7))
                    )
            }

            Spacer(minLength: 0)
        }
    }
}
