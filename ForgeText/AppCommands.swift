import AppKit
import SwiftUI

struct FileEditorCommands: Commands {
    @ObservedObject var appState: AppState

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New") {
                appState.newDocument()
            }
            .keyboardShortcut("n")
        }

        CommandGroup(after: .newItem) {
            Button("Open...") {
                appState.openDocument()
            }
            .keyboardShortcut("o")

            Button("Open Workspace...") {
                appState.openWorkspaceFilePanel()
            }

            Button("Workspace Center...") {
                appState.showWorkspacePlatformPanel()
            }

            Button("Clone Repository...") {
                appState.showCloneRepositoryPanel()
            }

            Button("Open Remote...") {
                appState.openRemotePanel()
            }

            Button("Git Workbench...") {
                appState.showGitWorkbenchPanel()
            }

            Button("AI Workbench...") {
                appState.showAIWorkbenchPanel()
            }

            Button("Search in Folder...") {
                appState.showProjectSearch()
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])

            Button("Close") {
                appState.closeSelectedDocument()
            }
            .keyboardShortcut("w")
            .disabled(!appState.canCloseSelectedDocument)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") {
                appState.saveDocument()
            }
            .keyboardShortcut("s")
            .disabled(!appState.canSave)

            Button("Save As...") {
                appState.saveDocumentAs()
            }
            .keyboardShortcut("S", modifiers: [.command, .shift])
            .disabled(!appState.canSave)

            Divider()

            Button("Save Workspace...") {
                appState.saveWorkspaceFile()
            }
            .disabled(appState.workspaceRootURLs.isEmpty)

            Button("Privileged Save") {
                appState.saveDocumentPrivileged()
            }
            .disabled(!appState.canPrivilegedSaveSelectedDocument)

            Button("Revert to Saved") {
                appState.revertToSaved()
            }
            .disabled(appState.selectedDocument?.fileURL == nil)
        }

        CommandMenu("Navigate") {
            Button("Go to Line...") {
                appState.showGoToLine()
            }
            .keyboardShortcut("l")

            Divider()

            Button("Next Document") {
                appState.selectNextDocument()
            }
            .keyboardShortcut("]", modifiers: [.command, .shift])

            Button("Previous Document") {
                appState.selectPreviousDocument()
            }
            .keyboardShortcut("[", modifiers: [.command, .shift])
        }

        CommandMenu("Search") {
            Button("Find and Replace") {
                appState.showFindReplace()
            }
            .keyboardShortcut("f")

            Button("Find Next") {
                appState.findNextMatch()
            }
            .keyboardShortcut("g")

            Button("Find Previous") {
                appState.findPreviousMatch()
            }
            .keyboardShortcut("G", modifiers: [.command, .shift])

            Divider()

            Button("Search in Folder...") {
                appState.showProjectSearch()
            }
            .keyboardShortcut("F", modifiers: [.command, .shift])

            Divider()

            Button("Command Palette...") {
                appState.showingCommandPalette = true
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
        }

        CommandMenu("Code") {
            Button("Toggle Comment") {
                NSApp.sendAction(#selector(EditorTextView.toggleCommentSelection(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("/")

            Divider()

            Button("Pretty Print JSON") {
                appState.prettyPrintJSON()
            }
            .disabled(appState.selectedDocument?.language != .json || !appState.canSave)

            Button("Minify JSON") {
                appState.minifyJSON()
            }
            .disabled(appState.selectedDocument?.language != .json || !appState.canSave)

            Divider()

            Button("Compare with Saved") {
                appState.showCompareAgainstSaved()
            }
            .disabled(!appState.canCompareSelectedDocument)

            Button("Compare with File...") {
                appState.compareSelectedDocumentWithFile()
            }
            .disabled(appState.selectedDocument == nil)

            Divider()

            Button("Compare with Git HEAD") {
                appState.compareSelectedDocumentWithGitHead()
            }
            .disabled(appState.selectedDocument?.fileURL == nil)

            Button("Stage Current File") {
                appState.stageSelectedFileInGit()
            }
            .disabled(appState.selectedDocument?.fileURL == nil)
        }

        CommandMenu("Source Control") {
            Button("Git Workbench") {
                appState.showGitWorkbenchPanel()
            }

            Button("Refresh Git Status") {
                appState.refreshGitStatus()
            }

            Divider()

            Button("Fetch") {
                appState.fetchGitRepository()
            }

            Button("Pull") {
                appState.pullGitRepository()
            }

            Button("Push") {
                appState.pushGitRepository()
            }
        }

        CommandMenu("View") {
            Button(appState.settings.wrapLines ? "Disable Line Wrap" : "Enable Line Wrap") {
                appState.toggleWrapLines()
            }

            Divider()

            Button("Increase Font Size") {
                appState.increaseFontSize()
            }
            .keyboardShortcut("+")

            Button("Decrease Font Size") {
                appState.decreaseFontSize()
            }
            .keyboardShortcut("-")

            Divider()

            Menu("Theme") {
                ForEach(EditorTheme.allCases) { theme in
                    Button(theme.displayName) {
                        appState.setTheme(theme)
                    }
                }
            }

            Menu("Language") {
                ForEach(DocumentLanguage.allCases) { language in
                    Button(language.displayName) {
                        appState.setLanguage(language)
                    }
                }
            }

            if let structuredPresentationMode = appState.selectedDocument?.availableStructuredPresentationMode {
                Divider()

                Button(appState.selectedDocument?.presentationMode == structuredPresentationMode ? "Show Raw Text" : "Show \(structuredPresentationMode.displayName)") {
                    if appState.selectedDocument?.presentationMode == structuredPresentationMode {
                        appState.showRawTextView()
                    } else {
                        appState.showStructuredView()
                    }
                }
            }

            Divider()

            Button(appState.settings.showsOutline ? "Hide Outline" : "Show Outline") {
                appState.toggleOutlinePanel()
            }

            Button(appState.settings.showsBreadcrumbs ? "Hide Breadcrumbs" : "Show Breadcrumbs") {
                appState.toggleBreadcrumbs()
            }

            Menu("Split Layout") {
                ForEach(WorkspaceSecondaryPaneMode.allCases) { mode in
                    Button(mode.displayName) {
                        appState.setSecondaryPaneMode(mode)
                    }
                }
            }

            Divider()

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

            Button(appState.selectedDocument?.includesByteOrderMark == true ? "Disable BOM" : "Enable BOM") {
                appState.toggleByteOrderMark()
            }
            .disabled(!appState.canSave)
        }

        CommandMenu("Tools") {
            Button("Workspace Center") {
                appState.showWorkspacePlatformPanel()
            }

            Button(appState.workspaceTrustMode == .trusted ? "Restrict Workspace" : "Trust Workspace") {
                if appState.workspaceTrustMode == .trusted {
                    appState.restrictCurrentWorkspace()
                } else {
                    appState.trustCurrentWorkspace()
                }
            }
            .disabled(appState.workspaceRootURLs.isEmpty)

            Divider()

            Button(appState.selectedDocument?.followModeEnabled == true ? "Disable Follow Mode" : "Enable Follow Mode") {
                appState.toggleFollowMode()
            }
            .disabled(!appState.canFollowSelectedDocument)

            Button("Workspace Sessions") {
                appState.showWorkspaceSessionsPanel()
            }

            Button("Keyboard Shortcuts") {
                appState.showingKeyboardShortcuts = true
            }

            Button("Open in Terminal") {
                appState.openSelectedDocumentInTerminal()
            }
            .disabled(appState.selectedDocument == nil && appState.projectSearchState.rootURL == nil)

            Button("Embedded Terminal") {
                appState.showTerminalConsolePanel()
            }

            Button("Problems Panel") {
                appState.showProblemsPanelView()
            }

            Button("Test Explorer") {
                appState.showTestExplorerPanel()
            }

            Divider()

            Button("Refresh Workspace Explorer") {
                appState.refreshWorkspaceExplorer()
            }

            Divider()

            Button("Export Sync Bundle...") {
                appState.exportSyncBundle()
            }

            Button("Import Sync Bundle...") {
                appState.importSyncBundle()
            }

            Divider()

            Button("Export Settings...") {
                appState.exportSettings()
            }

            Button("Import Settings...") {
                appState.importSettings()
            }
        }

        CommandMenu("Plugins") {
            Button("Plugin Manager") {
                appState.showPluginManagerPanel()
            }

            Button("Snippet Library") {
                appState.showSnippetLibraryPanel()
            }
            .disabled(appState.selectedDocument == nil)

            Button("Task Runner") {
                appState.showTaskRunnerPanel()
            }

            Button("Embedded Terminal") {
                appState.showTerminalConsolePanel()
            }

            Divider()

            Button("Format Document") {
                appState.formatSelectedDocumentUsingPlugins()
            }
            .disabled(appState.selectedDocument == nil || !appState.canSave)

            Button("Run Diagnostics") {
                appState.runPluginDiagnostics()
            }
            .disabled(appState.selectedDocument == nil)

            Divider()

            Button("Run Build Task") {
                appState.runPrimaryWorkspaceTask(.build)
            }

            Button("Run Test Task") {
                appState.runPrimaryWorkspaceTask(.test)
            }

            Button("Run Coverage Task") {
                appState.runSelectedCoverageTask()
            }

            Button("Run Lint Task") {
                appState.runPrimaryWorkspaceTask(.lint)
            }

            Divider()

            Button("Refresh Git Status") {
                appState.refreshGitStatus()
            }

            Button("Compare with Git HEAD") {
                appState.compareSelectedDocumentWithGitHead()
            }
            .disabled(appState.selectedDocument?.fileURL == nil)
        }

    }
}

struct AIWorkbenchCommands: Commands {
    @ObservedObject var appState: AppState

    var body: some Commands {
        CommandMenu("AI") {
            Button("AI Workbench") {
                appState.showAIWorkbenchPanel()
            }

            Divider()

            Button("Explain Selection") {
                appState.runAIQuickAction(.explainSelection)
            }

            Button("Improve Selection") {
                appState.runAIQuickAction(.improveSelection)
            }

            Button("Generate Tests") {
                appState.runAIQuickAction(.generateTests)
            }

            Button("Summarize File") {
                appState.runAIQuickAction(.summarizeFile)
            }

            Button("Draft Commit Message") {
                appState.runAIQuickAction(.draftCommitMessage)
            }
        }
    }
}

struct UpdateCommands: Commands {
    @ObservedObject var updateController: AppUpdateController

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates...") {
                updateController.checkForUpdates()
            }
        }
    }
}
