import XCTest
@testable import Fonti

final class WatermarkOverlayTests: XCTestCase {
    private func solidImage(_ size: CGSize, color: UIColor) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    func test_compose_preservesInputSize() {
        let input = solidImage(CGSize(width: 1080, height: 1920), color: .black)
        let output = WatermarkOverlay.compose(over: input)
        XCTAssertEqual(output.size, input.size)
    }

    func test_compose_isDeterministic() {
        let input = solidImage(CGSize(width: 400, height: 400), color: .black)
        let a = WatermarkOverlay.compose(over: input).pngData()
        let b = WatermarkOverlay.compose(over: input).pngData()
        XCTAssertEqual(a, b)
    }

    func test_caLayer_hasCorrectFrame() {
        let layer = WatermarkOverlay.caLayer(canvasSize: CGSize(width: 1920, height: 1080))
        XCTAssertEqual(layer.frame.size, CGSize(width: 1920, height: 1080))
    }
}
