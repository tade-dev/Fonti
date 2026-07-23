import SwiftUI
import UIKit

/// Specimen board that hosts the animated type. Background changes play as a
/// Y-axis card flip — swap the fill at 90° so nothing shows through.
struct SpecimenCard<Content: View>: View {
    let background: PreviewBackground
    let customImage: UIImage?
    let rotationY: Double
    var compact: Bool = false
    @ViewBuilder var content: () -> Content

    private let corner: CGFloat = 28

    var body: some View {
        ZStack {
            if background != .liquidGlass {
                background
                    .fill(customImage: customImage)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }

            content()
                .padding(.horizontal, compact ? 20 : 28)
                .padding(.vertical, compact ? 24 : 36)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .aspectRatio(compact ? 1.35 : 1.05, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: corner, style: .continuous))
        .modifier(LiquidGlassCardModifier(enabled: background == .liquidGlass, corner: corner))
        .overlay {
            RoundedRectangle(cornerRadius: corner, style: .continuous)
                .strokeBorder(
                    Color.fontiCream.opacity(background == .cream ? 0 : 0.08),
                    lineWidth: 1
                )
        }
        // Flatten into one layer so the photo can't paint outside during 3D.
        .compositingGroup()
        .shadow(color: .black.opacity(0.32), radius: 18, y: 10)
        .rotation3DEffect(
            .degrees(rotationY),
            axis: (x: 0, y: 1, z: 0),
            perspective: 0.65
        )
    }
}

private struct LiquidGlassCardModifier: ViewModifier {
    let enabled: Bool
    let corner: CGFloat

    func body(content: Content) -> some View {
        if enabled {
            content.glassEffect(in: .rect(cornerRadius: corner))
        } else {
            content
        }
    }
}
