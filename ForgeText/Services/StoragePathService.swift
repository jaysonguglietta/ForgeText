import Darwin
import Foundation

enum StoragePathService {
    private static let appSupportFolderName = "ForgeText"
    private static let portableMarkerName = ".forgetext-portable"

    static func portableDataDirectoryURL(
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) -> URL? {
        if let explicitPath = processInfo.environment["FORGETEXT_PORTABLE_DATA_DIR"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !explicitPath.isEmpty {
            return validatedPortableDirectory(URL(fileURLWithPath: explicitPath, isDirectory: true))
        }

        let siblingDirectory = bundle.bundleURL
            .deletingLastPathComponent()
            .appendingPathComponent("ForgeTextData", isDirectory: true)

        guard FileManager.default.fileExists(
            atPath: siblingDirectory.appendingPathComponent(portableMarkerName).path
        ) else {
            return nil
        }

        return validatedPortableDirectory(siblingDirectory)
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
        try? FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directoryURL.path)
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

    static func isPortableDataURL(_ url: URL) -> Bool {
        guard let portableDirectory = portableDataDirectoryURL() else {
            return false
        }
        let rootPath = portableDirectory.standardizedFileURL.path
        let candidatePath = url.standardizedFileURL.path
        return candidatePath == rootPath || candidatePath.hasPrefix(rootPath + "/")
    }

    private static func validatedPortableDirectory(_ directory: URL) -> URL? {
        let standardizedDirectory = directory.standardizedFileURL
        guard standardizedDirectory.resolvingSymlinksInPath().path == standardizedDirectory.path,
              let values = try? standardizedDirectory.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey]),
              values.isDirectory == true,
              values.isSymbolicLink != true,
              let attributes = try? FileManager.default.attributesOfItem(atPath: standardizedDirectory.path),
              (attributes[.ownerAccountID] as? NSNumber)?.uint32Value == getuid(),
              let permissions = (attributes[.posixPermissions] as? NSNumber)?.uint16Value,
              permissions & 0o077 == 0
        else {
            return nil
        }

        return standardizedDirectory
    }
}
