import AppKit

enum AppChromeStyle: String, CaseIterable, Identifiable, Codable {
    case studio
    case retroClassic
    case retroPro
    case minimalPro

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .studio:
            return "Studio"
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
        case .studio:
            return "A neutral, editor-first workbench inspired by modern code editors."
        case .retroClassic:
            return "More colorful, high-energy portal-era chrome."
        case .retroPro:
            return "A calmer daily-driver take on the late-90s style."
        case .minimalPro:
            return "The quietest shell with just a hint of retro structure."
        }
    }
}

enum WorkbenchPreset: String, CaseIterable, Identifiable, Codable {
    case quiet
    case balanced
    case fullRetro

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .quiet:
            return "Quiet UI"
        case .balanced:
            return "Balanced"
        case .fullRetro:
            return "Full Retro"
        }
    }

    var shortLabel: String {
        switch self {
        case .quiet:
            return "Quiet"
        case .balanced:
            return "Balanced"
        case .fullRetro:
            return "Retro"
        }
    }

    var summary: String {
        switch self {
        case .quiet:
            return "Studio chrome with the lowest visual noise for long editing sessions."
        case .balanced:
            return "Studio chrome with a bit more workbench context while staying calm for daily use."
        case .fullRetro:
            return "The full late-90s portal energy with richer chrome and more visible context."
        }
    }

    var appearance: WorkbenchAppearanceSnapshot {
        switch self {
        case .quiet:
            return WorkbenchAppearanceSnapshot(
                chromeStyle: .studio,
                interfaceDensity: .compact,
                focusModeEnabled: false,
                showsInspector: false,
                showsBreadcrumbs: false,
                showsSidebar: true,
                showsBottomPanel: false,
                preferredBottomPanel: .terminal
            )
        case .balanced:
            return WorkbenchAppearanceSnapshot(
                chromeStyle: .studio,
                interfaceDensity: .comfortable,
                focusModeEnabled: false,
                showsInspector: false,
                showsBreadcrumbs: true,
                showsSidebar: true,
                showsBottomPanel: true,
                preferredBottomPanel: .sourceControl
            )
        case .fullRetro:
            return WorkbenchAppearanceSnapshot(
                chromeStyle: .retroClassic,
                interfaceDensity: .comfortable,
                focusModeEnabled: false,
                showsInspector: true,
                showsBreadcrumbs: true,
                showsSidebar: true,
                showsBottomPanel: true,
                preferredBottomPanel: .terminal
            )
        }
    }

    static func matching(_ appearance: WorkbenchAppearanceSnapshot) -> WorkbenchPreset? {
        allCases.first(where: { preset in
            let candidate = preset.appearance
            return candidate.chromeStyle == appearance.chromeStyle
                && candidate.interfaceDensity == appearance.interfaceDensity
                && candidate.focusModeEnabled == appearance.focusModeEnabled
                && candidate.showsInspector == appearance.showsInspector
                && candidate.showsBreadcrumbs == appearance.showsBreadcrumbs
                && candidate.showsSidebar == appearance.showsSidebar
                && candidate.showsBottomPanel == appearance.showsBottomPanel
        })
    }
}

struct WorkbenchAppearanceSnapshot: Codable, Hashable {
    var chromeStyle: AppChromeStyle
    var interfaceDensity: InterfaceDensity
    var focusModeEnabled: Bool
    var showsInspector: Bool
    var showsBreadcrumbs: Bool
    var showsSidebar: Bool
    var showsBottomPanel: Bool
    var preferredBottomPanel: WorkbenchBottomPanel
}

enum WorkbenchBottomPanel: String, CaseIterable, Identifiable, Codable {
    case search
    case sourceControl
    case terminal
    case problems
    case tests
    case assistant

    var id: String { rawValue }

    var title: String {
        switch self {
        case .search:
            return "Search"
        case .sourceControl:
            return "Source Control"
        case .terminal:
            return "Terminal"
        case .problems:
            return "Problems"
        case .tests:
            return "Tests"
        case .assistant:
            return "AI"
        }
    }

