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

        updaterController.checkForUpdates(nil)
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
