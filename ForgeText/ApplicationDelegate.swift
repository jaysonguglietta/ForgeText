import AppKit

@MainActor
final class ApplicationDelegate: NSObject, NSApplicationDelegate {
    let appState = AppState()

    func application(_ application: NSApplication, open urls: [URL]) {
        openDocuments(at: urls)
    }

    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        openDocuments(at: [URL(fileURLWithPath: filename)])
        return true
    }

    func application(_ application: NSApplication, openFiles filenames: [String]) {
        openDocuments(at: filenames.map(URL.init(fileURLWithPath:)))
        application.reply(toOpenOrPrint: .success)
    }

    private func openDocuments(at urls: [URL]) {
        let fileURLs = urls
            .filter(\.isFileURL)
            .map(\.standardizedFileURL)

        guard !fileURLs.isEmpty else {
            return
        }

        appState.openDocuments(at: fileURLs)
        NSApp.activate(ignoringOtherApps: true)
    }
}
