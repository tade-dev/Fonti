import SwiftUI

struct SavedFontCard: View {
    let family: FontFamily
    let isLifted: Bool
    let isDimmed: Bool
    let namespace: Namespace.ID
    /// Drives staggered heights in the Saved masonry.
    var style: Style = .regular

    enum Style: CaseIterable {
        case compact
        case regular
        case tall

        var minHeight: CGFloat {
            switch self {
            case .compact: return 128
            case .regular: return 168
            case .tall: return 220
            }
        }

        var titleSize: CGFloat {
            switch self {
            case .compact: return 18
            case .regular: return 22
            case .tall: return 24
            }
        }

        var sampleSize: CGFloat {
            switch self {
            case .compact: return 28
            case .regular: return 36
            case .tall: return 44
            }
        }

        var sample: String {
            switch self {
            case .compact: return "Aa"
            case .regular: return "Aa Bb"
            case .tall: return "Aa Bb\nCc Dd"
            }
        }

        static func forFamily(_ name: String) -> Style {
            // Stable per-family so the grid doesn’t reshuffle on redraw.
            let hash = name.unicodeScalars.reduce(0) { $0 &+ Int($1.value) }
            switch hash % 3 {
            case 0: return .compact
            case 1: return .regular
            default: return .tall
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(family.displayName)
                .font(.custom(family.id, size: style.titleSize))
                .foregroundStyle(Color.fontiCream)
                .lineLimit(style == .tall ? 2 : 1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(style.sample)
                .font(.custom(family.id, size: style.sampleSize))
                .foregroundStyle(Color.fontiCream.opacity(0.85))
                .lineLimit(style == .tall ? 2 : 1)
                .minimumScaleFactor(0.6)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            Text(family.displayName.uppercased())
                .font(.caption2)
                .tracking(1.2)
                .foregroundStyle(Color.fontiCream.opacity(0.55))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: style.minHeight, alignment: .topLeading)
        .glassEffect(in: .rect(cornerRadius: 22))
        .matchedTransitionSource(id: family.id, in: namespace)
        .cardLift(isLifted: isLifted, isDimmed: isDimmed)
    }
}

#Preview {
    @Previewable @Namespace var ns
    ZStack {
        Color.fontiInk.ignoresSafeArea()
        HStack(alignment: .top, spacing: 14) {
            ForEach(SavedFontCard.Style.allCases, id: \.self) { style in
                SavedFontCard(
                    family: FontFamily(id: "Georgia", displayName: "Georgia"),
                    isLifted: false,
                    isDimmed: false,
                    namespace: ns,
                    style: style
                )
            }
        }
        .padding()
    }
}
