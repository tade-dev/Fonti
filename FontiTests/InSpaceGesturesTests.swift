import XCTest
@testable import Fonti

final class InSpaceGesturesTests: XCTestCase {
    func test_clampScale_belowMinReturnsMin() {
        XCTAssertEqual(InSpaceGestures.clampScale(0.01), InSpaceGestures.minScale, accuracy: 0.0001)
    }

    func test_clampScale_aboveMaxReturnsMax() {
        XCTAssertEqual(InSpaceGestures.clampScale(9.9), InSpaceGestures.maxScale, accuracy: 0.0001)
    }

    func test_clampScale_inRangeUnchanged() {
        XCTAssertEqual(InSpaceGestures.clampScale(1.2), 1.2, accuracy: 0.0001)
    }

    func test_snapRotation_snapsTo15Degrees() {
        let almost30 = Float(29.0) * .pi / 180
        let snapped = InSpaceGestures.snapRotation(almost30)
        XCTAssertEqual(snapped, Float(30.0) * .pi / 180, accuracy: 0.0001)
    }

    func test_hapticTick_crossesHalfBoundary() {
        XCTAssertTrue(InSpaceGestures.hapticTick(oldScale: 0.4, newScale: 0.6))
        XCTAssertFalse(InSpaceGestures.hapticTick(oldScale: 0.51, newScale: 0.55))
    }
}
