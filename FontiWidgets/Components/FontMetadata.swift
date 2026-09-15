import SwiftUI

/// The font's name, plus an optional caption beneath it.
///
/// Set in the system font on purpose: the specimen above is the typography,
/// this is the label on the museum wall.
struct FontMetadata: View {
    @Environment(\.palette) private var palette

    let font: ResolvedFont
    var size: CGFloat = 13
    var caption: String?
    var alignment: HorizontalAlignment = .leading

    private var textAlignment: TextAlignment {
        alignment == .trailing ? .trailing : .leading
    }

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(font.displayName)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(palette.secondary)
                .multilineTextAlignment(textAlignment)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            if let caption {
                Text(caption)
                    .font(.system(size: max(size - 3, 9)))
                    .foregroundStyle(palette.tertiary)
                    .multilineTextAlignment(textAlignment)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        var parts = [font.displayName]
        if let caption { parts.append(caption) }
        if !font.canRenderTypeface {
            parts.append("Preview unavailable, showing a substitute typeface")
        }
        return parts.joined(separator: ", ")
    }
}

/// A hairline editorial rule.
struct WidgetRule: View {
    @Environment(\.palette) private var palette

    var body: some View {
        Rectangle()
            .fill(palette.rule)
            .frame(height: 0.75)
            .accessibilityHidden(true)
    }
}
