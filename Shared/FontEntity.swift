import AppIntents
import UIKit

/// A typeface, as the system understands it.
///
/// This is Fonti's public face to Siri, Apple Intelligence, Spotlight and
/// Shortcuts. Kept lightweight on purpose — entities have size limits, and
/// nothing here is font file data, preview imagery, or internal model state.
///
/// No schema is attached: the published schema domains cover audio, calendar,
/// mail, photos and friends, but there is no typography or design domain, and
/// forcing a face into an unrelated one degrades Siri rather than helping it.
/// The *intents* adopt `.system.open` / `.system.search`, which do fit.
struct FontEntity: AppEntity {
    static let defaultQuery = FontEntityQuery()

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Font", numericFormat: "\(placeholder: .int) fonts")
    }

    /// The OS family name — stable across launches and devices, and the same
    /// identifier used by the deep link, the widget payload and Spotlight.
    /// Not the display name: an id has to survive localisation and renaming.
    var id: String

    @Property(title: "Name")
    var name: String

    @Property(title: "Category")
    var category: FontCategory

    @Property(title: "Saved")
    var isSaved: Bool

    @Property(title: "Imported")
    var isImported: Bool

    init(_ font: CatalogFont) {
        self.id = font.familyName
        self.name = font.displayName
        self.category = font.category
        self.isSaved = font.isSaved
        self.isImported = font.isImported
    }

    var displayRepresentation: DisplayRepresentation {
        var subtitleParts: [String] = []
        if category != .unclassified { subtitleParts.append(category.displayName) }
        if isImported { subtitleParts.append("Imported") }
        if isSaved { subtitleParts.append("Saved") }

        return DisplayRepresentation(
            title: "\(name)",
            subtitle: subtitleParts.isEmpty ? nil : LocalizedStringResource(stringLiteral: subtitleParts.joined(separator: " · "))
        )
    }
}

/// How the system finds a font.
///
/// `EntityStringQuery` is what lets Siri resolve a spoken name — "Helvetica",
/// "Avenir" — to an entity. The framework does no filtering of its own, so the
/// matching here is Fonti's job, and it delegates to `FontCatalog` rather than
/// reimplementing search.
/// The `@MainActor` annotations are load-bearing: the target builds with
/// default main-actor isolation, so `FontCatalog` is main-actor bound. An async
/// protocol requirement can be witnessed by a `@MainActor` method, which hops
/// properly — without it these were cross-actor calls that Swift 6 rejects
/// outright.
struct FontEntityQuery: EntityStringQuery {
    /// Batched by design: resolve every id in one pass, and simply omit ids
    /// that no longer name an installed family — a font can disappear when an
    /// import is deleted, and a stale saved shortcut shouldn't throw.
    @MainActor
    func entities(for identifiers: [String]) async throws -> [FontEntity] {
        FontCatalog.fonts(withIDs: identifiers).map(FontEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [FontEntity] {
        FontCatalog.search(string).map(FontEntity.init)
    }

    /// What the picker offers with nothing typed: the user's own fonts first,
    /// then Fonti's curated list. Kept bounded — the system calls this
    /// opportunistically.
    @MainActor
    func suggestedEntities() async throws -> [FontEntity] {
        let saved = FontCatalog.savedFonts()
        guard saved.isEmpty else { return saved.prefix(20).map(FontEntity.init) }

        let curated = Set(FontPairings.curatedFamilies.map { $0.lowercased() })
        return FontCatalog.allFonts()
            .filter { curated.contains($0.familyName.lowercased()) }
            .prefix(20)
            .map(FontEntity.init)
    }
}

/// Exposed so Shortcuts can filter by classification, and so a phrase can
/// expand across the cases.
/// `nonisolated` because the target builds with `SWIFT_DEFAULT_ACTOR_ISOLATION
/// = MainActor`, which would otherwise make this conformance main-actor
/// isolated — and `AppEnum` requires a `Sendable`, non-isolated conformance.
nonisolated extension FontCategory: AppEnum {
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: "Font Category")
    }

    // Raw values are a persisted contract — append only, never rename.
    static var caseDisplayRepresentations: [FontCategory: DisplayRepresentation] {
        [
            .serif: "Serif",
            .sansSerif: "Sans Serif",
            .slabSerif: "Slab Serif",
            .monospace: "Monospace",
            .script: "Script",
            .decorative: "Decorative",
            .unclassified: "Unclassified"
        ]
    }
}
