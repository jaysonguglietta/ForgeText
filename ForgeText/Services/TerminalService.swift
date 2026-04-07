import AppKit
import Foundation

enum TerminalService {
    static func openDirectory(_ directoryURL: URL) {
        guard let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal") else {
            return
        }

        NSWorkspace.shared.open(
            [directoryURL],
            withApplicationAt: terminalURL,
            configuration: NSWorkspace.OpenConfiguration()
        ) { _, _ in }
    }
}
