import AppKit

enum AppChromeStyle: String, CaseIterable, Identifiable, Codable {
    case retroClassic
    case retroPro
    case minimalPro

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .retroClassic:
            return "Retro Classic"
        case .retroPro:
            return "Retro Pro"
        case .minimalPro:
            return "Minimal Pro"
        }
    }

    var summary: String {
        switch self {
        case .retroClassic:
            return "More colorful, high-energy portal-era chrome."
        case .retroPro:
            return "A calmer daily-driver take on the late-90s style."
        case .minimalPro:
            return "The quietest shell with just a hint of retro structure."
        }
    }
}

enum InterfaceDensity: String, CaseIterable, Identifiable, Codable {
    case comfortable
    case compact
    case dense

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .comfortable:
            return "Comfortable"
        case .compact:
            return "Compact"
        case .dense:
            return "Dense"
        }
    }
}

enum EditorTheme: String, CaseIterable, Identifiable, Codable {
    case forge
    case blueprint
    case vellum

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .forge:
            return "Forge"
        case .blueprint:
            return "Blueprint"
        case .vellum:
            return "Vellum"
        }
    }

    var backgroundColor: NSColor {
        switch self {
        case .forge:
            return NSColor(calibratedRed: 0.11, green: 0.13, blue: 0.17, alpha: 1)
        case .blueprint:
            return NSColor(calibratedRed: 0.08, green: 0.15, blue: 0.22, alpha: 1)
        case .vellum:
            return NSColor(calibratedRed: 0.95, green: 0.93, blue: 0.89, alpha: 1)
        }
    }

    var textColor: NSColor {
        switch self {
        case .forge, .blueprint:
            return NSColor(calibratedRed: 0.93, green: 0.93, blue: 0.93, alpha: 1)
        case .vellum:
            return NSColor(calibratedRed: 0.18, green: 0.18, blue: 0.17, alpha: 1)
        }
    }

    var secondaryTextColor: NSColor {
        switch self {
        case .forge:
            return NSColor(calibratedRed: 0.62, green: 0.66, blue: 0.71, alpha: 1)
        case .blueprint:
            return NSColor(calibratedRed: 0.59, green: 0.74, blue: 0.86, alpha: 1)
        case .vellum:
            return NSColor(calibratedRed: 0.46, green: 0.42, blue: 0.37, alpha: 1)
        }
    }

    var gutterBackgroundColor: NSColor {
        switch self {
        case .forge:
            return NSColor(calibratedRed: 0.08, green: 0.09, blue: 0.12, alpha: 1)
        case .blueprint:
            return NSColor(calibratedRed: 0.05, green: 0.11, blue: 0.17, alpha: 1)
        case .vellum:
            return NSColor(calibratedRed: 0.90, green: 0.88, blue: 0.84, alpha: 1)
        }
    }

    var gutterTextColor: NSColor {
        secondaryTextColor
    }

    var accentColor: NSColor {
        switch self {
        case .forge:
            return NSColor(calibratedRed: 1.0, green: 0.42, blue: 0.24, alpha: 1)
        case .blueprint:
            return NSColor(calibratedRed: 0.36, green: 0.78, blue: 0.95, alpha: 1)
        case .vellum:
            return NSColor(calibratedRed: 0.70, green: 0.31, blue: 0.16, alpha: 1)
        }
    }

    var badgeBackgroundColor: NSColor {
        accentColor.withAlphaComponent(0.14)
    }

    var selectionColor: NSColor {
        accentColor.withAlphaComponent(self == .vellum ? 0.25 : 0.33)
    }

    var borderColor: NSColor {
        secondaryTextColor.withAlphaComponent(0.22)
    }

    var keywordColor: NSColor {
        switch self {
        case .forge:
            return NSColor(calibratedRed: 0.97, green: 0.76, blue: 0.39, alpha: 1)
        case .blueprint:
            return NSColor(calibratedRed: 0.54, green: 0.84, blue: 1.0, alpha: 1)
        case .vellum:
            return NSColor(calibratedRed: 0.53, green: 0.27, blue: 0.13, alpha: 1)
        }
    }

    var stringColor: NSColor {
        switch self {
        case .forge:
            return NSColor(calibratedRed: 0.53, green: 0.87, blue: 0.62, alpha: 1)
        case .blueprint:
            return NSColor(calibratedRed: 0.61, green: 0.92, blue: 0.82, alpha: 1)
        case .vellum:
            return NSColor(calibratedRed: 0.23, green: 0.45, blue: 0.27, alpha: 1)
        }
    }

    var commentColor: NSColor {
        secondaryTextColor.withAlphaComponent(0.88)
    }

    var numberColor: NSColor {
        switch self {
        case .forge:
            return NSColor(calibratedRed: 0.91, green: 0.50, blue: 0.70, alpha: 1)
        case .blueprint:
            return NSColor(calibratedRed: 0.94, green: 0.62, blue: 0.77, alpha: 1)
        case .vellum:
            return NSColor(calibratedRed: 0.61, green: 0.15, blue: 0.35, alpha: 1)
        }
    }

    var linkColor: NSColor {
        switch self {
        case .forge:
            return NSColor(calibratedRed: 0.48, green: 0.75, blue: 1.0, alpha: 1)
        case .blueprint:
            return NSColor(calibratedRed: 0.75, green: 0.90, blue: 1.0, alpha: 1)
        case .vellum:
            return NSColor(calibratedRed: 0.15, green: 0.35, blue: 0.61, alpha: 1)
        }
    }

    var warningColor: NSColor {
        switch self {
        case .forge, .vellum:
            return NSColor.systemOrange
        case .blueprint:
            return NSColor.systemYellow
        }
    }

    var currentSearchHighlightColor: NSColor {
        accentColor.withAlphaComponent(0.68)
    }

    var searchHighlightColor: NSColor {
        accentColor.withAlphaComponent(0.28)
    }

    var badgeTextColor: NSColor {
        switch self {
        case .vellum:
            return NSColor(calibratedRed: 0.31, green: 0.19, blue: 0.12, alpha: 1)
        case .forge, .blueprint:
            return accentColor
        }
    }
}

