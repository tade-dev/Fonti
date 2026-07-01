import SwiftUI

/// Step 1 — an engraved "A" surrounded by dim satellite glyphs in the same
/// typefaces the splash screen cycles through, radiating out like a burst.
struct EveryFontLiveIllustration: View {
    private let rayTargets: [CGPoint] = [
        CGPoint(x: 0.162, y: 0.279),
        CGPoint(x: 0.847, y: 0.2),
        CGPoint(x: 0.882, y: 0.676),
        CGPoint(x: 0.206, y: 0.794)
    ]

    private let sparklePoints: [CGPoint] = [
        CGPoint(x: 0.353, y: 0.162),
        CGPoint(x: 0.818, y: 0.441),
        CGPoint(x: 0.735, y: 0.765),
        CGPoint(x: 0.206, y: 0.632)
    ]

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let unit = min(w, h)
            let center = CGPoint(x: w * 0.5, y: h * 0.505)

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.fontiAmber.opacity(0.32), Color.fontiAmber.opacity(0)],
                            center: .center, startRadius: 0, endRadius: unit * 0.34
                        )
                    )
                    .frame(width: unit * 0.68, height: unit * 0.68)
                    .position(center)

                Path { path in
                    for target in rayTargets {
                        path.move(to: center)
                        path.addLine(to: CGPoint(x: w * target.x, y: h * target.y))
                    }
                }
                .stroke(Color.fontiCream.opacity(0.12), lineWidth: 1)

                Ellipse()
                    .stroke(Color.fontiCream.opacity(0.07), style: StrokeStyle(lineWidth: 1, dash: [2, 6]))
                    .frame(width: unit * 0.82, height: unit * 0.41)
                    .rotationEffect(.degrees(-16))
                    .position(center)

                Text("A")
                    .font(.custom("CourierNewPSMT", size: unit * 0.135))
                    .foregroundStyle(Color.fontiCream.opacity(0.16))
                    .rotationEffect(.degrees(-10))
                    .position(x: w * 0.162, y: h * 0.309)

                Text("A")
                    .font(.custom("Cochin-Italic", size: unit * 0.153))
                    .foregroundStyle(Color.fontiCream.opacity(0.18))
                    .rotationEffect(.degrees(8))
                    .position(x: w * 0.847, y: h * 0.24)

                Text("A")
                    .font(.custom("HelveticaNeue-Bold", size: unit * 0.124))
                    .foregroundStyle(Color.fontiCream.opacity(0.2))
                    .rotationEffect(.degrees(-6))
                    .position(x: w * 0.882, y: h * 0.706)

                Text("A")
                    .font(.custom("AvenirNext-UltraLightItalic", size: unit * 0.147))
                    .foregroundStyle(Color.fontiCream.opacity(0.17))
                    .rotationEffect(.degrees(5))
                    .position(x: w * 0.206, y: h * 0.818)

                EngravedGlyph(
                    letter: "A",
                    font: .custom("Didot-Bold", size: unit * 0.41),
                    color: .fontiAmber,
                    angle: .degrees(-45),
                    shadeEdge: .trailing,
                    shadeFraction: 0.4
                )
                .position(center)

                ForEach(Array(sparklePoints.enumerated()), id: \.offset) { _, point in
                    Circle()
                        .fill(Color.fontiCream.opacity(0.4))
                        .frame(width: max(unit * 0.012, 2), height: max(unit * 0.012, 2))
                        .position(x: w * point.x, y: h * point.y)
                }
            }
        }
    }
}

#Preview {
    EveryFontLiveIllustration()
        .frame(height: 340)
        .background(Color.fontiInk.ignoresSafeArea())
}
