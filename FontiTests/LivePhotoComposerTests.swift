// FontiTests/LivePhotoComposerTests.swift
import XCTest
import AVFoundation
import ImageIO
import MobileCoreServices
@testable import Fonti

final class LivePhotoComposerTests: XCTestCase {
    private func tempURL(_ ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(ext)
    }

    private func writeTestJPG(to url: URL) throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 64, height: 64)).image { ctx in
            UIColor.red.setFill()
            ctx.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
        }
        try image.jpegData(compressionQuality: 0.9)!.write(to: url)
    }

    private func writeTestMOV(to url: URL) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 64,
            AVVideoHeightKey: 64
        ])
        writer.add(input)
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        input.markAsFinished()
        await writer.finishWriting()
    }

    func test_pair_writesIdentifierIntoBothOutputs() async throws {
        let jpgIn = tempURL("jpg")
        let movIn = tempURL("mov")
        try writeTestJPG(to: jpgIn)
        try await writeTestMOV(to: movIn)

        let identifier = UUID().uuidString
        let (outJPG, outMOV) = try await LivePhotoComposer.pair(
            jpgAt: jpgIn, movAt: movIn, identifier: identifier
        )

        XCTAssertEqual(readImageIdentifier(from: outJPG), identifier)
        let videoIdentifier = await readVideoIdentifier(from: outMOV)
        XCTAssertEqual(videoIdentifier, identifier)
    }

    private func readImageIdentifier(from url: URL) -> String? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
              let maker = props[kCGImagePropertyMakerAppleDictionary] as? [String: Any]
        else { return nil }
        return maker["17"] as? String
    }

    private func readVideoIdentifier(from url: URL) async -> String? {
        let asset = AVURLAsset(url: url)
        do {
            let metadata = try await asset.load(.metadata)
            let item = metadata.first { $0.identifier?.rawValue == "com.apple.quicktime.content.identifier" }
            return try await item?.load(.stringValue)
        } catch { return nil }
    }
}
