import Foundation

enum LaunchCommandService {
    struct LineTarget {
        let fileURL: URL
        let lineNumber: Int
    }

    struct DiffRequest {
        let leftURL: URL
        let rightURL: URL
    }

    struct LaunchPlan {
        var workspaceFileURL: URL?
        var profileName: String?
        var fileURLs: [URL] = []
        var lineTarget: LineTarget?
        var diffRequest: DiffRequest?
    }

    static func parse(arguments: [String]) -> LaunchPlan {
        var plan = LaunchPlan()
        var index = 0

        while index < arguments.count {
            let argument = arguments[index]

            switch argument {
            case "--workspace":
                if index + 1 < arguments.count {
                    plan.workspaceFileURL = URL(fileURLWithPath: arguments[index + 1]).standardizedFileURL
                    index += 1
                }
            case "--profile":
                if index + 1 < arguments.count {
                    plan.profileName = arguments[index + 1]
                    index += 1
                }
            case "--diff":
                if index + 2 < arguments.count {
                    plan.diffRequest = DiffRequest(
                        leftURL: URL(fileURLWithPath: arguments[index + 1]).standardizedFileURL,
                        rightURL: URL(fileURLWithPath: arguments[index + 2]).standardizedFileURL
                    )
                    index += 2
                }
            default:
                if let target = parseLineTarget(argument) {
                    plan.fileURLs.append(target.fileURL)
                    plan.lineTarget = target
                } else {
                    let url = URL(fileURLWithPath: argument).standardizedFileURL
                    if url.pathExtension == WorkspacePlatformService.workspaceFileExtension {
                        plan.workspaceFileURL = url
                    } else {
                        plan.fileURLs.append(url)
                    }
                }
            }

            index += 1
        }

        var seenPaths = Set<String>()
        plan.fileURLs = plan.fileURLs.filter { seenPaths.insert($0.path).inserted }
        return plan
    }

    private static func parseLineTarget(_ argument: String) -> LineTarget? {
        let nsArgument = argument as NSString
        let range = NSRange(location: 0, length: nsArgument.length)
        guard let regex = try? NSRegularExpression(pattern: #"^(.*):(\d+)$"#),
              let match = regex.firstMatch(in: argument, options: [], range: range),
              match.numberOfRanges == 3
        else {
            return nil
        }

        let path = nsArgument.substring(with: match.range(at: 1))
        guard FileManager.default.fileExists(atPath: path) else {
            return nil
        }

        let lineValue = nsArgument.substring(with: match.range(at: 2))
        guard let lineNumber = Int(lineValue), lineNumber > 0 else {
            return nil
        }

        return LineTarget(
            fileURL: URL(fileURLWithPath: path).standardizedFileURL,
            lineNumber: lineNumber
        )
    }
}
