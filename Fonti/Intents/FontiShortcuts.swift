import AppIntents

/// The zero-configuration voice entry points into Fonti.
///
/// Kept to a deliberately small, high-value set. An app may declare at most ten
/// App Shortcuts (enforced at build time), and piling on near-duplicate
/// phrasings actually *degrades* Siri's matching rather than widening coverage —
/// the system already does flexible matching, so each phrase here is short,
/// distinct and memorable.
///
/// Every phrase includes `\(.applicationName)`. Without it Xcode warns and the
/// runtime index silently drops the phrase, so it would never become a usable
/// voice trigger at all.
struct FontiShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenFontIntent(),
            phrases: [
                "Open a font in \(.applicationName)",
                "Open \(\.$target) in \(.applicationName)",
                "Show me \(\.$target) in \(.applicationName)"
            ],
            shortTitle: "Open Font",
            systemImageName: "textformat"
        )

        AppShortcut(
            intent: ShowSavedFontsIntent(),
            phrases: [
                "Show my saved fonts in \(.applicationName)",
                "Show my favourite fonts in \(.applicationName)",
                "What fonts have I saved in \(.applicationName)"
            ],
            shortTitle: "Saved Fonts",
            systemImageName: "heart"
        )

        AppShortcut(
            intent: FindFontsIntent(),
            phrases: [
                "Find fonts in \(.applicationName)",
                "Search for fonts in \(.applicationName)"
            ],
            shortTitle: "Find Fonts",
            systemImageName: "magnifyingglass"
        )

        AppShortcut(
            intent: FindFontPairingsIntent(),
            phrases: [
                "Find font pairings in \(.applicationName)",
                "What pairs with \(\.$font) in \(.applicationName)"
            ],
            shortTitle: "Font Pairings",
            systemImageName: "rectangle.on.rectangle"
        )

        AppShortcut(
            intent: CompareFontsIntent(),
            phrases: [
                "Compare fonts in \(.applicationName)",
                "Compare \(\.$firstFont) in \(.applicationName)"
            ],
            shortTitle: "Compare Fonts",
            systemImageName: "arrow.left.and.right"
        )
    }
}
