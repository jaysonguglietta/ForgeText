import Foundation

enum StoragePathService {
    private static let appSupportFolderName = "ForgeText"

    static func portableDataDirectoryURL(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> URL? {
        if let explicitPath = processInfo.environment["FORGETEXT_PORTABLE_DATA_DIR"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !explicitPath.isEmpty {
            return URL(fileURLWithPath: explicitPath, isDirectory: true)
        }

        let siblingDirectory = bundle.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("ForgeTextData", isDirectory: true)

        guard FileManager.default.fileExists(atPath: siblingDirectory.path) else {
            return nil
        }

        return siblingDirectory
    }

    static var isPortableModeEnabled: Bool {
        portableDataDirectoryURL() != nil
    }

    static func appDataDirectoryURL() -> URL {
        if let portableDirectory = portableDataDirectoryURL() {
            return portableDirectory
        }

        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory

        return baseDirectory.appendingPathComponent(appSupportFolderName, isDirectory: true)
    }

    static func ensureDirectoryExists(_ directoryURL: URL) {
        try? FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: true)
    }

    static func dataFileURL(named filename: String) -> URL {
        let directoryURL = appDataDirectoryURL()
        ensureDirectoryExists(directoryURL)
        return directoryURL.appendingPathComponent(filename)
    }

    static func userPluginDirectoryURL() -> URL {
        let pluginsDirectory = appDataDirectoryURL().appendingPathComponent("Plugins", isDirectory: true)
        ensureDirectoryExists(pluginsDirectory)
        return pluginsDirectory
    }
}
