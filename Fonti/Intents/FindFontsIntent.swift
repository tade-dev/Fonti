import AppIntents

/// "Find serif fonts." / "Show me monospace fonts in Fonti."
///
/// Adopts `.system.search` — the published contract for navigating to search
/// results — so Apple Intelligence handles the language and Fonti handles the
/// search. There is no LLM here: `FontCatalog` does a deterministic match on
/// family name and classification.
///
/// The schema fixes the shape to a single `criteria` string. `category` and
/// `savedOnly` are optional extras, which per Apple's guidance means Siri and
/// Apple Intelligence never fill them — they exist so the Shortcuts editor can
/// offer a real category picker instead of making people type "sans serif".
@AppIntent(schema: .system.search)
struct FindFontsIntent {
    var criteria: StringSearchCriteria

    @Parameter(title: "Category")
    var category: FontCategory?

    @Parameter(title: "Saved Only", default: false)
    var savedOnly: Bool?

    /// Bring the app forward: the schema's job is to *show* results, and the
    /// value of a font search is seeing the typefaces.
    static var supportedModes: IntentModes { .foreground(.immediate) }

    static var parameterSummary: some ParameterSummary {
        Summary("Find \(\.$category) fonts matching \(\.$criteria)") {
            \.$savedOnly
        }
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[FontEntity]> {
        let term = criteria.term.trimmingCharacters(in: .whitespacesAndNewlines)

        var results = term.isEmpty
            ? FontCatalog.allFonts()
            : FontCatalog.search(term)

        // Shortcuts-only refinements, applied after the text match so a
        // category picker narrows the same ranked list rather than a new one.
        if let category {
            results = results.filter { $0.category == category }
        }
        if savedOnly == true {
            results = results.filter(\.isSaved)
        }

        // Navigate even when empty — an empty filtered list with a chip saying
        // what was searched is more honest than silently showing everything.
        FontiNavigator.shared.go(to: .search(query: term.isEmpty ? (category?.displayName ?? "") : term))

        return .result(value: results.map(FontEntity.init))
    }
}

/// "What pairs well with Garamond?" / "Show me font pairings for Avenir."
///
/// The pairings are Fonti's own curated table — Apple Intelligence understands
/// the question, it does not decide which typefaces go together. Only pairings
/// whose face is actually installed are returned.
struct FindFontPairingsIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Font Pairings"
    static let description = IntentDescription(
        "Shows the typefaces Fonti recommends alongside a font."
    )

    @Parameter(title: "Font")
    var font: FontEntity

    static var supportedModes: IntentModes { .foreground(.immediate) }

    static var parameterSummary: some ParameterSummary {
        Summary("Find pairings for \(\.$font)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[FontEntity]> {
        guard FontCatalog.font(named: font.id) != nil else {
            throw FontiIntentError.fontUnavailable(font.name)
        }

        let pairings = FontCatalog.pairings(for: font.id)
        guard !pairings.isEmpty else {
            throw FontiIntentError.noPairings(font.name)
        }

        // Opens the font's specimen, where the pairings strip already lives —
        // reusing the existing surface rather than inventing a results screen.
        FontiNavigator.shared.go(to: .font(familyName: font.id))

        return .result(value: pairings.map(FontEntity.init))
    }
}

/// "Compare Helvetica and Avenir in Fonti."
///
/// Fonti is a visual product, so this opens the real side-by-side comparison
/// rather than describing the difference in words.
struct CompareFontsIntent: AppIntent {
    static let title: LocalizedStringResource = "Compare Fonts"
    static let description = IntentDescription(
        "Opens two typefaces side by side in Fonti."
    )

    @Parameter(title: "First Font")
    var firstFont: FontEntity

    @Parameter(title: "Second Font")
    var secondFont: FontEntity

    static var supportedModes: IntentModes { .foreground(.immediate) }

    static var parameterSummary: some ParameterSummary {
        Summary("Compare \(\.$firstFont) with \(\.$secondFont)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        // Report the *specific* missing face rather than a generic failure, so
        // the person knows which name to correct.
        guard FontCatalog.font(named: firstFont.id) != nil else {
            throw FontiIntentError.fontUnavailable(firstFont.name)
        }
        guard FontCatalog.font(named: secondFont.id) != nil else {
            throw FontiIntentError.fontUnavailable(secondFont.name)
        }
        guard firstFont.id.caseInsensitiveCompare(secondFont.id) != .orderedSame else {
            throw FontiIntentError.sameFontTwice(firstFont.name)
        }

        FontiNavigator.shared.go(to: .compare(left: firstFont.id, right: secondFont.id))
        return .result()
    }
}
