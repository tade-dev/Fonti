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

/// A font family, addressable from the widget configuration sheet.
struct FontFamilyEntity: AppEntity {
    static let defaultQuery = FontFamilyEntityQuery()
    static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Font")

    /// The family name — stable across launches and devices, which is exactly
    /// what the framework needs since it persists this id into the widget's
    /// saved configuration.
    var id: String

    @Property(title: "Name")
    var name: String

    init(familyName: String) {
        self.id = familyName
        self.name = familyName
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct FontFamilyEntityQuery: EntityStringQuery {
    /// Batched by design — resolve every id in one pass, and simply omit ids
    /// that no longer name an installed family.
    func entities(for identifiers: [String]) async throws -> [FontFamilyEntity] {
        let installed = availableFamilies()
        return identifiers
            .filter { name in installed.contains(where: { $0.caseInsensitiveCompare(name) == .orderedSame }) }
            .map(FontFamilyEntity.init)
    }

    /// `EntityStringQuery` does no filtering for us — the match is ours to do.
    func entities(matching string: String) async throws -> [FontFamilyEntity] {
        let query = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return try await suggestedEntities() }

        return availableFamilies()
            .filter { $0.localizedCaseInsensitiveContains(query) }
            .prefix(50)
            .map(FontFamilyEntity.init)
    }

    /// Kept cheap and ordered by likely intent: the user's own fonts first,
    /// then Fonti's curated list, then everything else installed.
    func suggestedEntities() async throws -> [FontFamilyEntity] {
        let installed = availableFamilies()
        let installedSet = Set(installed)

        let favourites = WidgetSnapshotStore.hasNoUserFonts
            ? []
            : WidgetSnapshotStore.load().map(\.familyName)

        var seen = Set<String>()
        let ordered = (favourites + FontPairings.curatedFamilies + installed)
            .filter { installedSet.contains($0) && seen.insert($0).inserted }

        return ordered.prefix(60).map(FontFamilyEntity.init)
    }

    /// Imported faces only show up in `UIFont.familyNames` once registered, so
    /// pull them into this process first.
    private func availableFamilies() -> [String] {
        SharedFontContainer.registerAll()
        FontAvailability.refresh()
        return UIFont.familyNames
            .filter { !$0.isEmpty && !$0.hasPrefix(".") }
            .sorted()
    }
}

/// Parameter-only by design: `WidgetConfigurationIntent` never runs, so it has
/// no `perform()`. WidgetKit reads these values and hands them to the timeline
/// provider.
struct SpecimenConfigurationIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Specimen"
    static let description = IntentDescription("Choose which typeface Fonti puts on your Home Screen.")

    @Parameter(title: "Show", default: .featured)
    var source: WidgetFontSource

    @Parameter(title: "Font")
    var font: FontFamilyEntity?

    static var parameterSummary: some ParameterSummary {
        When(\.$source, .equalTo, .specific) {
            Summary("Show \(\.$source): \(\.$font)")
        } otherwise: {
            Summary("Show \(\.$source)")
        }
    }
}
