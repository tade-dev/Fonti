// Fonti/Services/ScreenRecorder.swift
import Foundation
import ReplayKit
import AVFoundation
import RealityKit
import UIKit

enum ScreenRecordingError: Error, Equatable {
    case notAvailable
    case alreadyRecording
    case notRecording
    case saveFailed
    case writerSetupFailed
}

protocol ScreenRecording: AnyObject {
    func start() async throws
    func stop() async throws -> URL
}

// Records only what ARView renders (camera feed + RealityKit entities) into
// an H.264 .mov, so the InSpaceControls UI never appears in the output.
// Frame sampling is driven by CADisplayLink; ARView.snapshot() is chained
// (next request only fires when the previous completes) so we self-throttle
// to whatever real frame rate the device can deliver rather than piling up
// in-flight snapshots.
@MainActor
final class ARViewFrameRecorder: ScreenRecording {
    private weak var arView: ARView?

    private var writer: AVAssetWriter?
    private var input: AVAssetWriterInput?
    private var adapter: AVAssetWriterInputPixelBufferAdaptor?
    private var displayLink: CADisplayLink?
    private var outputURL: URL?
    private var startTime: CFTimeInterval = 0
    private var isCapturingFrame = false
    private var isActive = false
    private var pixelSize: CGSize = .zero

    init(arView: ARView) {
        self.arView = arView
    }

    func start() async throws {
        guard !isActive else { throw ScreenRecordingError.alreadyRecording }
        guard let arView else { throw ScreenRecordingError.notAvailable }

        let scale = UIScreen.main.scale
        let bounds = arView.bounds
        // AVAssetWriter rejects odd dimensions for some presets — round to
        // even integers on both axes.
        let w = max(2, Int((bounds.width * scale).rounded()) & ~1)
        let h = max(2, Int((bounds.height * scale).rounded()) & ~1)
        pixelSize = CGSize(width: w, height: h)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("in-space-ar-\(UUID().uuidString).mov")
        outputURL = url

        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let settings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: w,
            AVVideoHeightKey: h
        ]
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
        input.expectsMediaDataInRealTime = true

        let attrs: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: w,
            kCVPixelBufferHeightKey as String: h
        ]
        let adapter = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: input, sourcePixelBufferAttributes: attrs
        )

        guard writer.canAdd(input) else {
            throw ScreenRecordingError.writerSetupFailed
        }
        writer.add(input)

        guard writer.startWriting() else {
            throw ScreenRecordingError.writerSetupFailed
        }
        writer.startSession(atSourceTime: .zero)

        self.writer = writer
        self.input = input
        self.adapter = adapter
        self.startTime = CACurrentMediaTime()
        self.isActive = true

        let link = CADisplayLink(target: self, selector: #selector(onFrame))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 24, maximum: 60, preferred: 30)
        link.add(to: .main, forMode: .common)
        self.displayLink = link
    }

    func stop() async throws -> URL {
        guard isActive, let writer, let input, let url = outputURL else {
            throw ScreenRecordingError.notRecording
        }
        isActive = false
        displayLink?.invalidate()
        displayLink = nil

        input.markAsFinished()
        await writer.finishWriting()

        self.writer = nil
        self.input = nil
        self.adapter = nil
        outputURL = nil

        guard writer.status == .completed else {
            throw ScreenRecordingError.saveFailed
        }
        return url
    }

    @objc private func onFrame() {
        guard isActive, !isCapturingFrame else { return }
        guard let arView, let adapter, let input else { return }
        guard input.isReadyForMoreMediaData else { return }

        isCapturingFrame = true
        let time = CMTime(seconds: CACurrentMediaTime() - startTime, preferredTimescale: 600)

        arView.snapshot(saveToHDR: false) { [weak self] image in
            guard let self else { return }
            defer { self.isCapturingFrame = false }
            guard let image, let buffer = self.pixelBuffer(from: image) else { return }
            adapter.append(buffer, withPresentationTime: time)
        }
    }

    private func pixelBuffer(from image: UIImage) -> CVPixelBuffer? {
        guard let cgImage = image.cgImage else { return nil }
        let w = Int(pixelSize.width)
        let h = Int(pixelSize.height)

        var pb: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault, w, h, kCVPixelFormatType_32BGRA,
            [
                kCVPixelBufferCGImageCompatibilityKey: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey: true
            ] as CFDictionary,
            &pb
        )
        guard status == kCVReturnSuccess, let buffer = pb else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: w, height: h,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: w, height: h))
        return buffer
    }
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
