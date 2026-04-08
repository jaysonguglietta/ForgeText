import Foundation

enum ToolchainService {
    static func executablePath(named executable: String) -> String? {
        guard let output = try? CommandExecutionService.runString("/usr/bin/which", arguments: [executable]) else {
            return nil
        }

        let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
        return path.isEmpty ? nil : path
    }

    static func isAvailable(_ executable: String) -> Bool {
        executablePath(named: executable) != nil
    }
}
