import SwiftUI

struct SplashWordmark: View {
    let index: Int

    struct FontStep: Identifiable {
        let id: Int
        let font: Font
    }

    static let steps: [FontStep] = [
        FontStep(id: 0, font: .custom("HelveticaNeue-Thin", size: 76)),
        FontStep(id: 1, font: .custom("Optima-Regular", size: 72)),
        FontStep(id: 2, font: .custom("Cochin-Italic", size: 76)),
        FontStep(id: 3, font: .custom("Didot", size: 72)),
        FontStep(id: 4, font: .custom("SnellRoundhand", size: 86)),
        FontStep(id: 5, font: .custom("AvenirNext-UltraLightItalic", size: 76)),
        FontStep(id: 6, font: .system(size: 74, weight: .thin, design: .rounded))
    ]

    var body: some View {
        ZStack {
            ForEach(Self.steps, id: \.id) { step in
                if step.id == index {
                    Text("Fonti")
                        .font(step.font)
                        .foregroundStyle(Color.fontiCream)
                        .transition(
                            .opacity.combined(with: .scale(scale: 0.94))
                        )
                }
            }
        }
    }
}
