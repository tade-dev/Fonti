import XCTest
@testable import Fonti

@MainActor
final class ARCaptureCoordinatorTests: XCTestCase {
    private func stubImage() -> UIImage {
        UIGraphicsImageRenderer(size: CGSize(width: 100, height: 100)).image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 100, height: 100))
        }
    }

    func test_capture_photo_returnsPhotoCaseWithWatermarkedFile() async throws {
        let snapshotter: () async -> UIImage? = { self.stubImage() }
        let recorder = InMemoryScreenRecorder()
        let coordinator = ARCaptureCoordinator(snapshotter: snapshotter, recorder: recorder)

        let media = try await coordinator.capture(mode: .photo)
        guard case .photo(let url) = media else {
            XCTFail("expected .photo")
            return
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func test_capture_photo_snapshotNil_throws() async {
        let snapshotter: () async -> UIImage? = { nil }
        let coordinator = ARCaptureCoordinator(
            snapshotter: snapshotter,
            recorder: InMemoryScreenRecorder()
        )
        do {
            _ = try await coordinator.capture(mode: .photo)
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? CaptureError, .snapshotFailed)
        }
    }
}
