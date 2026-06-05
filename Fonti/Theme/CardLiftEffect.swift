import SwiftUI

/// Source-side coordination for the lift+parallax transition.
///
/// When a card is `isLifted`, it scales up slightly and gains an amber glow.
/// When it is `isDimmed` (a sibling card was lifted), it pulls back, fades,
/// and blurs — producing the depth-of-field "parallax fade" effect.
struct CardLiftEffect: ViewModifier {
    let isLifted: Bool
    let isDimmed: Bool

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(isDimmed ? 0.35 : 1)
            .blur(radius: isDimmed ? 6 : 0)
            .shadow(
                color: .fontiAmber.opacity(isLifted ? 0.10 : 0),
                radius: isLifted ? 24 : 0,
                y: isLifted ? 6 : 0
            )
            .animation(.spring(response: 0.35, dampingFraction: 0.72), value: isLifted)
            .animation(.easeOut(duration: 0.22), value: isDimmed)
    }

    private var scale: CGFloat {
        if isLifted { return 1.05 }
        if isDimmed { return 0.97 }
        return 1
    }
}

extension View {
    func cardLift(isLifted: Bool, isDimmed: Bool) -> some View {
        modifier(CardLiftEffect(isLifted: isLifted, isDimmed: isDimmed))
    }
}
