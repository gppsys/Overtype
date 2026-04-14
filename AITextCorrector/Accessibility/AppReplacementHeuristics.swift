import Foundation

/// Determines how corrected text is written back into the originating app.
enum AppReplacementStrategy {
    /// Try direct Accessibility attribute replacement first; fall back to clipboard paste.
    case accessibilityPreferred
    /// Skip Accessibility replacement and use clipboard paste directly.
    /// Used for apps where AX writes silently fail or corrupt formatting.
    case clipboardPasteOnly
}

enum AppReplacementHeuristics {
    /// Apps known to work poorly with direct AX text replacement.
    /// Electron-based apps, web browsers and some native apps with custom text engines
    /// generally ignore or mishandle AXSelectedText / AXValue writes.
    private static let clipboardPasteOnlyBundles: Set<String> = [
        // Browsers
        "com.apple.Safari",
        "com.google.Chrome",
        "org.mozilla.firefox",
        "com.microsoft.edgemac",
        "com.brave.Browser",
        "com.operasoftware.Opera",
        "com.vivaldi.Vivaldi",
        // Electron / web-based apps
        "com.tinyspeck.slackmacOS",
        "com.hnc.Discord",
        "com.figma.Desktop",
        "com.microsoft.teams2",
        "com.notion.id",
        "com.linear.Linear",
        "md.obsidian",
        "com.github.GitHubClient",
        "com.microsoft.VSCode",
        "com.todesktop.230313mzl4w4u92",  // Loom
    ]

    static func strategy(for bundleIdentifier: String?) -> AppReplacementStrategy {
        guard let id = bundleIdentifier else { return .accessibilityPreferred }
        return clipboardPasteOnlyBundles.contains(id) ? .clipboardPasteOnly : .accessibilityPreferred
    }
}
