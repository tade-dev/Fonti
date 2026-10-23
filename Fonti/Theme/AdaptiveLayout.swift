import SwiftUI

/// Shared wide-layout vocabulary for Compare and the font detail screen.
///
/// "Wide" means regular horizontal width (iPad, iPhone Duo unfolded) or
/// compact vertical height (any phone in landscape). Wide screens drop the
/// boxed cards for full-bleed canvases split by hairlines, with controls
/// gathered into one floating glass bar or a side column.
enum AdaptiveLayout {
    static func isWide(
        horizontal: UserInterfaceSizeClass?,
        vertical: UserInterfaceSizeClass?
    ) -> Bool {
        horizontal == .regular || vertical == .compact
    }

    /// Geometry, not size classes, decides the arrangement. Size classes
    /// flip at awkward points on iPhone Duo (unfolded portrait is regular
    /// width yet taller than wide), so each posture is judged by its shape.
    ///
    /// Compare: side by side only when the container is wider than tall;
    /// otherwise stack top/bottom so each pane gets the long axis.
    static func comparePrefersSideBySide(_ size: CGSize) -> Bool {
        size.width >= 560 && size.width >= size.height
    }

    /// Detail: a settings column only when landscape-shaped and wide enough
    /// for the hero plus a usable column.
    static func detailPrefersSideColumn(_ size: CGSize) -> Bool {
        size.width >= 700 && size.width > size.height
    }

    /// Settings column width: fixed band so the hero never gets squeezed
    /// and the column never collapses. Slightly wider since the control bar
    /// moved out onto the canvas — the room now goes to the pairing chips,
    /// which are what actually ran out of it.
    static func sideColumnWidth(for width: CGFloat) -> CGFloat {
        min(max(width * 0.38, 320), 400)
    }

    /// Clamp a point size so the longest word fits on one line of `width`,
    /// so wordmarks never break mid-word ("Ty / pewriter").
    static func fittedPointSize(_ size: CGFloat, text: String, width: CGFloat) -> CGFloat {
        let longest = text.split(whereSeparator: { $0 == " " || $0 == "\n" })
            .map(\.count).max() ?? 1
        let maxSize = width / (CGFloat(max(longest, 1)) * 0.62)
        return max(min(size, maxSize), 12)
    }

    /// The one curve layout switches (compact ⇄ wide) animate on.
    static let transition = Animation.smooth(duration: 0.35)

    /// Scale type to the canvas it sits on, so the size slider stays relative
    /// to the space: 1.0 at a ~360pt phone-width card, growing on wider canvases.
    static func canvasScale(for size: CGSize, reference: CGFloat = 360) -> CGFloat {
        let basis = min(size.width, size.height * 1.4)
        return min(max(basis / reference, 0.75), 2.6)
    }
}

/// A single-pixel separator between full-bleed panes.
struct HairlineDivider: View {
    var axis: Axis = .vertical
    @Environment(\.displayScale) private var displayScale

    var body: some View {
        Rectangle()
            .fill(Color.fontiCream.opacity(0.18))
            .frame(
                width: axis == .vertical ? 1 / displayScale : nil,
                height: axis == .horizontal ? 1 / displayScale : nil
            )
            .allowsHitTesting(false)
    }
}

/// Compact capsule of controls that floats over a canvas.
struct FloatingGlassBar<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(spacing: 12) { content() }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .glassEffect(in: .capsule)
    }
}
