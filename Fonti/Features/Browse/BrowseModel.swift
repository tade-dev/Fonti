import Foundation
import Observation

@Observable
@MainActor
final class BrowseModel {
    var input: String = ""

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
