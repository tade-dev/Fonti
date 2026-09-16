import AppIntents
import CoreSpotlight
import Foundation

/// Pushes Fonti's typefaces into Spotlight.
///
/// The point is that searching "Bodoni" from the Home Screen finds the
/// typeface, not just Fonti's App Shortcuts — the font becomes system content
/// rather than something only reachable inside the app.
///
/// Only fonts are indexed. There are no user collections to index, pairings are
/// a static table rather than user content, and imported font *files* are
/// deliberately never exposed — a Spotlight entry carries the family name and
/// classification, nothing more.
enum FontSpotlightIndexer {
    /// Fingerprint of what's currently indexed, so a relaunch with an
    /// unchanged font set doesn't re-push ~87 items for nothing.
    private static let fingerprintKey = "fonti.spotlight.fingerprint"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: WidgetSnapshotStore.appGroupID) ?? .standard
    }

    /// Index every installed family, skipping the work when nothing changed.
    ///
    /// Call at launch and after an import. Importing or deleting a font
    /// changes the fingerprint, which is what makes the refresh happen.
    @MainActor
    static func indexAllIfNeeded() async {
        let fonts = FontCatalog.allFonts()
        let fingerprint = fingerprint(for: fonts)

        guard defaults.string(forKey: fingerprintKey) != fingerprint else { return }

        do {
            try await CSSearchableIndex.default().indexAppEntities(fonts.map(FontEntity.init))
            defaults.set(fingerprint, forKey: fingerprintKey)
        } catch {
            // A failed index is not worth surfacing: Spotlight is an
            // enhancement, and leaving the fingerprint unset means the next
            // launch simply tries again.
        }
    }

    /// Unconditional reindex, for when the system asks via
    /// `IndexedEntityQuery.reindexAllEntities`.
    @MainActor
    static func indexAll() async throws {
        let fonts = FontCatalog.allFonts()
        try await CSSearchableIndex.default().indexAppEntities(fonts.map(FontEntity.init))
        defaults.set(fingerprint(for: fonts), forKey: fingerprintKey)
    }

    /// Cheap stand-in for "has the set of installed fonts changed": the count
    /// plus a hash of the names. Catches imports, deletions and renames
    /// without storing the whole list.
    private static func fingerprint(for fonts: [CatalogFont]) -> String {
        var hasher = Hasher()
        for font in fonts {
            hasher.combine(font.familyName)
            hasher.combine(font.isSaved)
        }
        return "\(fonts.count)-\(hasher.finalize())"
    }
}
