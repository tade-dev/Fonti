import SwiftUI
import UIKit

private struct SpecimenView: View {
    let family: String
    let text: String
    let size: CGFloat
    let bold: Bool
    let italic: Bool

    private var font: Font {
        var f = Font.custom(family, size: size)
        if bold { f = f.bold() }
        if italic { f = f.italic() }
        return f
    }

    var body: some View {
        ZStack {
            Color.fontiInk

            // FONTI wordmark, top-left
            VStack {
                HStack {
                    Text("FONTI")
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(3)
                        .foregroundStyle(Color.fontiCream.opacity(0.3))
                    Spacer()
                }
                Spacer()
            }
            .padding(48)

            // User text, centred
            Text(text.isEmpty ? family : text)
                .font(font)
                .foregroundStyle(Color.fontiCream)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 80)

            // Family label, bottom
            VStack {
                Spacer()
                Text(family.uppercased())
                    .font(.system(size: 18, weight: .medium))
                    .tracking(2)
                    .foregroundStyle(Color.fontiCream.opacity(0.7))
            }
            .padding(.bottom, 48)
        }
        .frame(width: 1080, height: 1080)
    }
}

enum SpecimenRenderer {
    @MainActor
    static func render(
        family: String,
        text: String,
        size: CGFloat,
        bold: Bool,
        italic: Bool
    ) -> UIImage? {
        let view = SpecimenView(
            family: family,
            text: text,
            size: size,
            bold: bold,
            italic: italic
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        renderer.proposedSize = .init(width: 1080, height: 1080)
        return renderer.uiImage
    }
}