    var symbolName: String {
        switch self {
        case .search:
            return "magnifyingglass"
        case .sourceControl:
            return "arrow.triangle.branch"
        case .terminal:
            return "terminal"
        case .problems:
            return "exclamationmark.circle"
        case .tests:
            return "checkmark.circle"
        case .assistant:
            return "sparkles"
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
    var chromeStyle: AppChromeStyle = .studio
    var interfaceDensity: InterfaceDensity = .compact
    var workbenchPreset: WorkbenchPreset? = .quiet
    var customWorkbenchAppearance = WorkbenchPreset.quiet.appearance
    var hasCompletedFirstRunExperience = false
    var focusModeEnabled = false
    var showsSidebar = true
    var showsBottomPanel = false
    var preferredBottomPanel: WorkbenchBottomPanel = .terminal
    var wrapLines = false
    var autosaveToDisk = true
    var fontSize: Double = 14
    var showsOutline = true
    var showsInspector = false
    var showsBreadcrumbs = false
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
    var advanced = AdvancedEditorSettings()

    init() {}

    private enum CodingKeys: String, CodingKey {
        case theme
        case chromeStyle
        case interfaceDensity
        case workbenchPreset
        case customWorkbenchAppearance
        case hasCompletedFirstRunExperience
        case focusModeEnabled
        case showsSidebar
        case showsBottomPanel
        case preferredBottomPanel
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
        case advanced
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        theme = try container.decodeIfPresent(EditorTheme.self, forKey: .theme) ?? .forge
        chromeStyle = try container.decodeIfPresent(AppChromeStyle.self, forKey: .chromeStyle) ?? .studio
        interfaceDensity = try container.decodeIfPresent(InterfaceDensity.self, forKey: .interfaceDensity) ?? .compact
        workbenchPreset = try container.decodeIfPresent(WorkbenchPreset.self, forKey: .workbenchPreset)
            ?? WorkbenchPreset.matching(
                WorkbenchAppearanceSnapshot(
                    chromeStyle: chromeStyle,
                    interfaceDensity: interfaceDensity,
                    focusModeEnabled: try container.decodeIfPresent(Bool.self, forKey: .focusModeEnabled) ?? false,
                    showsInspector: try container.decodeIfPresent(Bool.self, forKey: .showsInspector) ?? false,
                    showsBreadcrumbs: try container.decodeIfPresent(Bool.self, forKey: .showsBreadcrumbs) ?? false,
                    showsSidebar: try container.decodeIfPresent(Bool.self, forKey: .showsSidebar) ?? true,
                    showsBottomPanel: try container.decodeIfPresent(Bool.self, forKey: .showsBottomPanel) ?? false,
                    preferredBottomPanel: try container.decodeIfPresent(WorkbenchBottomPanel.self, forKey: .preferredBottomPanel) ?? .terminal
                )
            )
            ?? .quiet
        customWorkbenchAppearance = try container.decodeIfPresent(WorkbenchAppearanceSnapshot.self, forKey: .customWorkbenchAppearance)
            ?? WorkbenchAppearanceSnapshot(
                chromeStyle: chromeStyle,
                interfaceDensity: interfaceDensity,
                focusModeEnabled: try container.decodeIfPresent(Bool.self, forKey: .focusModeEnabled) ?? false,
                showsInspector: try container.decodeIfPresent(Bool.self, forKey: .showsInspector) ?? false,
                showsBreadcrumbs: try container.decodeIfPresent(Bool.self, forKey: .showsBreadcrumbs) ?? false,
                showsSidebar: try container.decodeIfPresent(Bool.self, forKey: .showsSidebar) ?? true,
                showsBottomPanel: try container.decodeIfPresent(Bool.self, forKey: .showsBottomPanel) ?? false,
                preferredBottomPanel: try container.decodeIfPresent(WorkbenchBottomPanel.self, forKey: .preferredBottomPanel) ?? .terminal
            )
        hasCompletedFirstRunExperience = try container.decodeIfPresent(Bool.self, forKey: .hasCompletedFirstRunExperience) ?? false
        focusModeEnabled = try container.decodeIfPresent(Bool.self, forKey: .focusModeEnabled) ?? false
        showsSidebar = try container.decodeIfPresent(Bool.self, forKey: .showsSidebar) ?? true
        showsBottomPanel = try container.decodeIfPresent(Bool.self, forKey: .showsBottomPanel) ?? false
        preferredBottomPanel = try container.decodeIfPresent(WorkbenchBottomPanel.self, forKey: .preferredBottomPanel) ?? .terminal
        wrapLines = try container.decodeIfPresent(Bool.self, forKey: .wrapLines) ?? false
        autosaveToDisk = try container.decodeIfPresent(Bool.self, forKey: .autosaveToDisk) ?? true
        fontSize = try container.decodeIfPresent(Double.self, forKey: .fontSize) ?? 14
        showsOutline = try container.decodeIfPresent(Bool.self, forKey: .showsOutline) ?? true
        showsInspector = try container.decodeIfPresent(Bool.self, forKey: .showsInspector) ?? false
        showsBreadcrumbs = try container.decodeIfPresent(Bool.self, forKey: .showsBreadcrumbs) ?? false
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
        advanced = try container.decodeIfPresent(AdvancedEditorSettings.self, forKey: .advanced) ?? AdvancedEditorSettings()
    }
}

enum RuntimePerformanceMode: String, CaseIterable, Identifiable, Codable {
    case standard
    case performance

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .standard:
            return "Standard"
        case .performance:
            return "Performance"
        }
    }

