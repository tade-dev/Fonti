// Fonti/Services/ScreenRecorder.swift
import Foundation
import ReplayKit
import AVFoundation

enum ScreenRecordingError: Error, Equatable {
    case notAvailable
    case alreadyRecording
    case notRecording
    case saveFailed
}

protocol ScreenRecording: AnyObject {
    func start() async throws
    func stop() async throws -> URL
}

final class ReplayKitScreenRecorder: ScreenRecording {
    private let recorder = RPScreenRecorder.shared()
    private var outputURL: URL?

    func start() async throws {
        guard recorder.isAvailable else { throw ScreenRecordingError.notAvailable }
        guard !recorder.isRecording else { throw ScreenRecordingError.alreadyRecording }

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("in-space-\(UUID().uuidString).mov")
        outputURL = url

        do {
            try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
                recorder.startRecording { error in
                    if let error { cont.resume(throwing: error) } else { cont.resume() }
                }
            }
        } catch {
            outputURL = nil
            throw error
        }
    }

    func stop() async throws -> URL {
        guard recorder.isRecording else { throw ScreenRecordingError.notRecording }
        guard let url = outputURL else { throw ScreenRecordingError.saveFailed }

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            recorder.stopRecording(withOutput: url) { error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            }
        }
        outputURL = nil
        return url
    }
}

final class InMemoryScreenRecorder: ScreenRecording {
    private var isRecording = false
    private var currentURL: URL?

    func start() async throws {
        guard !isRecording else { throw ScreenRecordingError.alreadyRecording }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("test-\(UUID().uuidString).mov")
        try Data([0x00]).write(to: url)
        currentURL = url
        isRecording = true
    }

    func stop() async throws -> URL {
        guard isRecording, let url = currentURL else { throw ScreenRecordingError.notRecording }
        isRecording = false
        currentURL = nil
        return url
    }
}
