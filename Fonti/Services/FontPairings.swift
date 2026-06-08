import Foundation

/// Curated font pairings — designer-approved combinations for headings + body.
///
/// The mapping is intentionally redundant in both directions (Georgia points to
/// Helvetica Neue *and* Helvetica Neue points to Georgia) — costs a few extra
/// lines and makes the lookup trivial.
enum FontPairings {
    static func pairings(for family: String) -> [String] {
        pairs[family] ?? []
    }

    private static let pairs: [String: [String]] = [
        // Serif + sans classics
        "Georgia":              ["Helvetica Neue", "Avenir Next", "PT Sans"],
        "Helvetica Neue":       ["Georgia", "Hoefler Text", "Baskerville"],
        "Times New Roman":      ["Helvetica Neue", "Verdana", "Arial"],
        "Baskerville":          ["Avenir Next", "Helvetica Neue", "Futura"],
        "Hoefler Text":         ["Helvetica Neue", "Gill Sans", "Avenir"],
        "Palatino":             ["Helvetica Neue", "Avenir Next", "Optima"],
        "Charter":              ["Avenir Next", "PT Sans", "Helvetica Neue"],
        "Cochin":               ["Helvetica Neue", "Avenir", "Gill Sans"],

        // Modern serifs + geometric sans
        "Bodoni 72":            ["Futura", "Helvetica Neue", "Avenir Next"],
        "Bodoni 72 Oldstyle":   ["Futura", "Avenir", "Helvetica Neue"],
        "Bodoni 72 Smallcaps":  ["Avenir Next", "Helvetica Neue"],
        "Didot":                ["Futura", "Avenir Next", "Helvetica Neue"],

        // Geometric sans
        "Futura":               ["Bodoni 72", "Didot", "Georgia", "Baskerville"],
        "Avenir":               ["Georgia", "Baskerville", "Bodoni 72 Oldstyle", "Cochin"],
        "Avenir Next":          ["Georgia", "Baskerville", "Hoefler Text", "PT Serif", "Didot"],
        "Avenir Next Condensed":["Georgia", "Baskerville", "Bodoni 72"],

        // Humanist sans
        "Gill Sans":            ["Hoefler Text", "Georgia", "Bodoni 72 Oldstyle", "Cochin"],
        "Optima":               ["Baskerville", "Bodoni 72", "Georgia", "Palatino"],
        "Verdana":              ["Georgia", "Times New Roman", "PT Serif"],
        "Trebuchet MS":         ["Georgia", "Palatino"],

        // Slab serif
        "American Typewriter":  ["Avenir", "Futura", "Helvetica Neue"],

        // PT family
        "PT Sans":              ["PT Serif", "Georgia", "Charter"],
        "PT Serif":             ["PT Sans", "Helvetica Neue", "Avenir Next", "Verdana"],
        "PT Mono":              ["PT Sans", "Helvetica Neue"],

        // Mono
        "Menlo":                ["Helvetica Neue", "PT Sans"],
        "Courier New":          ["Helvetica Neue", "Avenir Next"],

        // Arial family
        "Arial":                ["Georgia", "Times New Roman"],
        "Arial Rounded MT Bold":["Georgia", "Baskerville", "Palatino"],

        // Display + neutral body
        "Copperplate":          ["Helvetica Neue", "Avenir Next", "Georgia"],
        "Impact":               ["Georgia", "Avenir Next"],

        // Script + clean body
        "Snell Roundhand":      ["Avenir Next", "Helvetica Neue", "Futura"],
        "Zapfino":              ["Helvetica Neue", "Avenir Next"],
        "Bradley Hand":         ["Helvetica Neue", "Avenir Next"],

        // Helvetica baseline
        "Helvetica":            ["Georgia", "Times New Roman", "Hoefler Text"],
    ]
}
