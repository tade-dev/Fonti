import SwiftUI

struct PairingsStrip: View {
    let family: FontFamily

    @Environment(\.cardNamespace) private var sharedNamespace

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
                                chipView(for: pair)
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

    /// Wraps the chip with a `.matchedTransitionSource` when a shared
    /// `cardNamespace` is in the environment. That makes the tap morph
    /// chip → new Preview via the same zoom transition the destination
    /// already declares.
    @ViewBuilder
    private func chipView(for pair: FontFamily) -> some View {
        if let ns = sharedNamespace {
            chip(for: pair).matchedTransitionSource(id: pair.id, in: ns)
        } else {
            chip(for: pair)
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

/// Spring-scaling chip with an amber glow on press.
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
