import SwiftUI

struct ContentView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        NavigationSplitView {
            DocumentSidebarView(appState: appState)
        } detail: {
            if let document = appState.selectedDocument, let metrics = appState.selectedMetrics {
                DocumentWorkspaceView(appState: appState, document: document, metrics: metrics)
            } else {
                EmptyWorkspaceView(appState: appState)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $appState.showingCommandPalette) {
            CommandPaletteView(appState: appState)
        }
        .sheet(isPresented: $appState.showingGoToLine) {
            GoToLineView(appState: appState)
        }
        .sheet(isPresented: $appState.projectSearchState.isPresented) {
            ProjectSearchView(appState: appState)
        }
        .sheet(isPresented: $appState.showingRemoteOpen) {
            RemoteOpenView(appState: appState)
        }
        .sheet(isPresented: $appState.showingWorkspaceSessions) {
            WorkspaceSessionsView(appState: appState)
        }
        .sheet(isPresented: $appState.showingKeyboardShortcuts) {
            KeyboardShortcutsView()
        }
        .sheet(item: $appState.comparisonState) { comparisonState in
            CompareView(state: comparisonState)
        }
        .confirmationDialog(
            "Discard unsaved changes?",
            isPresented: $appState.showingDiscardChanges,
            titleVisibility: .visible
        ) {
            Button("Discard Changes", role: .destructive) {
                appState.resolveDiscardChanges()
            }

            Button("Cancel", role: .cancel) {
                appState.cancelDiscardChanges()
            }
        } message: {
            Text("Any unsaved edits in the current document will be lost.")
        }
        .alert(item: $appState.alertContext) { context in
            Alert(
                title: Text(context.title),
                message: Text(context.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }
}

private struct DocumentSidebarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 12) {
                    BrandMarkView(size: 38)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("ForgeText")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                        Text("Robust text editing for macOS")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                LazyVGrid(
                    columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                    spacing: 10
                ) {
                    sidebarAction(
                        "New",
                        systemImage: "plus.square",
                        subtitle: "Document",
                        action: appState.newDocument
                    )
                    sidebarAction(
                        "Open",
                        systemImage: "folder",
                        subtitle: "Files",
                        action: appState.openDocument
                    )
                    sidebarAction(
                        "Command",
                        systemImage: "command",
                        subtitle: "Palette",
                        action: { appState.showingCommandPalette = true }
                    )
                }

                sidebarSection("Open Documents") {
                    ForEach(appState.documents) { document in
                        DocumentSidebarRow(
                            document: document,
                            isSelected: appState.selectedDocumentID == document.id,
                            onSelect: { appState.selectDocument(document.id) },
                            onClose: { appState.closeDocument(id: document.id) }
                        )
                    }
                }

                sidebarSection("Recent Files") {
                    if appState.recentFiles.isEmpty {
                        Text("Recent files will appear here after you open or save documents.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        ForEach(appState.recentFiles, id: \.path) { url in
                            Button {
                                appState.openDocuments(at: [url])
                            } label: {
                                fileCard(
                                    title: url.lastPathComponent,
                                    subtitle: url.path(percentEncoded: false),
                                    symbolName: "clock.arrow.circlepath"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if !appState.recentRemoteLocations.isEmpty {
                    sidebarSection("Recent Remote") {
                        ForEach(appState.recentRemoteLocations, id: \.spec) { reference in
                            Button {
                                appState.remoteLocationDraft = reference.spec
                                appState.openRemoteDocument()
                            } label: {
                                fileCard(
                                    title: reference.displayName,
                                    subtitle: reference.pathDescription,
                                    symbolName: "network"
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                sidebarSection("Workspace") {
                    Button {
                        appState.chooseWorkspaceRoot()
                    } label: {
                        fileCard(
                            title: appState.projectSearchState.rootURL?.lastPathComponent ?? "Choose Folder",
                            subtitle: appState.projectSearchState.rootURL?.path(percentEncoded: false) ?? "Set a project root for folder search and terminal tools.",
                            symbolName: "folder.badge.gearshape"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Choose workspace root folder")

                    Button {
                        appState.openRemotePanel()
                    } label: {
                        fileCard(
                            title: "Open Remote File",
                            subtitle: "Use SSH-style locations like user@host:/path/to/file",
                            symbolName: "network"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open a remote file")

                    Button {
                        appState.showWorkspaceSessionsPanel()
                    } label: {
                        fileCard(
                            title: "Workspace Sessions",
                            subtitle: "Save and reopen grouped files, remotes, and workspace settings",
                            symbolName: "square.stack.3d.up"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Open workspace sessions")

                    Button {
                        appState.showingKeyboardShortcuts = true
                    } label: {
                        fileCard(
                            title: "Keyboard Shortcuts",
                            subtitle: "Quick reference for editor navigation and text commands",
                            symbolName: "keyboard"
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Show keyboard shortcuts")
                }
            }
            .padding(18)
        }
        .frame(minWidth: 280)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private func sidebarAction(
        _ title: String,
        systemImage: String,
        subtitle: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: 34, height: 34)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.accentColor.opacity(0.12))
                    )

                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.primary)

                    Text(subtitle)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                .multilineTextAlignment(.center)
                .lineLimit(1)
            }
            .frame(maxWidth: .infinity, minHeight: 92)
            .padding(.horizontal, 8)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
        }
        .buttonStyle(.plain)
    }

    private func fileCard(title: String, subtitle: String, symbolName: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            Spacer(minLength: 0)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.45))
        )
    }

    private func sidebarSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
            content()
        }
    }
}

private struct DocumentSidebarRow: View {
    let document: EditorDocument
    let isSelected: Bool
    let onSelect: () -> Void
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: documentIconName)
                .foregroundStyle(isSelected ? .primary : .secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(document.displayName)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if document.isDirty {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 7, height: 7)
                    }
                }

                Text(document.pathDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(Circle().fill(Color.primary.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color(nsColor: .controlBackgroundColor).opacity(0.45))
        )
        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onTapGesture(perform: onSelect)
    }

    private var documentIconName: String {
        if document.isRemote {
            return "network"
        }

        if document.availableStructuredPresentationMode == .archiveBrowser {
            return "archivebox"
        }

        return document.language.symbolName
    }
}

private struct DocumentWorkspaceView: View {
    @ObservedObject var appState: AppState
    let document: EditorDocument
    let metrics: EditorMetrics

    private var backgroundColor: Color {
        Color(nsColor: appState.settings.theme.backgroundColor)
    }

    private var currentLine: Int {
        metrics.cursorLine
    }

    private var breadcrumbTrail: [String] {
        DocumentOutlineService.breadcrumbTrail(for: document, cursorLine: currentLine)
    }

    private var alternatePresentationMode: DocumentPresentationMode? {
        if document.presentationMode == .binaryHex {
            return nil
        }

        if document.presentationMode == .archiveBrowser {
            return .editor
        }

        guard let structuredMode = document.availableStructuredPresentationMode else {
            return nil
        }

        return document.presentationMode == structuredMode ? .editor : structuredMode
    }

    private var secondaryDocumentCandidates: [EditorDocument] {
        appState.documents.filter { $0.id != document.id }
    }

    var body: some View {
        VStack(spacing: 0) {
            DocumentTabStripView(appState: appState)
            Divider()
            header

            if appState.settings.showsBreadcrumbs, !breadcrumbTrail.isEmpty {
                Divider()
                breadcrumbBar
            }

            if document.hasExternalChanges || document.fileMissingOnDisk {
                statusBanner(
                    title: document.fileMissingOnDisk ? "File Missing on Disk" : "External Changes Detected",
                    message: document.fileMissingOnDisk
                        ? "The file is no longer available at its saved path. You can keep editing and save elsewhere."
                        : "This document changed outside ForgeText. Reload it or keep your current version.",
                    accent: document.fileMissingOnDisk ? .red : .orange
                ) {
                    Button("Compare") {
                        appState.showCompareAgainstSaved()
                    }

                    if !document.fileMissingOnDisk {
                        Button("Reload") {
                            appState.reloadFromExternalChange()
                        }
                    }

                    Button("Keep Mine") {
                        appState.keepCurrentVersionAfterExternalChange()
                    }
                }
            }

            if document.isPartialPreview || document.presentationMode == .binaryHex || document.followModeEnabled || document.presentationMode == .archiveBrowser {
                statusBanner(
                    title: bannerTitle,
                    message: bannerMessage,
                    accent: bannerAccent
                ) {
                    if document.fileURL != nil {
                        Button(document.followModeEnabled ? "Disable Follow" : "Enable Follow") {
                            appState.toggleFollowMode()
                        }
                    }

                    if document.fileURL != nil {
                        Button("Open in Terminal") {
                            appState.openSelectedDocumentInTerminal()
                        }
                    }
                }
            }

            if document.findState.isPresented, !document.presentationMode.isStructured {
                Divider()
                FindReplaceBar(appState: appState, document: document)
            }

            Divider()

            workspaceArea

            Divider()

            StatusBarView(document: document, metrics: metrics, settings: appState.settings)
        }
        .background(backgroundColor)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    appState.newDocument()
                } label: {
                    Label("New", systemImage: "plus.square")
                }

                Button {
                    appState.openDocument()
                } label: {
                    Label("Open", systemImage: "folder")
                }

                Button {
                    appState.openRemotePanel()
                } label: {
                    Label("Remote", systemImage: "network")
                }

                Button {
                    appState.saveDocument()
                } label: {
                    Label("Save", systemImage: "square.and.arrow.down")
                }

                Button {
                    appState.showFindReplace()
                } label: {
                    Label("Find", systemImage: "magnifyingglass")
                }

                Button {
                    appState.showProjectSearch()
                } label: {
                    Label("Search Files", systemImage: "magnifyingglass")
                }

                Button {
                    appState.showingCommandPalette = true
                } label: {
                    Label("Palette", systemImage: "command")
                }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 14) {
            BrandMarkView(size: 30)

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(document.displayName)
                        .font(.system(size: 21, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(nsColor: appState.settings.theme.textColor))

                    if document.isRemote {
                        headerBadge("Remote", color: .cyan)
                    }

                    if document.isDirty {
                        headerBadge("Edited", color: .orange)
                    }

                    if document.hasRecoveredDraft {
                        headerBadge("Recovered", color: .green)
                    }

                    if document.isLargeFileMode {
                        headerBadge("Large File", color: .yellow)
                    }

                    if let structuredBadge {
                        headerBadge(structuredBadge.text, color: structuredBadge.color)
                    }
                }

                Text(document.pathDescription)
                    .font(.caption)
                    .foregroundStyle(Color(nsColor: appState.settings.theme.secondaryTextColor))
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)

            if let structuredPresentationMode = document.availableStructuredPresentationMode {
                Button {
                    toggleStructuredPresentation(structuredPresentationMode)
                } label: {
                    headerControl(
                        document.presentationMode == structuredPresentationMode ? "Raw Text" : structuredPresentationMode.displayName,
                        systemImage: document.presentationMode == structuredPresentationMode ? "doc.text" : structuredPresentationMode.symbolName
                    )
                }
                .buttonStyle(.plain)
            }

            Menu {
                ForEach(DocumentLanguage.allCases) { language in
                    Button(language.displayName) {
                        appState.setLanguage(language)
                    }
                }
            } label: {
                headerControl(document.language.displayName, systemImage: document.language.symbolName)
            }
            .menuStyle(.borderlessButton)

            Menu {
                ForEach(EditorTheme.allCases) { theme in
                    Button(theme.displayName) {
                        appState.setTheme(theme)
                    }
                }
            } label: {
                headerControl(appState.settings.theme.displayName, systemImage: "paintpalette")
            }
            .menuStyle(.borderlessButton)

            Menu {
                ForEach(WorkspaceSecondaryPaneMode.allCases) { mode in
                    Button(mode.displayName) {
                        appState.setSecondaryPaneMode(mode)
                    }
                }

                if appState.secondaryPaneMode == .secondDocument, !secondaryDocumentCandidates.isEmpty {
                    Divider()

                    ForEach(secondaryDocumentCandidates) { candidate in
                        Button(candidate.displayName) {
                            appState.setSecondaryDocument(candidate.id)
                        }
                    }
                }
            } label: {
                headerControl(splitControlTitle, systemImage: "rectangle.split.2x1")
            }
            .menuStyle(.borderlessButton)

            Menu {
                Menu("Encoding") {
                    ForEach(String.Encoding.commonSaveEncodings, id: \.rawValue) { encoding in
                        Button(encoding.displayName) {
                            appState.setEncoding(encoding)
                        }
                    }
                }

                Menu("Line Endings") {
                    ForEach(LineEnding.allCases, id: \.rawValue) { lineEnding in
                        Button(lineEnding.label) {
                            appState.setLineEnding(lineEnding)
                        }
                    }
                }

                Button(document.includesByteOrderMark ? "Disable BOM" : "Enable BOM") {
                    appState.toggleByteOrderMark()
                }
                .disabled(!appState.canSave)

                Divider()

                Button(appState.settings.showsOutline ? "Hide Outline" : "Show Outline") {
                    appState.toggleOutlinePanel()
                }

                Button(appState.settings.showsBreadcrumbs ? "Hide Breadcrumbs" : "Show Breadcrumbs") {
                    appState.toggleBreadcrumbs()
                }

                Divider()

                Button("Compare with Saved") {
                    appState.showCompareAgainstSaved()
                }
                .disabled(!appState.canCompareSelectedDocument)

                Button("Workspace Sessions") {
                    appState.showWorkspaceSessionsPanel()
                }

                Button("Keyboard Shortcuts") {
                    appState.showingKeyboardShortcuts = true
                }

                Divider()

                if let structuredPresentationMode = document.availableStructuredPresentationMode {
                    Button(document.presentationMode == structuredPresentationMode ? "Show Raw Text" : "Show \(structuredPresentationMode.displayName)") {
                        toggleStructuredPresentation(structuredPresentationMode)
                    }
                }

                Button(document.followModeEnabled ? "Disable Follow Mode" : "Enable Follow Mode") {
                    appState.toggleFollowMode()
                }
                .disabled(!appState.canFollowSelectedDocument)

                Button("Open in Terminal") {
                    appState.openSelectedDocumentInTerminal()
                }
                .disabled(document.fileURL == nil && appState.projectSearchState.rootURL == nil)

                if appState.canPrivilegedSaveSelectedDocument {
                    Button("Privileged Save") {
                        appState.saveDocumentPrivileged()
                    }
                }
            } label: {
                headerControl("Document", systemImage: "slider.horizontal.3")
            }
            .menuStyle(.borderlessButton)

            Button {
                appState.showGoToLine()
            } label: {
                headerControl("Go to Line", systemImage: "text.line.first.and.arrowtriangle.forward")
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(backgroundColor)
    }

    private var breadcrumbBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(breadcrumbTrail.enumerated()), id: \.offset) { index, crumb in
                    if index > 0 {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(Color(nsColor: appState.settings.theme.secondaryTextColor))
                    }

                    Text(crumb)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Color(nsColor: appState.settings.theme.secondaryTextColor))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(
                            Capsule()
                                .fill(Color(nsColor: appState.settings.theme.gutterBackgroundColor))
                        )
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
        }
        .background(backgroundColor)
    }

    private var workspaceArea: some View {
        HSplitView {
            primaryWorkspaceArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if appState.settings.showsOutline {
                OutlinePanelView(
                    document: document,
                    currentLine: currentLine,
                    theme: appState.settings.theme,
                    onSelectLine: { lineNumber in
                        appState.goToLine(lineNumber, in: document.id)
                    }
                )
                .background(backgroundColor)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(backgroundColor)
    }

    @ViewBuilder
    private var primaryWorkspaceArea: some View {
        switch appState.secondaryPaneMode {
        case .off:
            documentPane(
                document: document,
                renderedMode: document.presentationMode,
                title: nil,
                isSelectedDocument: true
            )
        case .alternatePresentation:
            if let alternatePresentationMode {
                HSplitView {
                    documentPane(
                        document: document,
                        renderedMode: document.presentationMode,
                        title: paneTitle(for: document.presentationMode),
                        isSelectedDocument: true
                    )

                    documentPane(
                        document: document,
                        renderedMode: alternatePresentationMode,
                        title: paneTitle(for: alternatePresentationMode),
                        isSelectedDocument: true
                    )
                }
            } else {
                documentPane(
                    document: document,
                    renderedMode: document.presentationMode,
                    title: nil,
                    isSelectedDocument: true
                )
            }
        case .secondDocument:
            if let secondaryDocument = appState.selectedSecondaryDocument {
                HSplitView {
                    documentPane(
                        document: document,
                        renderedMode: document.presentationMode,
                        title: document.displayName,
                        isSelectedDocument: true
                    )

                    documentPane(
                        document: secondaryDocument,
                        renderedMode: secondaryDocument.presentationMode,
                        title: secondaryDocument.displayName,
                        isSelectedDocument: false
                    )
                }
            } else {
                documentPane(
                    document: document,
                    renderedMode: document.presentationMode,
                    title: nil,
                    isSelectedDocument: true
                )
            }
        }
    }

    private func paneTitle(for mode: DocumentPresentationMode) -> String {
        switch mode {
        case .editor, .readOnlyPreview:
            return "Raw Text"
        case .binaryHex:
            return "Hex Preview"
        case .structuredTable:
            return "Table View"
        case .structuredJSON:
            return "JSON Tree"
        case .logExplorer:
            return "Log Explorer"
        case .structuredConfig:
            return "Config Inspector"
        case .archiveBrowser:
            return "Archive Browser"
        }
    }

    private func documentPane(
        document: EditorDocument,
        renderedMode: DocumentPresentationMode,
        title: String?,
        isSelectedDocument: Bool
    ) -> some View {
        let renderedDocument = withPresentationMode(document, renderedMode)

        return VStack(spacing: 0) {
            if let title {
                HStack(spacing: 10) {
                    Label(title, systemImage: renderedMode.symbolName)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(nsColor: appState.settings.theme.secondaryTextColor))

                    Spacer(minLength: 0)

                    if !isSelectedDocument {
                        Text(renderedDocument.pathDescription)
                            .font(.system(size: 11))
                            .foregroundStyle(Color(nsColor: appState.settings.theme.secondaryTextColor))
                            .lineLimit(1)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(nsColor: appState.settings.theme.gutterBackgroundColor))

                Divider()
            }

            documentSurface(for: renderedDocument)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .id("\(renderedDocument.id.uuidString)-\(renderedMode.rawValue)")
        }
        .background(backgroundColor)
    }

    @ViewBuilder
    private func documentSurface(for document: EditorDocument) -> some View {
        switch document.presentationMode {
        case .structuredTable:
            CSVTableView(
                document: document,
                theme: appState.settings.theme,
                onShowRawText: appState.showRawTextView
            )
        case .structuredJSON:
            JSONTreeView(
                document: document,
                theme: appState.settings.theme,
                onShowRawText: appState.showRawTextView
            )
        case .logExplorer:
            LogExplorerView(
                document: document,
                theme: appState.settings.theme,
                savedFilters: appState.settings.savedLogFilters,
                onShowRawText: appState.showRawTextView,
                onToggleFollowMode: appState.toggleFollowMode,
                onSaveFilter: appState.saveCurrentLogFilter,
                onDeleteSavedFilter: appState.deleteSavedLogFilter
            )
        case .structuredConfig:
            ConfigInspectorView(
                document: document,
                theme: appState.settings.theme,
                onShowRawText: appState.showRawTextView,
                onSelectLine: { lineNumber in
                    appState.goToLine(lineNumber, in: document.id)
                }
            )
        case .archiveBrowser:
            ArchiveBrowserView(
                document: document,
                theme: appState.settings.theme
            )
        case .editor, .readOnlyPreview, .binaryHex:
            EditorContainerView(
                text: appState.textBinding(for: document.id),
                selectedRange: appState.selectionBinding(for: document.id),
                theme: appState.settings.theme,
                language: document.language,
                wrapLines: appState.settings.wrapLines,
                fontSize: CGFloat(appState.settings.fontSize),
                findState: document.findState,
                largeFileMode: document.isLargeFileMode,
                isEditable: !document.isReadOnly,
                focusRequestToken: appState.editorFocusToken
            )
        }
    }

    private func withPresentationMode(_ document: EditorDocument, _ mode: DocumentPresentationMode) -> EditorDocument {
        var updatedDocument = document
        updatedDocument.presentationMode = mode
        return updatedDocument
    }

    private var splitControlTitle: String {
        switch appState.secondaryPaneMode {
        case .off:
            return "Single Pane"
        case .alternatePresentation:
            return "Raw + Structured"
        case .secondDocument:
            return "Second Document"
        }
    }

    private var bannerTitle: String {
        if document.presentationMode == .archiveBrowser {
            return "Archive Browser"
        }

        if document.presentationMode == .binaryHex {
            return "Binary Hex Preview"
        }

        if document.isPartialPreview {
            return "Read-Only Preview"
        }

        return "Follow Mode"
    }

    private var bannerMessage: String {
        if document.presentationMode == .archiveBrowser {
            return "Archives open in a safe browser view so you can inspect contents without extracting them into the workspace."
        }

        if document.presentationMode == .binaryHex {
            return "ForgeText opened this file as a hex preview because it doesn’t decode cleanly as text."
        }

        if document.isPartialPreview {
            return "Large files are opened as read-only previews so the editor stays fast and safe."
        }

        return "This document automatically reloads when the file changes on disk."
    }

    private var bannerAccent: Color {
        if document.presentationMode == .archiveBrowser {
            return .indigo
        }

        return document.presentationMode == .binaryHex ? .purple : .blue
    }

    private func headerBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule()
                    .fill(color.opacity(0.14))
            )
    }

    private func headerControl(_ text: String, systemImage: String) -> some View {
        Label(text, systemImage: systemImage)
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(Color(nsColor: appState.settings.theme.textColor))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(nsColor: appState.settings.theme.gutterBackgroundColor))
            )
    }

    private var structuredBadge: (text: String, color: Color)? {
        switch document.presentationMode {
        case .structuredTable:
            return ("Table", .blue)
        case .structuredJSON:
            return ("JSON Tree", .teal)
        case .logExplorer:
            return ("Log Explorer", .mint)
        case .structuredConfig:
            return ("Config", .green)
        case .archiveBrowser:
            return ("Archive", .indigo)
        case .editor, .readOnlyPreview, .binaryHex:
            return nil
        }
    }

    private func toggleStructuredPresentation(_ mode: DocumentPresentationMode) {
        if document.presentationMode == mode {
            appState.showRawTextView()
        } else {
            appState.showStructuredView()
        }
    }

    private func statusBanner<Actions: View>(
        title: String,
        message: String,
        accent: Color,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(accent)
                .frame(width: 11, height: 11)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(Color(nsColor: appState.settings.theme.textColor))
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(Color(nsColor: appState.settings.theme.secondaryTextColor))
            }

            Spacer(minLength: 0)

            HStack(spacing: 8) {
                actions()
            }
            .buttonStyle(.borderless)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(accent.opacity(0.08))
    }
}

private struct EmptyWorkspaceView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(spacing: 20) {
            BrandMarkView(size: 84)

            VStack(spacing: 8) {
                Text("ForgeText")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                Text("A native editor for plain text, code, logs, configs, archives, and whatever else lands on your Mac.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 460)
            }

            HStack(spacing: 12) {
                Button("New Document") {
                    appState.newDocument()
                }
                .buttonStyle(.borderedProminent)

                Button("Open Files") {
                    appState.openDocument()
                }
                .buttonStyle(.bordered)

                Button("Open Remote") {
                    appState.openRemotePanel()
                }
                .buttonStyle(.bordered)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}