struct AppSettings: Codable {
    var theme: EditorTheme = .forge
    var chromeStyle: AppChromeStyle = .retroPro
    var interfaceDensity: InterfaceDensity = .compact
    var focusModeEnabled = false
    var wrapLines = false
    var autosaveToDisk = true
    var fontSize: Double = 14
    var showsOutline = true
    var showsInspector = true
    var showsBreadcrumbs = true
    var savedLogFilters: [SavedLogFilter] = []
    var enabledPluginIDs: [String] = []
    var showHiddenFilesInExplorer = false
    var workspaceFavoritePaths: [String] = []
    var profiles: [WorkspaceProfile] = []
    var trustedWorkspacePaths: [String] = []
    var trustedWorkspaces: [TrustedWorkspaceRecord] = []
    var pluginRegistries: [PluginRegistryConfiguration] = []
    var aiProviders: [AIProviderConfiguration] = AIProviderDefaults.profiles
    var preferredAIProviderID: UUID?
    var aiIncludeSelection = true
    var aiIncludeCurrentDocument = true
    var aiIncludeWorkspaceRules = true

    init() {}

    private enum CodingKeys: String, CodingKey {
        case theme
        case chromeStyle
        case interfaceDensity
        case focusModeEnabled
        case wrapLines
        case autosaveToDisk
        case fontSize
        case showsOutline
        case showsInspector
        case showsBreadcrumbs
        case savedLogFilters
        case enabledPluginIDs
        case showHiddenFilesInExplorer
        case workspaceFavoritePaths
        case profiles
        case trustedWorkspacePaths
        case trustedWorkspaces
        case pluginRegistries
        case aiProviders
        case preferredAIProviderID
        case aiIncludeSelection
        case aiIncludeCurrentDocument
        case aiIncludeWorkspaceRules
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        theme = try container.decodeIfPresent(EditorTheme.self, forKey: .theme) ?? .forge
        chromeStyle = try container.decodeIfPresent(AppChromeStyle.self, forKey: .chromeStyle) ?? .retroPro
        interfaceDensity = try container.decodeIfPresent(InterfaceDensity.self, forKey: .interfaceDensity) ?? .compact
        focusModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .focusModeEnabled) ?? false
        wrapLines = try container.decodeIfPresent(Bool.self, forKey: .wrapLines) ?? false
        autosaveToDisk = try container.decodeIfPresent(Bool.self, forKey: .autosaveToDisk) ?? true
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? 14
        showsOutline = try container.decodeIfPresent(Bool.self, forKey: .showsOutline) ?? true
        showsInspector = try container.decodeIfPresent(Bool.self, forKey: .showsInspector) ?? true
        showsBreadcrumbs = try container.decodeIfPresent(Bool.self, forKey: .showsBreadcrumbs) ?? true
        savedLogFilters = try container.decodeIfPresent([SavedLogFilter].self, forKey: .savedLogFilters) ?? []
        enabledPluginIDs = try container.decodeIfPresent([String].self, forKey: .enabledPluginIDs) ?? PluginHostService.defaultEnabledPluginIDs
        showHiddenFilesInExplorer = try container.decodeIfPresent(Bool.self, forKey: .showHiddenFilesInExplorer) ?? false
        workspaceFavoritePaths = try container.decodeIfPresent([String].self, forKey: .workspaceFavoritePaths) ?? []
        profiles = try container.decodeIfPresent([WorkspaceProfile].self, forKey: .profiles) ?? []
        trustedWorkspacePaths = try container.decodeIfPresent([String].self, forKey: .trustedWorkspacePaths) ?? []
        trustedWorkspaces = try container.decodeIfPresent([TrustedWorkspaceRecord].self, forKey: .trustedWorkspaces)
            ?? trustedWorkspacePaths.map {
                TrustedWorkspaceRecord(
                    displayPath: $0,
                    resolvedPath: URL(fileURLWithPath: $0, isDirectory: true)
                        .resolvingSymlinksInPath()
                        .standardizedFileURL
                        .path
                )
            }
        pluginRegistries = try container.decodeIfPresent([PluginRegistryConfiguration].self, forKey: .pluginRegistries) ?? []
        aiProviders = try container.decodeIfPresent([AIProviderConfiguration].self, forKey: .aiProviders) ?? AIProviderDefaults.profiles
        preferredAIProviderID = try container.decodeIfPresent(UUID.self, forKey: .preferredAIProviderID)
        aiIncludeSelection = try container.decodeIfPresent(Bool.self, forKey: .aiIncludeSelection) ?? true
        aiIncludeCurrentDocument = try container.decodeIfPresent(Bool.self, forKey: .aiIncludeCurrentDocument) ?? true
        aiIncludeWorkspaceRules = try container.decodeIfPresent(Bool.self, forKey: .aiIncludeWorkspaceRules) ?? true
    }
}
