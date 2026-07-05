import Foundation

enum InSpaceGestures {
    static let minScale: Float = 0.02
    static let maxScale: Float = 5.0

    static func clampScale(_ scale: Float) -> Float {
        min(max(scale, minScale), maxScale)
    }

    static func snapRotation(_ radians: Float, snapDegrees: Float = 15) -> Float {
        let snapRadians = snapDegrees * .pi / 180
        return round(radians / snapRadians) * snapRadians
    }

    static func hapticTick(oldScale: Float, newScale: Float, tickEvery: Float = 0.5) -> Bool {
        floor(oldScale / tickEvery) != floor(newScale / tickEvery)
    }
}
