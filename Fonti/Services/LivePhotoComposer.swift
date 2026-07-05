// Fonti/Services/LivePhotoComposer.swift
import AVFoundation
import ImageIO
import MobileCoreServices
import UniformTypeIdentifiers

enum LivePhotoComposerError: Error {
    case cannotReadImage
    case cannotWriteImage
    case cannotReadVideo
    case cannotWriteVideo
}

enum LivePhotoComposer {
    static func pair(jpgAt jpgIn: URL, movAt movIn: URL, identifier: String) async throws -> (jpgURL: URL, movURL: URL) {
        let outputDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("LivePhoto-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)
        let outJPG = outputDir.appendingPathComponent("frame.jpg")
        let outMOV = outputDir.appendingPathComponent("motion.mov")

        try writeImageWithIdentifier(from: jpgIn, to: outJPG, identifier: identifier)
        try await writeVideoWithIdentifier(from: movIn, to: outMOV, identifier: identifier)

        return (outJPG, outMOV)
    }

    private static func writeImageWithIdentifier(from src: URL, to dst: URL, identifier: String) throws {
        guard let source = CGImageSourceCreateWithURL(src as CFURL, nil),
              let dest = CGImageDestinationCreateWithURL(dst as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw LivePhotoComposerError.cannotReadImage }

        var props = (CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]) ?? [:]
        var maker = (props[kCGImagePropertyMakerAppleDictionary] as? [String: Any]) ?? [:]
        maker["17"] = identifier
        props[kCGImagePropertyMakerAppleDictionary] = maker

        CGImageDestinationAddImageFromSource(dest, source, 0, props as CFDictionary)
        guard CGImageDestinationFinalize(dest) else {
            throw LivePhotoComposerError.cannotWriteImage
        }
    }

    private static func writeVideoWithIdentifier(from src: URL, to dst: URL, identifier: String) async throws {
        let asset = AVURLAsset(url: src)
        guard let exporter = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetPassthrough) else {
            throw LivePhotoComposerError.cannotReadVideo
        }

        let identifierItem = AVMutableMetadataItem()
        identifierItem.identifier = .init(rawValue: "com.apple.quicktime.content.identifier")
        identifierItem.value = identifier as NSString
        identifierItem.dataType = "com.apple.metadata.datatype.UTF-8"

        let stillTimeItem = AVMutableMetadataItem()
        stillTimeItem.identifier = .init(rawValue: "mdta/com.apple.quicktime.still-image-time")
        stillTimeItem.value = 0 as NSNumber
        stillTimeItem.dataType = "com.apple.metadata.datatype.int8"

        exporter.metadata = [identifierItem, stillTimeItem]

        do {
            try await exporter.export(to: dst, as: .mov)
        } catch {
            throw LivePhotoComposerError.cannotWriteVideo
        }
    }
}
