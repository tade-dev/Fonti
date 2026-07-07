import UIKit
import AVFoundation

enum CaptureError: Error, Equatable {
    case snapshotFailed
    case recorderUnavailable
}

@MainActor
final class ARCaptureCoordinator {
    static let maxVideoDurationDefault: Double = 15
    static let maxVideoDurationThermal: Double = 5

    private var snapshotter: () async -> UIImage?
    private var recorder: ScreenRecording
    private var videoSleepTask: Task<Void, Never>?

    var isRecording: Bool { videoSleepTask != nil }

    init(snapshotter: @escaping () async -> UIImage?, recorder: ScreenRecording) {
        self.snapshotter = snapshotter
        self.recorder = recorder
    }

    func updateSnapshotter(_ snap: @escaping () async -> UIImage?) {
        self.snapshotter = snap
    }

    func updateRecorder(_ recorder: ScreenRecording) {
        self.recorder = recorder
    }

    private static func maxVideoDurationForCurrentThermal() -> Double {
        ProcessInfo.processInfo.thermalState == .critical
            ? maxVideoDurationThermal
            : maxVideoDurationDefault
    }

    func capture(mode: InSpaceMode) async throws -> CapturedMedia {
        switch mode {
        case .photo:
            return .photo(try await capturePhoto())
        case .video:
            return .video(try await recordVideo(maxSeconds: Self.maxVideoDurationForCurrentThermal()))
        case .live:
            return try await captureLivePhoto()
        }
    }

    func stopRecordingEarly() {
        videoSleepTask?.cancel()
    }

    private func capturePhoto() async throws -> URL {
        guard let image = await snapshotter() else { throw CaptureError.snapshotFailed }
        let watermarked = WatermarkOverlay.compose(over: image)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("in-space-\(UUID().uuidString).jpg")
        guard let data = watermarked.jpegData(compressionQuality: 0.92) else {
            throw CaptureError.snapshotFailed
        }
        try data.write(to: url)
        return url
    }

    func recordVideo(maxSeconds: Double) async throws -> URL {
        try await recorder.start()
        let sleep: Task<Void, Never> = Task {
            try? await Task.sleep(nanoseconds: UInt64(maxSeconds * 1_000_000_000))
            return
        }
        videoSleepTask = sleep
        await sleep.value
        videoSleepTask = nil
        let raw = try await recorder.stop()
        return try await burnWatermark(into: raw)
    }

    private func burnWatermark(into rawURL: URL) async throws -> URL {
        let asset = AVURLAsset(url: rawURL)
        guard let track = try await asset.loadTracks(withMediaType: .video).first else {
            return rawURL
        }
        let naturalSize = try await track.load(.naturalSize)

        let composition = AVMutableComposition()
        let compTrack = composition.addMutableTrack(
            withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid
        )
        let duration = try await asset.load(.duration)
        try compTrack?.insertTimeRange(
            CMTimeRange(start: .zero, duration: duration), of: track, at: .zero
        )

        let videoComposition = AVMutableVideoComposition()
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.renderSize = naturalSize

        let overlay = WatermarkOverlay.caLayer(canvasSize: naturalSize)
        let parent = CALayer()
        parent.frame = CGRect(origin: .zero, size: naturalSize)
        let videoLayer = CALayer()
        videoLayer.frame = parent.frame
        parent.addSublayer(videoLayer)
        parent.addSublayer(overlay)
        videoComposition.animationTool = AVVideoCompositionCoreAnimationTool(
            postProcessingAsVideoLayer: videoLayer, in: parent
        )

        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        if let compTrack {
            let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compTrack)
            instruction.layerInstructions = [layerInstruction]
        }
        videoComposition.instructions = [instruction]

        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("in-space-\(UUID().uuidString).mov")

        guard let exporter = AVAssetExportSession(
            asset: composition, presetName: AVAssetExportPresetHighestQuality
        ) else { return rawURL }
        exporter.videoComposition = videoComposition
        do {
            try await exporter.export(to: outURL, as: .mov)
            return outURL
        } catch {
            return rawURL
        }
    }

    private func captureLivePhoto() async throws -> CapturedMedia {
        let identifier = UUID().uuidString
        try await recorder.start()

        try? await Task.sleep(nanoseconds: 1_500_000_000)
        guard let midFrame = await snapshotter() else {
            _ = try? await recorder.stop()
            throw CaptureError.snapshotFailed
        }
        let watermarkedFrame = WatermarkOverlay.compose(over: midFrame)
        let jpgURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("live-\(UUID().uuidString).jpg")
        guard let data = watermarkedFrame.jpegData(compressionQuality: 0.92) else {
            _ = try? await recorder.stop()
            throw CaptureError.snapshotFailed
        }
        try data.write(to: jpgURL)

        try? await Task.sleep(nanoseconds: 1_500_000_000)
        let rawMOV = try await recorder.stop()
        let watermarkedMOV = try await burnWatermark(into: rawMOV)

        let paired = try await LivePhotoComposer.pair(
            jpgAt: jpgURL, movAt: watermarkedMOV, identifier: identifier
        )
        return .livePhoto(jpgURL: paired.jpgURL, movURL: paired.movURL)
    }
}
