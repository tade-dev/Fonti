import SwiftUI

/// "Pair with — Georgia", with the pairing name set in Georgia.
///
/// Showing the pairing in its own face is the point: a designer can judge the
/// combination at a glance instead of reading two names in the same font.
struct FontPairingPreview: View {
    @Environment(\.palette) private var palette

    let pairing: String
    var size: CGFloat = 20

    private var resolved: ResolvedFont {
        ResolvedFont(
            WidgetFontEntry(
                familyName: pairing,
                displayName: pairing,
                sampleText: pairing
            )
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text("PAIRS WITH")
                .font(.system(size: 9, weight: .medium))
                .tracking(1.3)
                .foregroundStyle(palette.tertiary)

            Text(pairing)
                .font(resolved.font(size: size))
                .foregroundStyle(palette.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Pairs with \(pairing)")
    }
}
