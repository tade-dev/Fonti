import SwiftUI

struct PairingsStrip: View {
    let family: FontFamily

    private var pairs: [FontFamily] {
        FontPairings.pairings(for: family.id).map {
            FontFamily(id: $0, displayName: $0)
        }
    }

    var body: some View {
        if !pairs.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Pairs well with")
                    .font(.caption2)
                    .tracking(1.4)
                    .textCase(.uppercase)
                    .foregroundStyle(Color.fontiCream.opacity(0.55))

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(pairs) { pair in
                            NavigationLink(value: pair) {
                                chip(for: pair)
                            }
                            .buttonStyle(LiftChipButtonStyle())
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 6)   // breathing room for the lift scale
                }
            }
        }
    }

    private func chip(for pair: FontFamily) -> some View {
        Text(pair.displayName)
            .font(.custom(pair.id, size: 18))
            .foregroundStyle(Color.fontiCream)
            .lineLimit(1)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .glassEffect(in: .capsule)
    }
}

/// Spring-scaling chip with an amber glow on press. Used for pair chips so
/// the tap feels like the card lifts before navigation, matching the
/// lift+parallax+zoom pattern on Browse / Saved.
struct LiftChipButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 1.08 : 1.0)
            .shadow(
                color: .fontiAmber.opacity(configuration.isPressed ? 0.45 : 0),
                radius: configuration.isPressed ? 14 : 0,
                y: configuration.isPressed ? 4 : 0
            )
            .animation(.spring(response: 0.32, dampingFraction: 0.65), value: configuration.isPressed)
    }
}

#Preview {
    NavigationStack {
        VStack {
            Spacer()
            PairingsStrip(
                family: FontFamily(id: "Georgia", displayName: "Georgia")
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fontiInk.ignoresSafeArea())
    }
}
