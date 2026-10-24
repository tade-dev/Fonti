import SwiftUI

/// First-launch greeting, shown over Home rather than in front of it.
///
/// This replaces the old onboarding carousel. A sheet is the system's job:
/// it sizes and positions itself on a phone, on iPhone Duo folded or open,
/// and on iPad without a single layout decision here — which is most of why
/// the carousel was replaced, since it was the first screen to break on every
/// new shape.
struct WelcomeSheet: View {
    let onContinue: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 26) {
                header
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(WelcomeFeature.all) { WelcomeFeatureRow(feature: $0) }
                }
            }
            .padding(.horizontal, 28)
            // Tight enough that all five rows land above the button on the
            // 678pt cover panel. The list still scrolls — safeAreaInset keeps
            // it clear of the button — but nobody opens on a cut-off row.
            .padding(.top, 40)
            .padding(.bottom, 12)
            // Capped so the rows keep a readable measure on the inner display
            // and on iPad, where a sheet is given far more width than this
            // content wants.
            .frame(maxWidth: 460, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollBounceBehavior(.basedOnSize)
        // Pinned rather than in the scroll: on a 669pt-tall landscape panel
        // the list scrolls, and the way out should never scroll away with it.
        .safeAreaInset(edge: .bottom) {
            Button(action: onContinue) {
                Text("Get Started")
                    .foregroundStyle(.black)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .tint(.fontiAmber)
            .controlSize(.large)
            .padding(.horizontal, 28)
            .padding(.bottom, 20)
            .frame(maxWidth: 460)
            .frame(maxWidth: .infinity)
            .background(Color.fontiInk.opacity(0.92))
        }
        .background(Color.fontiInk.ignoresSafeArea())
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Welcome to")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.fontiCream.opacity(0.7))

            Image("FontiWordmark")
                .resizable()
                .scaledToFit()
                .frame(height: 34)
                .accessibilityLabel("Fonti")
        }
    }
}

/// One line of the welcome list.
struct WelcomeFeature: Identifiable {
    let id = UUID()
    let symbol: String
    let title: String
    let detail: String

    static let all: [WelcomeFeature] = [
        .init(
            symbol: "textformat",
            title: "Your words, every font",
            detail: "Type anything and the whole library re-sets itself in front of you."
        ),
        .init(
            symbol: "squares.below.rectangle",
            title: "Proper specimens",
            detail: "Four layouts and warm backgrounds, with size, weight, tracking and leading in your hands."
        ),
        .init(
            symbol: "link",
            title: "Pairings",
            detail: "Every face suggests the ones designers put it with."
        ),
        .init(
            symbol: "arrow.left.arrow.right",
            title: "Compare",
            detail: "Put two typefaces side by side and judge them together."
        ),
        .init(
            symbol: "heart",
            title: "Yours to keep",
            detail: "Heart a shortlist, and bring in your own .ttf and .otf files."
        )
    ]
}

private struct WelcomeFeatureRow: View {
    let feature: WelcomeFeature

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: feature.symbol)
                .font(.system(size: 22))
                .foregroundStyle(Color.fontiAmber)
                // Fixed width so the titles align however wide the glyphs are.
                .frame(width: 32, alignment: .center)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text(feature.title)
                    .font(.headline)
                    .foregroundStyle(Color.fontiCream)

                Text(feature.detail)
                    .font(.subheadline)
                    .foregroundStyle(Color.fontiCream.opacity(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    Color.fontiInk
        .sheet(isPresented: .constant(true)) {
            WelcomeSheet(onContinue: {})
        }
}
