import AppIntents

/// "Open Helvetica Neue in Fonti."
///
/// Adopts the `.system.open` schema — the published contract for opening an
/// item in an app — which is what lets Apple Intelligence invoke this without
/// Fonti having to guess at phrasings. The macro confers `OpenIntent`, whose
/// `target` is the thing that opens.
///
/// Deliberately thin: it resolves a destination and hands it to the navigator.
/// It knows nothing about tabs or navigation stacks.
@AppIntent(schema: .system.open)
struct OpenFontIntent {
    @Parameter(title: "Font")
    var target: FontEntity

    /// The app has to come forward — the whole point is to land on the
    /// specimen. `.immediate` switches before `perform()` runs, so navigation
    /// state is set while the UI is already on screen.
    static var supportedModes: IntentModes { .foreground(.immediate) }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard FontCatalog.font(named: target.id) != nil else {
            throw FontiIntentError.fontUnavailable(target.name)
        }
        FontiNavigator.shared.go(to: .font(familyName: target.id))
        return .result()
    }
}

/// "Show my saved fonts in Fonti." / "What fonts have I saved?"
///
/// Saved and favourite are one concept in Fonti — a single hearted list — so
/// both phrasings land here rather than pretending there are two tiers.
struct ShowSavedFontsIntent: AppIntent {
    static let title: LocalizedStringResource = "Show Saved Fonts"
    static let description = IntentDescription("Opens the typefaces you've saved in Fonti.")

    static var supportedModes: IntentModes { .foreground(.immediate) }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[FontEntity]> {
        FontiNavigator.shared.go(to: .saved)
        let saved = FontCatalog.savedFonts().map(FontEntity.init)
        // Returning the entities as well as navigating means Siri can read the
        // list back without the user having to look at the screen.
        return .result(value: saved)
    }
}
