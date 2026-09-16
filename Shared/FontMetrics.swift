import UIKit
import CoreText

/// Measured proportions of a typeface, used to judge similarity.
///
/// Everything here is read off the font itself rather than tagged by hand, so
/// it can't drift from reality and needs no authoring. All values are ratios
/// against point size, making them comparable across families.
///
/// Chosen by measuring what actually separates faces on iOS. Two traits that
/// look promising were dropped because they carry no signal: `kCTFontWeight
/// Trait` reads 0.0 for nearly every family — we always resolve the regular
/// face, so it's constant — and `kCTFontWidthTrait` only fires on families
/// explicitly named condensed. The advance-width ratio below captures width
/// far better, since it measures the letterforms instead of asking for a label.
struct FontMetrics: Hashable, Sendable {
    /// x-height over cap-height. The most perceptually salient difference
    /// between two faces of the same classification: Helvetica reads at 0.73,
    /// Futura at 0.63, Baskerville at 0.60.
    var xHeightRatio: Double
    /// Advance width of a reference string over point size — catches
    /// condensed, expanded and monospaced without relying on a trait bit.
    var widthRatio: Double
    var ascentRatio: Double
    var descentRatio: Double

    /// Observed spread of each value across the installed families, used to
    /// normalise deltas so one axis can't dominate purely because its raw
    /// numbers are larger.
    private static let spread = FontMetrics(
        xHeightRatio: 0.32,
        widthRatio: 2.9,
        ascentRatio: 0.15,
        descentRatio: 0.16
    )

    /// How much each axis counts. x-height and width dominate because they're
    /// what someone actually notices; vertical extents are secondary.
    private static let weight = FontMetrics(
        xHeightRatio: 0.45,
        widthRatio: 0.30,
        ascentRatio: 0.125,
        descentRatio: 0.125
    )

    /// Weighted distance to another face. 0 is identical; larger is less alike.
    func distance(to other: FontMetrics) -> Double {
        func term(
            _ lhs: Double,
            _ rhs: Double,
            _ spread: Double,
            _ weight: Double
        ) -> Double {
            let delta = abs(lhs - rhs) / spread
            return weight * delta * delta
        }

        let total =
            term(xHeightRatio, other.xHeightRatio, Self.spread.xHeightRatio, Self.weight.xHeightRatio)
            + term(widthRatio, other.widthRatio, Self.spread.widthRatio, Self.weight.widthRatio)
            + term(ascentRatio, other.ascentRatio, Self.spread.ascentRatio, Self.weight.ascentRatio)
            + term(descentRatio, other.descentRatio, Self.spread.descentRatio, Self.weight.descentRatio)

        return total.squareRoot()
    }
}

/// Measures and caches per-family metrics.
enum FontMetricsProvider {
    /// Measuring means laying out a string, which is far too expensive to
    /// repeat for 87 families on every similarity query.
    private static var cache: [String: FontMetrics?] = [:]

    /// The string measured for width. A pangram-ish mix of ascenders,
    /// descenders and round forms, so the result reflects real text rather
    /// than one unusual glyph.
    private static let referenceString = "Hamburgefonstiv"

    /// Measured at 100pt so the returned ratios read directly as percentages
    /// and rounding noise stays well below the differences that matter.
    private static let referenceSize: CGFloat = 100

    static func metrics(for familyName: String) -> FontMetrics? {
        if let cached = cache[familyName] { return cached }

        let measured = measure(familyName)
        cache[familyName] = measured
        return measured
    }

    static func clearCache() {
        cache.removeAll()
        latinTextFaceCache.removeAll()
    }

    private static var latinTextFaceCache: [String: Bool] = [:]

    /// Whether this face is designed for Latin text, rather than being a face
    /// for another writing system that happens to include Latin glyphs.
    ///
    /// Without this, similarity results fill up with faces whose Latin is an
    /// afterthought: "something like Futura" returned PingFang HK, MO, SC and
    /// TC — four near-identical CJK faces — and pushed Avenir and Gill Sans
    /// out of the results entirely.
    ///
    /// Tested by character coverage, and deliberately *not* on Arabic or
    /// Hebrew: Arial and Times New Roman both ship those, and excluding them
    /// would drop the single best answer for "like Helvetica". Faces that are
    /// primarily Arabic or Hebrew — Geeza Pro, Mishafi, Al Nile — carry no
    /// Core Text classification anyway, so the category gate already excludes
    /// them.
    static func isLatinTextFace(_ familyName: String) -> Bool {
        if let cached = latinTextFaceCache[familyName] { return cached }

        // Writing systems a Latin text face never bundles.
        let foreignScriptMarkers: [UInt32] = [
            0x4E00,  // CJK ideographs
            0xAC00,  // Hangul
            0x0900,  // Devanagari
            0x0E01,  // Thai
            0x0E81,  // Lao
            0x0B85,  // Tamil
            0x0C05,  // Telugu
            0x0C85,  // Kannada
            0x0D05,  // Malayalam
            0x0D85,  // Sinhala
            0x1000,  // Myanmar
            0x1200,  // Ethiopic
            0x0F00,  // Tibetan
            0x13A0   // Cherokee
        ]

        let descriptor = UIFontDescriptor(fontAttributes: [.family: familyName])
        let font = UIFont(descriptor: descriptor, size: 16)
        guard font.familyName == familyName else {
            latinTextFaceCache[familyName] = false
            return false
        }

        let coverage = CTFontCopyCharacterSet(font as CTFont) as CharacterSet
        let isLatin = !foreignScriptMarkers.contains { marker in
            guard let scalar = UnicodeScalar(marker) else { return false }
            return coverage.contains(scalar)
        }

        latinTextFaceCache[familyName] = isLatin
        return isLatin
    }

    private static func measure(_ familyName: String) -> FontMetrics? {
        let descriptor = UIFontDescriptor(fontAttributes: [.family: familyName])
        let font = UIFont(descriptor: descriptor, size: referenceSize)

        // A family this process can't see silently resolves to the system
        // font, whose measurements would be a lie about the requested family.
        guard font.familyName == familyName, font.capHeight > 0 else { return nil }

        let advance = (referenceString as NSString)
            .size(withAttributes: [.font: font])
            .width

        return FontMetrics(
            xHeightRatio: Double(font.xHeight / font.capHeight),
            widthRatio: Double(advance / referenceSize),
            ascentRatio: Double(font.ascender / referenceSize),
            descentRatio: Double(abs(font.descender) / referenceSize)
        )
    }
}