    var summary: String {
        switch self {
        case .standard:
            return "Keep live editor context, Git hints, and richer workbench signals turned on."
        case .performance:
            return "Prioritize typing latency and calmer background work in larger files and heavier repositories."
        }
    }
}

struct FileHandlingAdvancedSettings: Codable, Hashable {
    var alwaysOpenInRawView = true
    var autosaveDelayMilliseconds = 1_500
    var defaultLineEnding: LineEnding = .lf
    var restorePreviousSessionOnLaunch = true
    var externalChangePollingIntervalSeconds = 2.5
}

struct PerformanceAdvancedSettings: Codable, Hashable {
    var mode: RuntimePerformanceMode = .standard
    var autoEnableForLargeFiles = true
    var liveDiagnosticsEnabled = true
    var documentInsightsEnabled = true
    var indexWorkspaceSymbols = true
}

struct GitAdvancedSettings: Codable, Hashable {
    var enableLineDecorations = true
    var enableBlamePrefetch = true
    var largeRepositoryMode = false
}

struct AIPrivacyAdvancedSettings: Codable, Hashable {
    var localModelsOnly = false
    var requireReviewBeforeSend = false
    var redactSensitiveContext = true
    var maxContextCharacters = 12_000
}

struct PluginHardeningAdvancedSettings: Codable, Hashable {
    var allowWorkspacePlugins = true
    var allowTaskCapablePlugins = true
    var allowCustomRegistries = true
}

struct RemoteAdvancedSettings: Codable, Hashable {
    var openFilesReadOnly = false
    var allowRemoteCommands = true
    var allowRemoteAgentInstall = true
}

struct SafeModeSettings: Codable, Hashable {
    var isEnabled = false
    var restoresPreviousSession = false
    var allowsExternalPlugins = false
    var allowsAI = false
    var allowsRemoteConnections = false
}

struct AdvancedEditorSettings: Codable, Hashable {
    var fileHandling = FileHandlingAdvancedSettings()
    var performance = PerformanceAdvancedSettings()
    var git = GitAdvancedSettings()
    var ai = AIPrivacyAdvancedSettings()
    var plugins = PluginHardeningAdvancedSettings()
    var remote = RemoteAdvancedSettings()
    var safeMode = SafeModeSettings()
}
