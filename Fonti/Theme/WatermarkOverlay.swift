import UIKit

enum WatermarkOverlay {
    private static let text = "FONTI"
    private static let fontSize: CGFloat = 32
    private static let inset: CGFloat = 24
    private static let opacity: CGFloat = 0.7

    static func compose(over image: UIImage) -> UIImage {
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            image.draw(in: CGRect(origin: .zero, size: size))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
                .foregroundColor: UIColor(red: 0.961, green: 0.941, blue: 0.910, alpha: opacity),
                .kern: 2.0
            ]
            let attr = NSAttributedString(string: text, attributes: attrs)
            let textSize = attr.size()
            let origin = CGPoint(
                x: size.width - textSize.width - inset,
                y: size.height - textSize.height - inset
            )
            attr.draw(at: origin)
        }
    }

    static func caLayer(canvasSize: CGSize) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: canvasSize)

        let textLayer = CATextLayer()
        textLayer.string = text
        textLayer.fontSize = fontSize
        textLayer.font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        textLayer.foregroundColor = UIColor(
            red: 0.961, green: 0.941, blue: 0.910, alpha: opacity
        ).cgColor
        textLayer.alignmentMode = .right
        textLayer.contentsScale = UIScreen.main.scale

        let textWidth: CGFloat = 140
        let textHeight = fontSize * 1.4
        textLayer.frame = CGRect(
            x: canvasSize.width - textWidth - inset,
            y: inset,
            width: textWidth,
            height: textHeight
        )
        container.addSublayer(textLayer)
        return container
    }
}
