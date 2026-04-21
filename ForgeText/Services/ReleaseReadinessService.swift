import Foundation

enum ReleaseReadinessService {
    static func state(workspaceRoots: [URL]) -> ReleaseReadinessState {
        let configuration = AppUpdateController.Configuration.fromBundle()
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let projectRoot = probableProjectRoot(workspaceRoots: workspaceRoots)
        var items: [ReleaseReadinessItem] = []

        items.append(
            ReleaseReadinessItem(
                id: "version",
                title: "Version Metadata",
                detail: "ForgeText \(version ?? "unknown") (\(build ?? "unknown build"))",
                tone: version?.isEmpty == false && build?.isEmpty == false ? .pass : .fail,
                symbolName: "number.square"
            )
        )

        items.append(
            ReleaseReadinessItem(
                id: "sparkle-feed",
                title: "Sparkle Feed URL",
                detail: configuration.feedURLString?.isEmpty == false ? configuration.feedURLString! : "SUFeedURL is missing from Info.plist.",
                tone: configuration.feedURLString?.isEmpty == false ? .pass : .fail,
                symbolName: "antenna.radiowaves.left.and.right"
            )
        )

        items.append(
            ReleaseReadinessItem(
                id: "sparkle-key",
                title: "Sparkle Signing Key",
                detail: configuration.publicEDKey?.isEmpty == false ? "SUPublicEDKey is present." : "SUPublicEDKey is missing from Info.plist.",
                tone: configuration.publicEDKey?.isEmpty == false ? .pass : .fail,
                symbolName: "key"
            )
        )

        items.append(fileItem(
            id: "build-script",
            title: "Release Build Script",
            relativePath: "Scripts/build_release_dmg.sh",
            projectRoot: projectRoot,
            required: false
        ))

        items.append(fileItem(
            id: "appcast",
            title: "Public Appcast",
            relativePath: "docs/appcast.xml",
            projectRoot: projectRoot,
            required: false
        ))

        items.append(fileItem(
            id: "updates-doc",
            title: "Update Documentation",
            relativePath: "docs/UPDATES.md",
            projectRoot: projectRoot,
            required: false
        ))

        let dmgCount = dmgCount(projectRoot: projectRoot)
        items.append(
            ReleaseReadinessItem(
                id: "dmg",
                title: "Downloadable DMG",
                detail: dmgCount > 0 ? "\(dmgCount) DMG file\(dmgCount == 1 ? "" : "s") found in dist/." : "No DMG found in dist/. Build one before publishing a public release.",
                tone: dmgCount > 0 ? .pass : .warning,
                symbolName: "opticaldiscdrive"
            )
        )

        if projectRoot == nil {
            items.append(
                ReleaseReadinessItem(
                    id: "project-root",
                    title: "Project Root",
                    detail: "Open the ForgeText source folder as a workspace to check docs, appcast, and release artifacts.",
                    tone: .info,
                    symbolName: "folder.badge.questionmark"
                )
            )
        }

        return ReleaseReadinessState(items: items, checkedAt: Date())
    }

    private static func fileItem(id: String, title: String, relativePath: String, projectRoot: URL?, required: Bool) -> ReleaseReadinessItem {
        guard let projectRoot else {
            return ReleaseReadinessItem(
                id: id,
                title: title,
                detail: "\(relativePath) could not be checked because no project root is active.",
                tone: required ? .fail : .warning,
                symbolName: "doc.badge.questionmark"
            )
        }

        let url = projectRoot.appendingPathComponent(relativePath)
        let exists = FileManager.default.fileExists(atPath: url.path)
        return ReleaseReadinessItem(
            id: id,
            title: title,
            detail: exists ? "\(relativePath) found." : "\(relativePath) is missing.",
            tone: exists ? .pass : (required ? .fail : .warning),
            symbolName: exists ? "checkmark.seal" : "exclamationmark.triangle"
        )
    }

    private static func dmgCount(projectRoot: URL?) -> Int {
        guard let projectRoot else {
            return 0
        }

        let distURL = projectRoot.appendingPathComponent("dist", isDirectory: true)
        let contents = (try? FileManager.default.contentsOfDirectory(at: distURL, includingPropertiesForKeys: nil)) ?? []
        return contents.filter { $0.pathExtension.lowercased() == "dmg" }.count
    }

    private static func probableProjectRoot(workspaceRoots: [URL]) -> URL? {
        let candidates = workspaceRoots + [URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)]
        return candidates.map(\.standardizedFileURL).first { root in
            FileManager.default.fileExists(atPath: root.appendingPathComponent("ForgeText.xcodeproj").path)
                || FileManager.default.fileExists(atPath: root.appendingPathComponent("project.yml").path)
        }
    }
}
