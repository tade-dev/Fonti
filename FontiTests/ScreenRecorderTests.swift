// FontiTests/ScreenRecorderTests.swift
import XCTest
@testable import Fonti

final class ScreenRecorderTests: XCTestCase {
    func test_inMemoryRecorder_startThenStop_returnsURL() async throws {
        let recorder = InMemoryScreenRecorder()
        try await recorder.start()
        let url = try await recorder.stop()
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
    }

    func test_inMemoryRecorder_stopWithoutStart_throws() async {
        let recorder = InMemoryScreenRecorder()
        do {
            _ = try await recorder.stop()
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? ScreenRecordingError, .notRecording)
        }
    }

    func test_inMemoryRecorder_doubleStart_throws() async throws {
        let recorder = InMemoryScreenRecorder()
        try await recorder.start()
        do {
            try await recorder.start()
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? ScreenRecordingError, .alreadyRecording)
        }
    }
}
