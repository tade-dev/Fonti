import SwiftUI
import WidgetKit

/// The hero: text set in the font being shown.
///
/// This is the widget's whole reason to exist, so it gets the space and the
/// scale. Always `minimumScaleFactor` + `lineLimit` so long names, wide faces
/// and large Dynamic Type sizes shrink instead of clipping.
struct FontSpecimen: View {
    @Environment(\.palette) private var palette

    let font: ResolvedFont
    let text: String
    var size: CGFloat
    var lineLimit: Int = 1
    var alignment: TextAlignment = .leading
    /// Tighten leading on multi-line editorial settings.
    var lineSpacing: CGFloat = 0

    /// When the copy carries its own line breaks, those breaks *are* the
    /// composition — so cap the line count at what was authored. Otherwise a
    /// wide face re-wraps "Typography is / visual language." into four ragged
    /// lines instead of scaling down to honour the two.
    private var effectiveLineLimit: Int {
        let authored = text.components(separatedBy: "\n").count
        return authored > 1 ? authored : lineLimit
    }

    var body: some View {
        Text(text)
            .font(font.font(size: size))
            .foregroundStyle(palette.primary)
            .multilineTextAlignment(alignment)
            .lineSpacing(lineSpacing)
            .lineLimit(effectiveLineLimit)
            .minimumScaleFactor(0.4)
            .widgetAccentable()
            // The glyphs are decorative to a screen reader — the font name
            // carries the meaning, so it's the thing that gets announced.
            .accessibilityHidden(true)
    }
}
