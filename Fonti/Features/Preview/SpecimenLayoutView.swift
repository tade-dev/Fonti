import SwiftUI

/// Renders specimen text according to the active layout template.
struct SpecimenLayoutView: View {
    let template: SpecimenTemplate
    let text: String
    let familyName: String
    let pointSize: CGFloat
    let font: Font
    let color: Color
    let secondary: Color
    var animates: Bool = true
    var compact: Bool = false
    var tracking: CGFloat = 0
    var leading: CGFloat = 4

    var body: some View {
        Group {
            if compact {
                AnimatedSpecimenText(
                    text: text,
                    font: font,
                    color: color,
                    animates: animates,
                    tracking: tracking,
                    lineSpacing: leading
                )
            } else {
                switch template {
                case .wordmark:
                    AnimatedSpecimenText(
                        text: text,
                        font: font,
                        color: color,
                        animates: animates,
                        tracking: tracking,
                        lineSpacing: leading
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .headline:
                    Text(text)
                        .font(font)
                        .tracking(tracking)
                        .lineSpacing(leading)
                        .foregroundStyle(color)
                        .multilineTextAlignment(.center)
                        .lineLimit(template.lineLimit)
                        .minimumScaleFactor(0.45)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                case .body:
                    Text(text)
                        .font(font)
                        .tracking(tracking)
                        .lineSpacing(leading)
                        .foregroundStyle(color)
                        .multilineTextAlignment(.leading)
                        .lineLimit(template.lineLimit)
                        .minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)

                case .poster:
                    poster
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: template.textAlignment)
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.86), value: tracking)
        .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.86), value: leading)
    }

    private var poster: some View {
        VStack(spacing: 14) {
            Spacer(minLength: 0)

            Text(posterTitle)
                .font(font)
                .tracking(tracking)
                .foregroundStyle(color)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.4)

            Text(posterSubtitle)
                .font(.system(size: max(pointSize * 0.28, 11), weight: .medium))
                .tracking(1.4)
                .textCase(.uppercase)
                .foregroundStyle(secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.7)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var posterTitle: String {
        if let idx = text.firstIndex(of: "\n") {
            return String(text[..<idx])
        }
        return text
    }

    private var posterSubtitle: String {
        if let idx = text.firstIndex(of: "\n") {
            let rest = text[text.index(after: idx)...]
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !rest.isEmpty { return rest }
        }
        return familyName
    }
}
