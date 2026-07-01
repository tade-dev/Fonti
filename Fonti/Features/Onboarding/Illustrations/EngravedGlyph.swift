import SwiftUI

/// A single letterform filled with a hatched line pattern instead of a flat
/// color, with a denser second hatch layer along one edge to fake shading —
/// an engraved type-specimen look.
struct EngravedGlyph: View {
    let letter: String
    let font: Font
    let color: Color
    var angle: Angle = .degrees(45)
    var shadeEdge: Edge = .trailing
    var shadeFraction: CGFloat = 0.35

    var body: some View {
        ZStack {
            hatchedLetter(spacing: 7, lineWidth: 1)
            hatchedLetter(spacing: 3, lineWidth: 1.1)
                .mask(shadeMask)
        }
    }

    private func hatchedLetter(spacing: CGFloat, lineWidth: CGFloat) -> some View {
        Text(letter)
            .font(font)
            .foregroundStyle(.clear)
            .overlay(HatchPattern(color: color, spacing: spacing, lineWidth: lineWidth, angle: angle))
            .mask(Text(letter).font(font))
    }

    private var shadeMask: some View {
        GeometryReader { proxy in
            HStack(spacing: 0) {
                if shadeEdge == .leading {
                    Color.black.frame(width: proxy.size.width * shadeFraction)
                    Color.clear
                } else {
                    Color.clear
                    Color.black.frame(width: proxy.size.width * shadeFraction)
                }
            }
        }
    }
}
