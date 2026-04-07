import CoreServices
import Foundation
import UniformTypeIdentifiers

let appBundleIdentifier = "com.jaysonguglietta.ForgeText"

let explicitTypeIdentifiers: Set<String> = [
    "public.text",
    "public.plain-text",
    "public.source-code",
    "public.json",
    "public.xml",
    "public.html",
    "net.daringfireball.markdown",
    "public.comma-separated-values-text",
]

let filenameExtensions = [
    "txt", "text",
    "md", "markdown", "mkd", "rmd",
    "json", "jsonc",
    "xml", "html", "htm", "svg", "xhtml", "plist",
    "swift",
    "sh", "bash", "zsh", "fish", "command",
    "js", "jsx", "mjs", "cjs", "ts", "tsx",
    "py", "pyw",
    "css", "scss", "sass", "less",
    "sql", "psql",
    "ini", "toml", "yaml", "yml", "conf", "cfg", "env", "properties",
    "tf", "tfvars", "service", "socket", "mount", "timer", "target", "path", "rules",
    "log", "out", "err", "trace",
    "csv", "tsv", "tab",
]

var contentTypes = explicitTypeIdentifiers

for filenameExtension in filenameExtensions {
    if let type = UTType(filenameExtension: filenameExtension) {
        contentTypes.insert(type.identifier)
    }
}

var failures: [(String, OSStatus)] = []
var applied: [String] = []

for contentType in contentTypes.sorted() {
    let status = LSSetDefaultRoleHandlerForContentType(
        contentType as CFString,
        .all,
        appBundleIdentifier as CFString
    )

    if status == noErr {
        applied.append(contentType)
    } else {
        failures.append((contentType, status))
    }
}

print("Applied ForgeText as default editor for \(applied.count) content types.")

if !failures.isEmpty {
    fputs("Some content types could not be updated:\n", stderr)
    for failure in failures {
        fputs("  \(failure.0): \(failure.1)\n", stderr)
    }
}

let sampleIdentifiers = [
    "public.plain-text",
    "public.source-code",
    "public.json",
    "public.xml",
    "net.daringfireball.markdown",
    "public.comma-separated-values-text",
]

for contentType in sampleIdentifiers {
    let handler = LSCopyDefaultRoleHandlerForContentType(contentType as CFString, .all)?
        .takeRetainedValue() as String?
        ?? "none"
    print("\(contentType) -> \(handler)")
}
