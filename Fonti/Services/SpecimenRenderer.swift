import SwiftUI
import UIKit

private struct SpecimenView: View {
    let family: String
    let text: String
    let size: CGFloat
    let bold: Bool
    let italic: Bool
    let background: PreviewBackground
    let customImage: UIImage?
    let template: SpecimenTemplate
    let tracking: CGFloat
    let leading: CGFloat

    private var layoutSize: CGFloat { size * template.sizeMultiplier }

    private var font: Font {
        var f = Font.custom(family, size: layoutSize)
        if bold { f = f.bold() }
        if italic { f = f.italic() }
        return f
    }

    private var glyph: Color { background.glyphColor }
    private var secondary: Color { background.secondaryGlyphColor }

    var body: some View {
        ZStack {
            background
                .exportFill(customImage: customImage)

            VStack {
                HStack {
                    Text("FONTI")
                        .font(.system(size: 14, weight: .semibold))
                        .tracking(3)
                        .foregroundStyle(secondary.opacity(0.55))
                    Spacer()
                }
                Spacer()
            }
            .padding(48)

            SpecimenLayoutView(
                template: template,
                text: text.isEmpty ? family : text,
                familyName: family,
                pointSize: layoutSize,
                font: font,
                color: glyph,
                secondary: secondary,
                animates: false,
                compact: false,
                tracking: tracking,
                leading: leading
            )
            .padding(.horizontal, template == .body ? 72 : 80)
            .padding(.vertical, 120)

            VStack {
                Spacer()
                Text(family.uppercased())
                    .font(.system(size: 18, weight: .medium))
                    .tracking(2)
                    .foregroundStyle(secondary)
            }
            .padding(.bottom, 48)
        }
        .frame(width: 1080, height: 1080)
        .clipped()
    }
}

enum SpecimenRenderer {
    @MainActor
    static func render(
        family: String,
        text: String,
        size: CGFloat,
        bold: Bool,
        italic: Bool,
        background: PreviewBackground = .ink,
        customImage: UIImage? = nil,
        template: SpecimenTemplate = .wordmark,
        tracking: CGFloat = 0,
        leading: CGFloat = 4
    ) -> UIImage? {
        let view = SpecimenView(
            family: family,
            text: text,
            size: size,
            bold: bold,
            italic: italic,
            background: background,
            customImage: customImage,
            template: template,
            tracking: tracking,
            leading: leading
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        renderer.proposedSize = .init(width: 1080, height: 1080)
        return renderer.uiImage
    }
}
