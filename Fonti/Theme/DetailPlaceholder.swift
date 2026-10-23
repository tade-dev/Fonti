import SwiftUI

/// What the split view's detail column shows before anything is selected.
///
/// On iPhone Duo's inner display that column is 551pt wide, and a single line
/// of grey text left almost all of it empty. It now shows the font of the day —
/// already curated and day-seeded by `FeaturedFont`, so there is nothing new to
/// choose — set at size over the same drifting glyph backdrop as the splash.
/// Tapping it opens that face, so the space answers "what do I do here" and
/// gives you something to do in one move.
///
/// `featured` is optional because not every list can honour the tap: Saved can
/// only select from what has been hearted, and the font of the day usually
/// hasn't been. There it falls back to backdrop and prompt alone.
struct DetailPlaceholder: View {
    let hint: String
    var featured: FontFamily?
    var onPick: ((FontFamily) -> Void)?

    var body: some View {
        ZStack {
            Color.fontiInk.ignoresSafeArea()

            SplashBackdrop()
                .allowsHitTesting(false)
                .opacity(0.5)

            if let featured {
                VStack(spacing: 18) {
                    Text("Font of the day")
                        .font(.caption)
                        .textCase(.uppercase)
                        .tracking(1.4)
                        .foregroundStyle(Color.fontiCream.opacity(0.35))

                    Text(featured.displayName)
                        .font(.custom(featured.id, size: 56))
                        .foregroundStyle(Color.fontiCream)
                        .multilineTextAlignment(.center)
                        .minimumScaleFactor(0.5)
                        .lineLimit(2)
                        .padding(.horizontal, 32)

                    Text(hint)
                        .font(.footnote)
                        .foregroundStyle(Color.fontiCream.opacity(0.35))
                }
                .contentShape(Rectangle())
                .onTapGesture { onPick?(featured) }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Font of the day, \(featured.displayName)")
                .accessibilityHint("Opens this typeface")
                .accessibilityAddTraits(.isButton)
            } else {
                Text(hint)
                    .font(.title3)
                    .foregroundStyle(Color.fontiCream.opacity(0.4))
            }
        }
    }
}
