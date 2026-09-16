import AppIntents

/// "Find something like Helvetica." / "Show me fonts similar to Avenir."
///
/// Fonti owns the similarity entirely — Apple Intelligence only understands
/// that similarity was asked for. The ranking is deterministic and *measured*:
/// classification gates the candidates, then `FontMetrics` compares x-height
/// ratio, advance width and vertical extents read off the fonts themselves.
/// No tags, no model, no authored table to fall out of date.
///
/// Opens the closest match side by side with the original rather than reading
/// names aloud. Fonti is a visual product, and "similar" is a claim you can
/// only really judge by looking at the two together.
struct FindSimilarFontsIntent: AppIntent {
    static let title: LocalizedStringResource = "Find Similar Fonts"
    static let description = IntentDescription(
        "Finds typefaces with proportions close to a font you choose."
    )

    @Parameter(title: "Font")
    var font: FontEntity

    static var supportedModes: IntentModes { .foreground(.immediate) }

    static var parameterSummary: some ParameterSummary {
        Summary("Find fonts similar to \(\.$font)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<[FontEntity]> {
        guard FontCatalog.font(named: font.id) != nil else {
            throw FontiIntentError.fontUnavailable(font.name)
        }

        let matches = FontCatalog.similarFonts(to: font.id)
        guard let closest = matches.first else {
            // Genuinely possible: script and monospace faces have very few
            // peers, and an unclassified face has none it can be compared to.
            throw FontiIntentError.noSimilarFonts(font.name)
        }

        FontiNavigator.shared.go(
            to: .compare(left: font.id, right: closest.familyName)
        )

        return .result(value: matches.map(FontEntity.init))
    }
}
