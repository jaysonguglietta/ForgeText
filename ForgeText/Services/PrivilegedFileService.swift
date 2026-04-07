import Foundation

enum PrivilegedFileService {
    static func write(data: Data, to url: URL) throws {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("forge-privileged-\(UUID().uuidString)")
        try data.write(to: tempURL, options: .atomic)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        let targetPath = CommandExecutionService.shellQuote(url.path)
        let tempPath = CommandExecutionService.shellQuote(tempURL.path)

        let shellScript = """
        set -e
        if [ -e \(targetPath) ]; then
          perms=$(/usr/bin/stat -f %Lp \(targetPath) 2>/dev/null || echo 644)
        else
          perms=644
        fi
        /usr/bin/install -m "$perms" \(tempPath) \(targetPath)
        """

        let command = "/bin/sh -c " + CommandExecutionService.shellQuote(shellScript)
        let appleScript = "do shell script \"\(CommandExecutionService.appleScriptQuote(command))\" with administrator privileges"
        _ = try CommandExecutionService.run("/usr/bin/osascript", arguments: ["-e", appleScript])
    }

    static func likelyNeedsPrivilege(for url: URL) -> Bool {
        let path = url.path
        let protectedPrefixes = [
            "/etc/",
            "/private/etc/",
            "/Library/",
            "/System/",
            "/private/var/root/",
            "/usr/local/etc/",
        ]

        if protectedPrefixes.contains(where: path.hasPrefix) {
            return true
        }

        return !FileManager.default.isWritableFile(atPath: url.path)
    }

    static func isPermissionFailure(_ error: Error) -> Bool {
        let nsError = error as NSError
        return nsError.domain == NSCocoaErrorDomain
            && [NSFileWriteNoPermissionError, NSFileReadNoPermissionError, NSFileWriteUnknownError].contains(nsError.code)
    }
}
