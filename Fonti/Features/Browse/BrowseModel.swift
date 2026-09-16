import Foundation
import Observation

@Observable
@MainActor
final class BrowseModel {
    /// What the specimen cards *say*. Not a filter — typing here changes the
    /// preview text on every card.
    var input: String = ""

    /// Narrows which families are listed.
    ///
    /// Separate from `input` on purpose: the two look similar but do opposite
    /// things, and conflating them would mean a search request silently
    /// rewrote every specimen instead of filtering. Set by a search
    /// destination (Siri, Spotlight, a deep link) rather than typed.
    var filter: String = ""

    var isFiltering: Bool {
        !filter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Apply the active filter, matching name or classification.
    ///
    /// Delegates the actual matching to `FontCatalog` so Browse, Siri and
    /// Spotlight all agree on what "serif" means.
    func filtered(_ families: [FontFamily]) -> [FontFamily] {
        guard isFiltering else { return families }

        let ranked = FontCatalog.search(filter, limit: .max).map(\.familyName)
        let order = Dictionary(
            uniqueKeysWithValues: ranked.enumerated().map { ($0.element.lowercased(), $0.offset) }
        )

        return families
            .compactMap { family in order[family.id.lowercased()].map { (family, $0) } }
            .sorted { $0.1 < $1.1 }
            .map(\.0)
    }

    /// Resolved text for a card. Precedence: typed input → caller-supplied
    /// `fallback` (e.g. user default sample text) → family name.
    func displayText(for family: FontFamily, fallback: String) -> String {
        let trimmedInput = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedInput.isEmpty { return trimmedInput }

        let trimmedFallback = fallback.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedFallback.isEmpty { return trimmedFallback }

        return family.displayName
    }
}
