import SwiftUI

/// Step 2 — a serif capital and a sans lowercase overlapping at a shared
/// baseline, dressed up with type-specimen guide rules and a kerning mark.
struct PairsThatWorkIllustration: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let unit = min(w, h)

            ZStack {
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [Color.fontiAmber.opacity(0.24), Color.fontiAmber.opacity(0)],
                            center: .center, startRadius: 0, endRadius: unit * 0.44
                        )
                    )
                    .frame(width: unit * 0.88, height: unit * 0.38)
                    .position(x: w * 0.529, y: h * 0.662)

                guideRules(w: w, h: h)

                EngravedGlyph(
                    letter: "A",
                    font: .custom("Cochin", size: unit * 0.6),
                    color: .fontiCream,
                    angle: .degrees(45),
                    shadeEdge: .leading,
                    shadeFraction: 0.4
                )
                .position(x: w * 0.347, y: h * 0.6)

                EngravedGlyph(
                    letter: "a",
                    font: .custom("HelveticaNeue-Bold", size: unit * 0.44),
                    color: .fontiAmber,
                    angle: .degrees(-45),
                    shadeEdge: .trailing,
                    shadeFraction: 0.4
                )
                .position(x: w * 0.653, y: h * 0.63)

                kerningMark(w: w, h: h)

                Text("Aa")
                    .font(.custom("SnellRoundhand", size: unit * 0.094))
                    .foregroundStyle(Color.fontiCream.opacity(0.22))
                    .position(x: w * 0.847, y: h * 0.135)
            }
        }
    }

    private func guideRules(w: CGFloat, h: CGFloat) -> some View {
        ZStack {
            rule(y: h * 0.265, w: w, opacity: 0.14, dashed: true)
            rule(y: h * 0.441, w: w, opacity: 0.14, dashed: true)
            rule(y: h * 0.662, w: w, opacity: 0.3, dashed: false)
        }
    }

    private func rule(y: CGFloat, w: CGFloat, opacity: Double, dashed: Bool) -> some View {
        Path { path in
            path.move(to: CGPoint(x: w * 0.076, y: y))
            path.addLine(to: CGPoint(x: w * 0.924, y: y))
        }
        .stroke(
            Color.fontiCream.opacity(opacity),
            style: dashed ? StrokeStyle(lineWidth: 1, dash: [3, 5]) : StrokeStyle(lineWidth: 1)
        )
    }

    private func kerningMark(w: CGFloat, h: CGFloat) -> some View {
        Path { path in
            let x1 = w * 0.441
            let x2 = w * 0.518
            let yTop = h * 0.544
            let yBottom = h * 0.603
            let yMid = h * 0.574
            path.move(to: CGPoint(x: x1, y: yTop))
            path.addLine(to: CGPoint(x: x1, y: yBottom))
            path.move(to: CGPoint(x: x2, y: yTop))
            path.addLine(to: CGPoint(x: x2, y: yBottom))
            path.move(to: CGPoint(x: x1, y: yMid))
            path.addLine(to: CGPoint(x: x2, y: yMid))
        }
        .stroke(Color.fontiAmber.opacity(0.6), lineWidth: 1.2)
    }
}

#Preview {
    PairsThatWorkIllustration()
        .frame(height: 340)
        .background(Color.fontiInk.ignoresSafeArea())
}
