import UIKit

/// A typeface as Fonti's domain understands it.
///
/// Deliberately small: enough to identify and reason about a face, with no font
/// file data, no rendered previews and no heavy objects — App Intents entities
/// have size limits, and this is what backs them.
struct CatalogFont: Identifiable, Hashable, Sendable {
    /// The OS family name. Stable across launches and devices, and the only
    /// identifier Core Text itself recognises — so it's the id everywhere:
    /// entity, Spotlight, deep link, widget payload.
    var id: String { familyName }

    var familyName: String
    var displayName: String
    var category: FontCategory
    var isSaved: Bool
    var isImported: Bool
    /// Whether the real typeface can actually be rendered in this process.
    var canRender: Bool
}

/// The single source of truth for "what fonts does Fonti know about".
///
/// This is the domain layer from the architecture boundary: it knows nothing
/// about Siri, App Intents or SwiftUI. The intent layer, the widget and the app
/// all read through it, so a font means the same thing on every surface.
enum FontCatalog {
    /// Every installed family, sorted, imports included.
    ///
    /// Imported faces are registered first so they appear at all — Core Text
    /// registration is per-process, and an intent runs in a fresh one.
    static func allFonts() -> [CatalogFont] {
        SharedFontContainer.registerAll()
        FontAvailability.refresh()

        let saved = Set(SavedFontsMirror.load().map { $0.lowercased() })
        let imported = Set(importedFamilyNames().map { $0.lowercased() })

        return UIFont.familyNames
            .filter { !$0.isEmpty && !$0.hasPrefix(".") }
            .sorted { $0.lowercased() < $1.lowercased() }
            .map { family in
                CatalogFont(
                    familyName: family,
                    displayName: family,
                    category: FontCategory.category(for: family),
                    isSaved: saved.contains(family.lowercased()),
                    isImported: imported.contains(family.lowercased()),
                    canRender: FontAvailability.isAvailable(family)
                )
            }
    }

    /// Exact family lookup, case-insensitive.
    static func font(named familyName: String) -> CatalogFont? {
        let name = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }
        return allFonts().first { $0.familyName.caseInsensitiveCompare(name) == .orderedSame }
    }

    static func fonts(withIDs ids: [String]) -> [CatalogFont] {
        guard !ids.isEmpty else { return [] }
        let wanted = Set(ids.map { $0.lowercased() })
        return allFonts().filter { wanted.contains($0.familyName.lowercased()) }
    }

    /// Match on family name *or* classification.
    ///
    /// Fonti owns the search; Apple Intelligence only decides *that* the user
    /// wanted to search. Matching the category matters because the
    /// `.system.search` schema hands over a bare string — "serif" has to find
    /// serif faces, not just families with "serif" in their name.
    ///
    /// Name matches rank above category matches, and prefix above interior, so
    /// "helv" finds Helvetica first and "mono" doesn't bury Monaco under every
    /// monospace face.
    static func search(_ query: String, limit: Int = 50) -> [CatalogFont] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !needle.isEmpty else { return Array(allFonts().prefix(limit)) }

        func rank(_ font: CatalogFont) -> Int? {
            let name = font.familyName.lowercased()
            if name.hasPrefix(needle) { return 0 }
            if name.contains(needle) { return 1 }
            if font.category.matches(searchTerm: needle) { return 2 }
            return nil
        }

        // Broken into steps with explicit types on purpose: as one chained
        // expression the type checker gives up ("unable to type-check in
        // reasonable time").
        var ranked: [(font: CatalogFont, rank: Int)] = []
        for font in allFonts() {
            if let value = rank(font) {
                ranked.append((font, value))
            }
        }

        ranked.sort { lhs, rhs in
            if lhs.rank != rhs.rank { return lhs.rank < rhs.rank }
            return lhs.font.familyName.lowercased() < rhs.font.familyName.lowercased()
        }

        let sorted: [CatalogFont] = ranked.map(\.font)
        return Array(sorted.prefix(limit))
    }

    /// Every font in one classification.
    static func fonts(in category: FontCategory, limit: Int = 50) -> [CatalogFont] {
        Array(allFonts().filter { $0.category == category }.prefix(limit))
    }


    /// The user's saved fonts, in the order they saved them.
    static func savedFonts() -> [CatalogFont] {
        let order = SavedFontsMirror.load()
        let byName = Dictionary(
            allFonts().map { ($0.familyName.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return order.compactMap { byName[$0.lowercased()] }
    }

    /// Faces that look like this one, closest first.
    ///
    /// Deterministic and measured: classification gates the candidates, then
    /// `FontMetrics` ranks what's left by measured proportions. No tags, no
    /// model — Apple Intelligence understands the question, Fonti answers it.
    ///
    /// Pairings are deliberately *not* reused here. A pairing is chosen for
    /// contrast — Georgia pairs with Helvetica Neue precisely because they
    /// differ — so it's close to the opposite of similarity.
    static func similarFonts(to familyName: String, limit: Int = 10) -> [CatalogFont] {
        guard
            let subject = font(named: familyName),
            let subjectMetrics = FontMetricsProvider.metrics(for: subject.familyName)
        else { return [] }

        var scored: [(font: CatalogFont, distance: Double)] = []

        for candidate in allFonts() {
            guard candidate.familyName.caseInsensitiveCompare(subject.familyName) != .orderedSame,
                  candidate.category.isComparable(with: subject.category),
                  FontMetricsProvider.isLatinTextFace(candidate.familyName),
                  let metrics = FontMetricsProvider.metrics(for: candidate.familyName)
            else { continue }

            scored.append((candidate, metrics.distance(to: subjectMetrics)))
        }

        scored.sort { lhs, rhs in
            if lhs.distance != rhs.distance { return lhs.distance < rhs.distance }
            return lhs.font.familyName.lowercased() < rhs.font.familyName.lowercased()
        }

        let ordered: [CatalogFont] = scored.map(\.font)
        return Array(ordered.prefix(limit))
    }

    /// Curated pairings for a family, limited to faces that are installed.
    static func pairings(for familyName: String) -> [CatalogFont] {
        let names = FontPairings.pairings(for: familyName)
        guard !names.isEmpty else { return [] }
        let byName = Dictionary(
            allFonts().map { ($0.familyName.lowercased(), $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return names.compactMap { byName[$0.lowercased()] }
    }

    /// Imported family names, read from the shared font folder's filenames.
    ///
    /// The `ImportedFont` records live in the app's SwiftData store, which an
    /// intent process can't reach — but the files themselves are in the App
    /// Group, and a registered file's family name is what we actually need.
    private static func importedFamilyNames() -> [String] {
        guard
            let directory = SharedFontContainer.fontsDirectory,
            let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path)
        else { return [] }

        return names
            .filter { !$0.hasPrefix(".") }
            .compactMap { SharedFontContainer.familyName(forFileNamed: $0) }
    }
}
