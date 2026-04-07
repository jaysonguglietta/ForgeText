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

            Button("Open Remote...") {
                appState.openRemotePanel()
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

            Divider()

            Button("Export Settings...") {
                appState.exportSettings()
            }

            Button("Import Settings...") {
                appState.importSettings()
            }
        }
    }
}
