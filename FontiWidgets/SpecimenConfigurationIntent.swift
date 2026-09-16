import AppIntents
import UIKit

/// What the widget shows. Deliberately three options, not eight.
///
/// Raw values are a persisted contract — append only, never rename or reorder.
enum WidgetFontSource: String, AppEnum {
    case featured = "featured"
    case favourite = "favourite"
    case specific = "specific"

    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Source")

    static let caseDisplayRepresentations: [WidgetFontSource: DisplayRepresentation] = [
        .featured: DisplayRepresentation(
            title: "Font of the Day",
            subtitle: "A curated face, changing each morning"
        ),
        .favourite: DisplayRepresentation(
            title: "Latest Favourite",
            subtitle: "The typeface you saved most recently"
        ),
        .specific: DisplayRepresentation(
            title: "A Specific Font",
            subtitle: "Pick one and keep it there"
        )
    ]
}

/// Parameter-only by design: `WidgetConfigurationIntent` never runs, so it has
/// no `perform()`. WidgetKit reads these values and hands them to the timeline
/// provider.
struct SpecimenConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Specimen"
    static let description = IntentDescription("Choose which typeface Fonti puts on your Home Screen.")

    @Parameter(title: "Show", default: .featured)
    var source: WidgetFontSource

    /// The shared `FontEntity` rather than a widget-local duplicate — the same
    /// type Siri, Spotlight and Shortcuts resolve, so a font means one thing
    /// across every surface and the ids stay interchangeable.
    @Parameter(title: "Font")
    var font: FontEntity?

    static var parameterSummary: some ParameterSummary {
        When(\.$source, .equalTo, .specific) {
            Summary("Show \(\.$source): \(\.$font)")
        } otherwise: {
            Summary("Show \(\.$source)")
        }
    }
}
