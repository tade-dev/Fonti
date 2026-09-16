import UIKit

/// How a typeface is classified.
///
/// Fonti stores no classification data of its own — this is derived from Core
/// Text's own family-class bits (`UIFontDescriptor.SymbolicTraits`), so it's OS
/// metadata rather than a hand-authored table that would drift from reality.
///
/// Measured against the installed families on iOS 27: 74 of 87 classify, and
/// the ones that don't are almost entirely non-Latin (Arabic, Hebrew, Tibetan,
/// Malayalam, Sinhala, Urdu) plus symbol fonts — the set a Latin-typography app
/// cares least about labelling. Those land in `.unclassified` rather than being
/// guessed at.
///
/// Known imprecision: the class bits are reliable for the broad buckets (sans,
/// serif, script, mono) but occasionally wrong for display faces — Papyrus
/// reports sans-serif, and Copperplate reports slab. Treat this as a good
/// default rather than an authority, and override per-family if a curated
/// classification is ever authored.
enum FontCategory: String, CaseIterable, Sendable {
    case serif
    case sansSerif
    case slabSerif
    case monospace
    case script
    case decorative
    case unclassified

    /// Present the broad strokes a designer would actually say out loud.
    var displayName: String {
        switch self {
        case .serif: return "Serif"
        case .sansSerif: return "Sans Serif"
        case .slabSerif: return "Slab Serif"
        case .monospace: return "Monospace"
        case .script: return "Script"
        case .decorative: return "Decorative"
        case .unclassified: return "Unclassified"
        }
    }

    /// The words someone might actually say for this category.
    ///
    /// An explicit table rather than substring matching on `displayName`:
    /// "sans serif" normalises to "sansserif", which *contains* "serif", so a
    /// substring test answers a request for serif faces with Helvetica and
    /// Arial. Matching whole terms keeps the categories genuinely distinct.
    var searchTerms: Set<String> {
        switch self {
        case .serif:
            return ["serif", "serifs", "roman", "oldstyle", "transitional", "didone", "modern"]
        case .sansSerif:
            return ["sans", "sansserif", "grotesque", "grotesk", "gothic", "neogrotesque"]
        case .slabSerif:
            return ["slab", "slabserif", "egyptian", "typewriter"]
        case .monospace:
            return ["mono", "monospace", "monospaced", "fixedwidth", "code"]
        case .script:
            return ["script", "cursive", "handwriting", "handwritten", "calligraphic"]
        case .decorative:
            return ["decorative", "display", "ornamental", "ornament", "novelty"]
        case .unclassified:
            return []
        }
    }

    /// Whether two classifications are close enough to compare for similarity.
    ///
    /// Serif and slab serif are neighbours — a slab is a serif with squared-off
    /// brackets, so American Typewriter is a reasonable answer to "something
    /// like Georgia". Everything else stays in its own lane: script, monospace
    /// and decorative faces are defined by what makes them *unlike* a text
    /// face, so "something like Zapfino" must never return Helvetica.
    ///
    /// `.unclassified` compares with nothing. Those are mostly non-Latin
    /// faces, and ranking them by Latin proportions would be meaningless.
    func isComparable(with other: FontCategory) -> Bool {
        guard self != .unclassified, other != .unclassified else { return false }
        if self == other { return true }

        let serifFamily: Set<FontCategory> = [.serif, .slabSerif]
        return serifFamily.contains(self) && serifFamily.contains(other)
    }

    /// Does a spoken term name this category?
    ///
    /// Whitespace and hyphens are stripped so "sans serif", "sans-serif" and
    /// "sansserif" all land in the same place.
    func matches(searchTerm term: String) -> Bool {
        let needle = term.lowercased().filter { !$0.isWhitespace && $0 != "-" }
        guard !needle.isEmpty else { return false }
        return searchTerms.contains(needle)
    }

    /// Classify a family by asking Core Text what it is.
    static func category(for familyName: String) -> FontCategory {
        guard let traits = symbolicTraits(for: familyName) else { return .unclassified }

        // Monospace is a trait rather than a class, and it has to outrank the
        // class bits: Menlo reports sans-serif and Courier New reports slab,
        // neither of which is what anyone means by "a mono font".
        if traits.contains(.traitMonoSpace) { return .monospace }

        switch traits.rawValue & UIFontDescriptor.SymbolicTraits.classMask.rawValue {
        case UIFontDescriptor.SymbolicTraits.classOldStyleSerifs.rawValue,
             UIFontDescriptor.SymbolicTraits.classTransitionalSerifs.rawValue,
             UIFontDescriptor.SymbolicTraits.classModernSerifs.rawValue,
             UIFontDescriptor.SymbolicTraits.classClarendonSerifs.rawValue,
             UIFontDescriptor.SymbolicTraits.classFreeformSerifs.rawValue:
            return .serif
        case UIFontDescriptor.SymbolicTraits.classSlabSerifs.rawValue:
            return .slabSerif
        case UIFontDescriptor.SymbolicTraits.classSansSerif.rawValue:
            return .sansSerif
        case UIFontDescriptor.SymbolicTraits.classScripts.rawValue:
            return .script
        case UIFontDescriptor.SymbolicTraits.classOrnamentals.rawValue:
            return .decorative
        default:
            return .unclassified
        }
    }

    /// Read the traits off the family's own descriptor.
    ///
    /// Deliberately not `UIFont(name:)` — that takes a *font* name, and a family
    /// name like "Bodoni 72 Oldstyle" doesn't resolve through it.
    private static func symbolicTraits(for familyName: String) -> UIFontDescriptor.SymbolicTraits? {
        let name = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return nil }

        let descriptor = UIFontDescriptor(fontAttributes: [.family: name])
        let font = UIFont(descriptor: descriptor, size: 16)
        // A family the process can't see resolves to the system font, whose
        // traits would be a lie about the requested family.
        guard font.familyName == name else { return nil }
        return font.fontDescriptor.symbolicTraits
    }
}
