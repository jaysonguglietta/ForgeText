import AppKit
import Foundation
import Sparkle

@MainActor
final class AppUpdateController: NSObject, ObservableObject {
    private static let defaultFeedURL = "https://jaysonguglietta.github.io/ForgeText/appcast.xml"

    private let updaterController: SPUStandardUpdaterController?
    private let configuration: Configuration

    override init() {
        configuration = Configuration.fromBundle()

        if configuration.isReady {
            updaterController = SPUStandardUpdaterController(
                startingUpdater: true,
                updaterDelegate: nil,
                userDriverDelegate: nil
            )
        } else {
            updaterController = nil
        }

        super.init()
    }

    var isFullyConfigured: Bool {
        configuration.isReady
    }

    func checkForUpdates() {
        guard let updaterController else {
            presentSetupAlert()
            return
        }

        Task { [configuration] in
            let availability = await Self.checkFeedAvailability(configuration: configuration)

            switch availability {
            case .available:
                updaterController.checkForUpdates(nil)
            case .unavailable(let details):
                presentFeedUnavailableAlert(details: details)
            }
        }
    }

    private func presentSetupAlert() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "ForgeText Updates Need One-Time Release Setup"
        alert.informativeText = """
        The updater button is wired in, but public release updates are not fully configured yet.

        Missing pieces:
        \(configuration.missingRequirements.joined(separator: "\n"))

        Expected appcast URL:
        \(configuration.feedURLString ?? Self.defaultFeedURL)

        Finish the setup in docs/UPDATES.md, then rebuild ForgeText and this button will use Sparkle to check for updates.
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func presentFeedUnavailableAlert(details: FeedAvailability.Details) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "ForgeText Could Not Reach Its Update Feed"
        alert.informativeText = """
        ForgeText is configured for updates, but the public appcast is not reachable yet.

        Feed URL:
        \(details.feedURL)

        What I found:
        \(details.summary)

        Next steps:
        • Push the updater files, including docs/appcast.xml, to the public repo.
        • Enable GitHub Pages for the repository's docs folder.
        • Retry Check for Updates after the site is live.
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private static func checkFeedAvailability(configuration: Configuration) async -> FeedAvailability {
        guard let feedURLString = configuration.feedURLString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !feedURLString.isEmpty,
              let feedURL = URL(string: feedURLString) else {
            return .unavailable(.init(
                feedURL: configuration.feedURLString ?? defaultFeedURL,
                summary: "• The configured feed URL is missing or invalid."
            ))
        }

        var request = URLRequest(url: feedURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 10
        request.cachePolicy = .reloadIgnoringLocalCacheData

        do {
            let (_, response) = try await URLSession.shared.data(for: request)

            if let httpResponse = response as? HTTPURLResponse,
               !(200..<300).contains(httpResponse.statusCode) {
                return .unavailable(.init(
                    feedURL: feedURLString,
                    summary: "• The server responded with HTTP \(httpResponse.statusCode)."
                ))
            }

            return .available
        } catch {
            return .unavailable(.init(
                feedURL: feedURLString,
                summary: "• \(error.localizedDescription)"
            ))
        }
    }
}

extension AppUpdateController {
    enum FeedAvailability {
        case available
        case unavailable(Details)

        struct Details {
            let feedURL: String
            let summary: String
        }
    }
}

extension AppUpdateController {
    struct Configuration {
        let feedURLString: String?
        let publicEDKey: String?

        var missingRequirements: [String] {
            var messages: [String] = []

            if feedURLString?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                messages.append("• Add SUFeedURL to Info.plist and point it at your GitHub Pages appcast.")
            }

            if publicEDKey?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
                messages.append("• Add SUPublicEDKey to Info.plist after generating Sparkle signing keys.")
            }

            return messages
        }

        var isReady: Bool {
            missingRequirements.isEmpty
        }

        static func fromBundle(_ bundle: Bundle = .main) -> Self {
            let feedURLString = bundle.object(forInfoDictionaryKey: "SUFeedURL") as? String
            let publicEDKey = bundle.object(forInfoDictionaryKey: "SUPublicEDKey") as? String
            return Self(feedURLString: feedURLString, publicEDKey: publicEDKey)
        }
    }
}
