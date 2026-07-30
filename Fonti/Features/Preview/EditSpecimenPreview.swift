import SwiftUI

/// Calm type sample shown while the composer is open.
/// Word-wrapping `Text` only — no per-glyph flow (that clusters long copy).
struct EditSpecimenPreview: View {
    let text: String
    let familyName: String
    let font: Font
    let color: Color
    let secondary: Color

    var body: some View {
        VStack(spacing: 10) {
            Text(text)
                .font(font)
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.35)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            Text(familyName)
                .font(.caption2.weight(.medium))
                .tracking(0.6)
                .foregroundStyle(secondary)
        }
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(text), \(familyName)")
    }
}
