import SwiftUI

/// Step 3 — the letters F, O, N, T fanned out dim in the background, with
/// a hatched "I" wearing a small heart halo as the hero glyph.
struct KeepWhatYouLoveIllustration: View {
    private let sparklePoints: [CGPoint] = [
        CGPoint(x: 0.894, y: 0.535),
        CGPoint(x: 0.947, y: 0.682),
        CGPoint(x: 0.859, y: 0.865)
    ]

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let unit = min(w, h)
            let heroCenter = CGPoint(x: w * 0.75, y: h * 0.7)

            ZStack {
                Path { path in
                    path.move(to: CGPoint(x: w * 0.106, y: h * 0.788))
                    path.addQuadCurve(
                        to: CGPoint(x: w * 0.929, y: h * 0.741),
                        control: CGPoint(x: w * 0.5, y: h * 0.347)
                    )
                }
                .stroke(Color.fontiCream.opacity(0.09), style: StrokeStyle(lineWidth: 1, dash: [2, 6]))

                Text("F")
                    .font(.custom("Optima-Regular", size: unit * 0.159))
                    .foregroundStyle(Color.fontiCream.opacity(0.22))
                    .rotationEffect(.degrees(-24))
                    .position(x: w * 0.171, y: h * 0.671)

                Text("O")
                    .font(.custom("CourierNewPSMT", size: unit * 0.147))
                    .foregroundStyle(Color.fontiCream.opacity(0.24))
                    .rotationEffect(.degrees(-13))
                    .position(x: w * 0.306, y: h * 0.524)

                Text("N")
                    .font(.custom("HelveticaNeue-Bold", size: unit * 0.135))
                    .foregroundStyle(Color.fontiCream.opacity(0.26))
                    .rotationEffect(.degrees(-3))
                    .position(x: w * 0.5, y: h * 0.45)

                Text("T")
                    .font(.system(size: unit * 0.147, weight: .thin, design: .rounded))
                    .foregroundStyle(Color.fontiCream.opacity(0.24))
                    .rotationEffect(.degrees(12))
                    .position(x: w * 0.744, y: h * 0.509)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.fontiAmber.opacity(0.3), Color.fontiAmber.opacity(0)],
                            center: .center, startRadius: 0, endRadius: unit * 0.28
                        )
                    )
                    .frame(width: unit * 0.56, height: unit * 0.56)
                    .position(heroCenter)

                heartHalo(center: CGPoint(x: heroCenter.x, y: heroCenter.y - unit * 0.16), width: unit * 0.16)
                    .stroke(Color.fontiAmber.opacity(0.6), lineWidth: 1.3)

                EngravedGlyph(
                    letter: "I",
                    font: .custom("Didot-Bold", size: unit * 0.29),
                    color: .fontiAmber,
                    angle: .degrees(-45),
                    shadeEdge: .trailing,
                    shadeFraction: 0.4
                )
                .rotationEffect(.degrees(6))
                .position(heroCenter)

                ForEach(Array(sparklePoints.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(Color.fontiAmber.opacity(0.55))
                        .frame(width: max(unit * 0.013, 2), height: max(unit * 0.013, 2))
                        .position(x: w * point.x, y: h * point.y)
                }
            }
        }
    }

    private func heartHalo(center: CGPoint, width: CGFloat) -> Path {
        let s = width / 54
        var path = Path()
        let top = CGPoint(x: center.x, y: center.y - 32 * s)
        path.move(to: top)
        path.addCurve(
            to: CGPoint(x: center.x - 27 * s, y: center.y - 28 * s),
            control1: CGPoint(x: center.x - 9 * s, y: center.y - 43 * s),
            control2: CGPoint(x: center.x - 27 * s, y: center.y - 43 * s)
        )
        path.addCurve(
            to: CGPoint(x: center.x, y: center.y + 5 * s),
            control1: CGPoint(x: center.x - 27 * s, y: center.y - 15 * s),
            control2: CGPoint(x: center.x - 12 * s, y: center.y - 5 * s)
        )
        path.addCurve(
            to: CGPoint(x: center.x + 27 * s, y: center.y - 28 * s),
            control1: CGPoint(x: center.x + 12 * s, y: center.y - 5 * s),
            control2: CGPoint(x: center.x + 27 * s, y: center.y - 15 * s)
        )
        path.addCurve(
            to: top,
            control1: CGPoint(x: center.x + 27 * s, y: center.y - 43 * s),
            control2: CGPoint(x: center.x + 9 * s, y: center.y - 43 * s)
        )
        path.closeSubpath()
        return path
    }
}

#Preview {
    KeepWhatYouLoveIllustration()
        .frame(height: 340)
        .background(Color.fontiInk.ignoresSafeArea())
}
