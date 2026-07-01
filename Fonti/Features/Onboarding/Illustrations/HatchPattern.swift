import SwiftUI

/// A field of parallel diagonal lines, meant to be masked by a glyph shape
/// to produce an engraved/hatched fill instead of a flat color.
struct HatchPattern: View {
    let color: Color
    var spacing: CGFloat = 6
    var lineWidth: CGFloat = 1
    var angle: Angle = .degrees(45)

    var body: some View {
        Canvas { context, size in
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.rotate(by: angle)

            let diagonal = hypot(size.width, size.height)
            var path = Path()
            var x = -diagonal
            while x < diagonal {
                path.move(to: CGPoint(x: x, y: -diagonal))
                path.addLine(to: CGPoint(x: x, y: diagonal))
                x += spacing
            }
            context.stroke(path, with: .color(color), lineWidth: lineWidth)
        }
    }
}
