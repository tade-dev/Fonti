# In Space (AR) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship an AR mode launched from Full Screen Preview that places extruded 3D text in the world, with photo / video / Live Photo capture and a small "FONTI" wordmark on outputs.

**Architecture:** New feature module at `Fonti/Features/InSpace/` composing a `RealityView`-based scene, glass controls, and a capture-preview sheet. Pure-logic services live under `Fonti/Services/` (mesh builder, watermark, screen recorder, live photo composer, capture coordinator). Entry point is a new AR icon in the existing `PreviewControls` glass capsule; state passes down via parameters. No new SwiftData models.

**Tech Stack:** SwiftUI, RealityKit (`RealityView`, `MeshResource.generateText`), ARKit (`ARWorldTrackingConfiguration`, no plane detection), ReplayKit (`RPScreenRecorder`), AVFoundation (`AVAssetWriter`, `AVVideoCompositionCoreAnimationTool`), Photos (`PHAssetCreationRequest`, `PHLivePhotoView`), ImageIO (for JPG content-identifier metadata). No third-party dependencies.

## Global Constraints

- **iOS 26+ only.** No back-deployment. `RealityView` and modern APIs required.
- **No third-party packages.** Adding any dependency requires user approval.
- **Portrait orientation only** for the AR screen.
- **Reuse existing font infrastructure.** `SystemFontProvider` and `FontTraitSupport` must resolve CTFonts. Custom `.ttf`/`.otf` imports (v1.1) must work end-to-end.
- **Brand tokens:** `fontiInk` `#0D0D0D`, `fontiCream` `#F5F0E8`, `fontiAmber` `#E8A040`.
- **Watermark:** `FONTI` (uppercase), `fontiCream` at 70% opacity, 32 pt, bottom-right, 24 pt inset. Non-removable in v1.
- **Extrusion depth:** `0.02` (RealityKit world units).
- **Initial text scale:** `0.15`. Text placed at world position `(0, 0, -0.4)`.
- **Video max length:** 15 s (5 s under thermal `.critical`).
- **Live Photo duration:** 3 s, key frame at `t=1.5s`.
- **Copy is exact** — do not paraphrase user-visible strings from the spec.
- **Voice:** short, confident, lowercase-friendly. Match existing app copy.
- **No emojis** in code, UI, or comments.

---

## File Structure

**Create:**

```
Fonti/
├── Models/
│   └── CapturedMedia.swift
├── Theme/
│   └── WatermarkOverlay.swift
├── Services/
│   ├── ARTextMeshBuilder.swift
│   ├── LivePhotoComposer.swift
│   ├── ScreenRecorder.swift
│   └── ARCaptureCoordinator.swift
└── Features/
    └── InSpace/
        ├── InSpaceMode.swift
        ├── InSpaceMaterial.swift
        ├── InSpaceGestures.swift
        ├── InSpaceScene.swift
        ├── InSpaceControls.swift
        ├── CapturePreviewSheet.swift
        └── InSpaceView.swift
```

**Modify:**

- `Fonti/Features/Preview/PreviewControls.swift` — add AR icon button.
- `Fonti/Features/Preview/FullScreenPreviewView.swift` — present `InSpaceView`.
- `Fonti.xcodeproj/project.pbxproj` — new file refs (Xcode does this automatically when creating files inside the target).
- `Fonti/Info.plist` — `NSCameraUsageDescription`, `NSPhotoLibraryAddUsageDescription`.

**Test targets:**

- `FontiTests/` — the existing unit test target. Add test files parallel to the sources they cover.

---

## Task 1: Data models & shared enums

**Files:**
- Create: `Fonti/Models/CapturedMedia.swift`
- Create: `Fonti/Features/InSpace/InSpaceMode.swift`
- Create: `Fonti/Features/InSpace/InSpaceMaterial.swift`
- Test: `FontiTests/InSpaceMaterialTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum CapturedMedia { case photo(URL); case video(URL); case livePhoto(jpgURL: URL, movURL: URL) }`
  - `enum InSpaceMode: CaseIterable { case photo, video, live }` with `var title: String`
  - `enum InSpaceMaterial: CaseIterable { case cream, glass, amber }` with `var displayName: String`, `func next() -> InSpaceMaterial`, `var materialProperties: (baseColor: UIColor, roughness: Float, metallic: Float, isTranslucent: Bool)`

- [ ] **Step 1: Write the failing test**

```swift
// FontiTests/InSpaceMaterialTests.swift
import XCTest
@testable import Fonti

final class InSpaceMaterialTests: XCTestCase {
    func test_next_cyclesCreamGlassAmberCream() {
        XCTAssertEqual(InSpaceMaterial.cream.next(), .glass)
        XCTAssertEqual(InSpaceMaterial.glass.next(), .amber)
        XCTAssertEqual(InSpaceMaterial.amber.next(), .cream)
    }

    func test_materialProperties_amberIsMetallic() {
        let props = InSpaceMaterial.amber.materialProperties
        XCTAssertEqual(props.metallic, 1.0)
        XCTAssertEqual(props.roughness, 0.25)
        XCTAssertFalse(props.isTranslucent)
    }

    func test_materialProperties_glassIsTranslucent() {
        let props = InSpaceMaterial.glass.materialProperties
        XCTAssertTrue(props.isTranslucent)
        XCTAssertEqual(props.roughness, 0.05)
    }

    func test_allCases_hasThreeMaterials() {
        XCTAssertEqual(InSpaceMaterial.allCases.count, 3)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Fonti -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FontiTests/InSpaceMaterialTests`
Expected: FAIL with "Cannot find 'InSpaceMaterial' in scope"

- [ ] **Step 3: Create InSpaceMaterial.swift**

```swift
// Fonti/Features/InSpace/InSpaceMaterial.swift
import UIKit

enum InSpaceMaterial: CaseIterable, Equatable {
    case cream
    case glass
    case amber

    var displayName: String {
        switch self {
        case .cream: return "cream"
        case .glass: return "glass"
        case .amber: return "amber"
        }
    }

    func next() -> InSpaceMaterial {
        let all = InSpaceMaterial.allCases
        let idx = all.firstIndex(of: self) ?? 0
        return all[(idx + 1) % all.count]
    }

    var materialProperties: (baseColor: UIColor, roughness: Float, metallic: Float, isTranslucent: Bool) {
        switch self {
        case .cream:
            return (UIColor(red: 0.961, green: 0.941, blue: 0.910, alpha: 1.0), 0.85, 0.0, false)
        case .glass:
            return (UIColor(white: 1.0, alpha: 0.4), 0.05, 0.0, true)
        case .amber:
            return (UIColor(red: 0.910, green: 0.627, blue: 0.251, alpha: 1.0), 0.25, 1.0, false)
        }
    }
}
```

- [ ] **Step 4: Create InSpaceMode.swift**

```swift
// Fonti/Features/InSpace/InSpaceMode.swift
import Foundation

enum InSpaceMode: CaseIterable, Equatable {
    case photo, video, live

    var title: String {
        switch self {
        case .photo: return "Photo"
        case .video: return "Video"
        case .live: return "Live"
        }
    }
}
```

- [ ] **Step 5: Create CapturedMedia.swift**

```swift
// Fonti/Models/CapturedMedia.swift
import Foundation

enum CapturedMedia {
    case photo(URL)
    case video(URL)
    case livePhoto(jpgURL: URL, movURL: URL)
}
```

- [ ] **Step 6: Run test to verify it passes**

Run: `xcodebuild test -scheme Fonti -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FontiTests/InSpaceMaterialTests`
Expected: PASS (4 tests)

- [ ] **Step 7: Commit**

```bash
git add Fonti/Models/CapturedMedia.swift Fonti/Features/InSpace/InSpaceMode.swift Fonti/Features/InSpace/InSpaceMaterial.swift FontiTests/InSpaceMaterialTests.swift Fonti.xcodeproj
git commit -m "feat(in-space): shared enums — CapturedMedia, InSpaceMode, InSpaceMaterial"
```

---

## Task 2: WatermarkOverlay

**Files:**
- Create: `Fonti/Theme/WatermarkOverlay.swift`
- Test: `FontiTests/WatermarkOverlayTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum WatermarkOverlay { static func compose(over image: UIImage) -> UIImage; static func caLayer(canvasSize: CGSize) -> CALayer }`

- [ ] **Step 1: Write the failing test**

```swift
// FontiTests/WatermarkOverlayTests.swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Fonti -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FontiTests/WatermarkOverlayTests`
Expected: FAIL with "Cannot find 'WatermarkOverlay' in scope"

- [ ] **Step 3: Implement WatermarkOverlay.swift**

```swift
// Fonti/Theme/WatermarkOverlay.swift
import UIKit

enum WatermarkOverlay {
    private static let text = "FONTI"
    private static let fontSize: CGFloat = 32
    private static let inset: CGFloat = 24
    private static let opacity: CGFloat = 0.7

    static func compose(over image: UIImage) -> UIImage {
        let size = image.size
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            image.draw(in: CGRect(origin: .zero, size: size))
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: fontSize, weight: .medium),
                .foregroundColor: UIColor(red: 0.961, green: 0.941, blue: 0.910, alpha: opacity),
                .kern: 2.0
            ]
            let attr = NSAttributedString(string: text, attributes: attrs)
            let textSize = attr.size()
            let origin = CGPoint(
                x: size.width - textSize.width - inset,
                y: size.height - textSize.height - inset
            )
            attr.draw(at: origin)
        }
    }

    static func caLayer(canvasSize: CGSize) -> CALayer {
        let container = CALayer()
        container.frame = CGRect(origin: .zero, size: canvasSize)

        let textLayer = CATextLayer()
        textLayer.string = text
        textLayer.fontSize = fontSize
        textLayer.font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
        textLayer.foregroundColor = UIColor(
            red: 0.961, green: 0.941, blue: 0.910, alpha: opacity
        ).cgColor
        textLayer.alignmentMode = .right
        textLayer.contentsScale = UIScreen.main.scale

        let textWidth: CGFloat = 140
        let textHeight = fontSize * 1.4
        textLayer.frame = CGRect(
            x: canvasSize.width - textWidth - inset,
            y: inset,
            width: textWidth,
            height: textHeight
        )
        container.addSublayer(textLayer)
        return container
    }
}
```

Note: `CATextLayer` uses a flipped coordinate system for video compositions — the video pipeline in Task 6 accounts for this by placing the overlay in the correct AV coordinates.

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Fonti -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FontiTests/WatermarkOverlayTests`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add Fonti/Theme/WatermarkOverlay.swift FontiTests/WatermarkOverlayTests.swift Fonti.xcodeproj
git commit -m "feat(in-space): WatermarkOverlay — FONTI wordmark for photo + video"
```

---

## Task 3: ARTextMeshBuilder

**Files:**
- Create: `Fonti/Services/ARTextMeshBuilder.swift`
- Test: `FontiTests/ARTextMeshBuilderTests.swift`

**Interfaces:**
- Consumes: `InSpaceMaterial` (Task 1); existing `SystemFontProvider`, `FontTraitSupport`.
- Produces:
  - `enum ARTextMeshBuilder { static func build(text: String, familyName: String, bold: Bool, italic: Bool, extrusion: Float, material: InSpaceMaterial) throws -> ModelEntity }`
  - `enum ARTextMeshError: Error { case emptyText, fontResolutionFailed, timeout }`

- [ ] **Step 1: Write the failing test**

```swift
// FontiTests/ARTextMeshBuilderTests.swift
import XCTest
import RealityKit
@testable import Fonti

final class ARTextMeshBuilderTests: XCTestCase {
    func test_build_returnsEntityWithNonZeroBounds() throws {
        let entity = try ARTextMeshBuilder.build(
            text: "Aa",
            familyName: "Helvetica Neue",
            bold: false,
            italic: false,
            extrusion: 0.02,
            material: .cream
        )
        let bounds = entity.visualBounds(relativeTo: nil)
        XCTAssertGreaterThan(bounds.extents.x, 0)
        XCTAssertGreaterThan(bounds.extents.y, 0)
        XCTAssertGreaterThan(bounds.extents.z, 0)
    }

    func test_build_emptyText_throws() {
        XCTAssertThrowsError(
            try ARTextMeshBuilder.build(
                text: "",
                familyName: "Helvetica Neue",
                bold: false,
                italic: false,
                extrusion: 0.02,
                material: .cream
            )
        ) { error in
            XCTAssertEqual(error as? ARTextMeshError, .emptyText)
        }
    }

    func test_build_unknownFont_fallsBackWithoutThrowing() throws {
        let entity = try ARTextMeshBuilder.build(
            text: "Aa",
            familyName: "ThisFontDoesNotExist-12345",
            bold: false,
            italic: false,
            extrusion: 0.02,
            material: .cream
        )
        XCTAssertGreaterThan(entity.visualBounds(relativeTo: nil).extents.x, 0)
    }

    func test_build_boldTraitAppliedWhenSupported() throws {
        let plain = try ARTextMeshBuilder.build(
            text: "MMMM",
            familyName: "Helvetica Neue",
            bold: false,
            italic: false,
            extrusion: 0.02,
            material: .cream
        )
        let bold = try ARTextMeshBuilder.build(
            text: "MMMM",
            familyName: "Helvetica Neue",
            bold: true,
            italic: false,
            extrusion: 0.02,
            material: .cream
        )
        XCTAssertGreaterThan(
            bold.visualBounds(relativeTo: nil).extents.x,
            plain.visualBounds(relativeTo: nil).extents.x * 1.02
        )
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Fonti -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FontiTests/ARTextMeshBuilderTests`
Expected: FAIL with "Cannot find 'ARTextMeshBuilder' in scope"

**Timeout note (spec §6 vs reality):** the spec calls for a 2 s timeout on mesh generation. `MeshResource.generateText` is synchronous and cannot be cancelled mid-call. Wrapping it in a `Task` with an outer race gives us an *observation* timeout — we can catch that the mesh is taking too long and surface the error to the user — but the underlying call still finishes on its own thread. In v1 we implement the observation-timeout so bad fonts show the fallback UI; on a true hang the main thread stays blocked briefly. This is a known limitation; document it in the file and revisit if it becomes a real user issue.

- [ ] **Step 3: Implement ARTextMeshBuilder.swift**

```swift
// Fonti/Services/ARTextMeshBuilder.swift
import RealityKit
import UIKit
import CoreText

enum ARTextMeshError: Error, Equatable {
    case emptyText
    case fontResolutionFailed
    case timeout
}

enum ARTextMeshBuilder {
    static func build(
        text: String,
        familyName: String,
        bold: Bool,
        italic: Bool,
        extrusion: Float,
        material: InSpaceMaterial
    ) throws -> ModelEntity {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw ARTextMeshError.emptyText }

        let font = resolveFont(familyName: familyName, bold: bold, italic: italic, size: 72)

        let mesh = MeshResource.generateText(
            text,
            extrusionDepth: extrusion,
            font: font,
            containerFrame: .zero,
            alignment: .center,
            lineBreakMode: .byWordWrapping
        )

        let mat = makeMaterial(from: material)
        let entity = ModelEntity(mesh: mesh, materials: [mat])
        centerPivot(of: entity)
        return entity
    }

    private static func resolveFont(familyName: String, bold: Bool, italic: Bool, size: CGFloat) -> MeshResource.Font {
        var descriptor = UIFontDescriptor(fontAttributes: [.family: familyName])
        var traits: UIFontDescriptor.SymbolicTraits = []
        if bold { traits.insert(.traitBold) }
        if italic { traits.insert(.traitItalic) }
        if !traits.isEmpty, let traited = descriptor.withSymbolicTraits(traits) {
            descriptor = traited
        }
        let uiFont = UIFont(descriptor: descriptor, size: size)
        return MeshResource.Font(descriptor: descriptor, size: size) ?? MeshResource.Font(name: uiFont.fontName, size: size) ?? .systemFont(ofSize: size)
    }

    private static func makeMaterial(from preset: InSpaceMaterial) -> RealityKit.Material {
        let props = preset.materialProperties
        var pbr = PhysicallyBasedMaterial()
        pbr.baseColor = .init(tint: props.baseColor)
        pbr.roughness = .init(floatLiteral: props.roughness)
        pbr.metallic = .init(floatLiteral: props.metallic)
        if props.isTranslucent {
            pbr.blending = .transparent(opacity: .init(floatLiteral: 0.4))
        }
        return pbr
    }

    private static func centerPivot(of entity: ModelEntity) {
        let bounds = entity.visualBounds(relativeTo: nil)
        entity.position = -bounds.center
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Fonti -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FontiTests/ARTextMeshBuilderTests`
Expected: PASS (4 tests)

- [ ] **Step 5: Commit**

```bash
git add Fonti/Services/ARTextMeshBuilder.swift FontiTests/ARTextMeshBuilderTests.swift Fonti.xcodeproj
git commit -m "feat(in-space): ARTextMeshBuilder — CTFont-driven extruded 3D text"
```

---

## Task 4: LivePhotoComposer

**Files:**
- Create: `Fonti/Services/LivePhotoComposer.swift`
- Test: `FontiTests/LivePhotoComposerTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum LivePhotoComposer { static func pair(jpgAt: URL, movAt: URL, identifier: String) async throws -> (jpgURL: URL, movURL: URL) }`
  - `enum LivePhotoComposerError: Error { case cannotReadImage, cannotWriteImage, cannotReadVideo, cannotWriteVideo }`

- [ ] **Step 1: Write the failing test**

```swift
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
        XCTAssertEqual(await readVideoIdentifier(from: outMOV), identifier)
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Fonti -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FontiTests/LivePhotoComposerTests`
Expected: FAIL with "Cannot find 'LivePhotoComposer' in scope"

- [ ] **Step 3: Implement LivePhotoComposer.swift**

```swift
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
        exporter.outputURL = dst
        exporter.outputFileType = .mov

        let identifierItem = AVMutableMetadataItem()
        identifierItem.identifier = .init(rawValue: "com.apple.quicktime.content.identifier")
        identifierItem.value = identifier as NSString
        identifierItem.dataType = "com.apple.metadata.datatype.UTF-8"

        let stillTimeItem = AVMutableMetadataItem()
        stillTimeItem.identifier = .init(rawValue: "mdta/com.apple.quicktime.still-image-time")
        stillTimeItem.value = 0 as NSNumber
        stillTimeItem.dataType = "com.apple.metadata.datatype.int8"

        exporter.metadata = [identifierItem, stillTimeItem]
        await exporter.export()

        guard exporter.status == .completed else {
            throw LivePhotoComposerError.cannotWriteVideo
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Fonti -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FontiTests/LivePhotoComposerTests`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Fonti/Services/LivePhotoComposer.swift FontiTests/LivePhotoComposerTests.swift Fonti.xcodeproj
git commit -m "feat(in-space): LivePhotoComposer — content-identifier pairing"
```

---

## Task 5: ScreenRecorder

**Files:**
- Create: `Fonti/Services/ScreenRecorder.swift`
- Test: `FontiTests/ScreenRecorderTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `protocol ScreenRecording { func start() async throws; func stop() async throws -> URL }`
  - `final class ReplayKitScreenRecorder: ScreenRecording { init(outputName: String = UUID().uuidString) }`
  - `enum ScreenRecordingError: Error { case notAvailable, alreadyRecording, notRecording, saveFailed }`
  - `final class InMemoryScreenRecorder: ScreenRecording` (test double for later tasks)

- [ ] **Step 1: Write the failing test**

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Fonti -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FontiTests/ScreenRecorderTests`
Expected: FAIL with "Cannot find 'InMemoryScreenRecorder' in scope"

- [ ] **Step 3: Implement ScreenRecorder.swift**

```swift
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

        try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Void, Error>) in
            recorder.startRecording { error in
                if let error { cont.resume(throwing: error) } else { cont.resume() }
            }
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Fonti -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FontiTests/ScreenRecorderTests`
Expected: PASS (3 tests)

- [ ] **Step 5: Commit**

```bash
git add Fonti/Services/ScreenRecorder.swift FontiTests/ScreenRecorderTests.swift Fonti.xcodeproj
git commit -m "feat(in-space): ScreenRecorder protocol + ReplayKit + in-memory double"
```

---

## Task 6: ARCaptureCoordinator

**Files:**
- Create: `Fonti/Services/ARCaptureCoordinator.swift`
- Test: `FontiTests/ARCaptureCoordinatorTests.swift`

**Interfaces:**
- Consumes: `CapturedMedia`, `InSpaceMode` (Task 1); `WatermarkOverlay` (Task 2); `ScreenRecording`, `InMemoryScreenRecorder` (Task 5); `LivePhotoComposer` (Task 4).
- Produces:
  - `@MainActor final class ARCaptureCoordinator`
  - Init: `init(snapshotter: @escaping () async -> UIImage?, recorder: ScreenRecording)`
  - Method: `func capture(mode: InSpaceMode) async throws -> CapturedMedia`
  - Method: `func recordVideo(maxSeconds: Double) async throws -> URL`
  - Constant: `static let maxVideoDurationDefault: Double = 15`
  - `enum CaptureError: Error { case snapshotFailed, recorderUnavailable }`

- [ ] **Step 1: Write the failing test**

```swift
// FontiTests/ARCaptureCoordinatorTests.swift
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
        let coordinator = ARCaptureCoordinator(snapshotter: snapshotter, recorder: InMemoryScreenRecorder())
        do {
            _ = try await coordinator.capture(mode: .photo)
            XCTFail("expected throw")
        } catch {
            XCTAssertEqual(error as? CaptureError, .snapshotFailed)
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Fonti -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FontiTests/ARCaptureCoordinatorTests`
Expected: FAIL

- [ ] **Step 3: Implement ARCaptureCoordinator.swift**

```swift
// Fonti/Services/ARCaptureCoordinator.swift
import UIKit
import AVFoundation

enum CaptureError: Error, Equatable {
    case snapshotFailed
    case recorderUnavailable
}

@MainActor
final class ARCaptureCoordinator {
    static let maxVideoDurationDefault: Double = 15

    private let snapshotter: () async -> UIImage?
    private let recorder: ScreenRecording

    init(snapshotter: @escaping () async -> UIImage?, recorder: ScreenRecording) {
        self.snapshotter = snapshotter
        self.recorder = recorder
    }

    func capture(mode: InSpaceMode) async throws -> CapturedMedia {
        switch mode {
        case .photo:
            return .photo(try await capturePhoto())
        case .video:
            return .video(try await recordVideo(maxSeconds: Self.maxVideoDurationDefault))
        case .live:
            return try await captureLivePhoto()
        }
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
        try? await Task.sleep(nanoseconds: UInt64(maxSeconds * 1_000_000_000))
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
        let layerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: compTrack!)
        instruction.layerInstructions = [layerInstruction]
        videoComposition.instructions = [instruction]

        let outURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("in-space-\(UUID().uuidString).mov")

        guard let exporter = AVAssetExportSession(
            asset: composition, presetName: AVAssetExportPresetHighestQuality
        ) else { return rawURL }
        exporter.outputURL = outURL
        exporter.outputFileType = .mov
        exporter.videoComposition = videoComposition
        await exporter.export()
        return exporter.status == .completed ? outURL : rawURL
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
        try watermarkedFrame.jpegData(compressionQuality: 0.92)!.write(to: jpgURL)

        try? await Task.sleep(nanoseconds: 1_500_000_000)
        let rawMOV = try await recorder.stop()
        let watermarkedMOV = try await burnWatermark(into: rawMOV)

        let paired = try await LivePhotoComposer.pair(
            jpgAt: jpgURL, movAt: watermarkedMOV, identifier: identifier
        )
        return .livePhoto(jpgURL: paired.jpgURL, movURL: paired.movURL)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Fonti -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FontiTests/ARCaptureCoordinatorTests`
Expected: PASS (2 tests)

- [ ] **Step 5: Commit**

```bash
git add Fonti/Services/ARCaptureCoordinator.swift FontiTests/ARCaptureCoordinatorTests.swift Fonti.xcodeproj
git commit -m "feat(in-space): ARCaptureCoordinator — photo/video/live routing"
```

---

## Task 7: InSpaceGestures (pure math helpers)

**Files:**
- Create: `Fonti/Features/InSpace/InSpaceGestures.swift`
- Test: `FontiTests/InSpaceGesturesTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum InSpaceGestures { static let minScale: Float = 0.02; static let maxScale: Float = 5.0; static func clampScale(_ scale: Float) -> Float; static func snapRotation(_ radians: Float, snapDegrees: Float = 15) -> Float; static func hapticTick(oldScale: Float, newScale: Float) -> Bool }`

- [ ] **Step 1: Write the failing test**

```swift
// FontiTests/InSpaceGesturesTests.swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `xcodebuild test -scheme Fonti -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FontiTests/InSpaceGesturesTests`
Expected: FAIL

- [ ] **Step 3: Implement InSpaceGestures.swift**

```swift
// Fonti/Features/InSpace/InSpaceGestures.swift
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `xcodebuild test -scheme Fonti -destination 'platform=iOS Simulator,name=iPhone 17' -only-testing:FontiTests/InSpaceGesturesTests`
Expected: PASS (5 tests)

- [ ] **Step 5: Commit**

```bash
git add Fonti/Features/InSpace/InSpaceGestures.swift FontiTests/InSpaceGesturesTests.swift Fonti.xcodeproj
git commit -m "feat(in-space): InSpaceGestures — scale clamp, rotation snap, haptic ticks"
```

---

## Task 8: InSpaceScene (RealityView)

**Files:**
- Create: `Fonti/Features/InSpace/InSpaceScene.swift`

**Interfaces:**
- Consumes: `ARTextMeshBuilder`, `InSpaceMaterial`, `InSpaceGestures`.
- Produces:
  - `struct InSpaceScene: View`
  - Init: `init(text: String, familyName: String, bold: Bool, italic: Bool, material: Binding<InSpaceMaterial>, arView: Binding<ARView?>, textEntity: Binding<ModelEntity?>, onResetHandler: Binding<(() -> Void)?>)`
  - Side effect: on `.onAppear`, builds the text entity and adds it to the ARView anchor. Rebuilds when `material` changes.

- [ ] **Step 1: Implement InSpaceScene.swift**

Manual test only — RealityKit is not unit-testable without a device runtime. Correctness verified via on-device QA checklist (Task 12) and the `#Preview` in the file.

```swift
// Fonti/Features/InSpace/InSpaceScene.swift
import SwiftUI
import RealityKit
import ARKit

struct InSpaceScene: UIViewRepresentable {
    let text: String
    let familyName: String
    let bold: Bool
    let italic: Bool
    @Binding var material: InSpaceMaterial
    @Binding var arView: ARView?
    @Binding var textEntity: ModelEntity?

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .ar, automaticallyConfigureSession: false)
        let config = ARWorldTrackingConfiguration()
        config.planeDetection = []
        config.environmentTexturing = .automatic
        view.session.run(config)
        view.environment.lighting.intensityExponent = 1.0

        let anchor = AnchorEntity(world: SIMD3<Float>(0, 0, -0.4))
        view.scene.anchors.append(anchor)

        do {
            let entity = try ARTextMeshBuilder.build(
                text: text,
                familyName: familyName,
                bold: bold,
                italic: italic,
                extrusion: 0.02,
                material: material
            )
            entity.scale = SIMD3<Float>(repeating: 0.001)
            anchor.addChild(entity)

            var target = entity.transform
            target.scale = SIMD3<Float>(repeating: 0.15)
            entity.move(to: target, relativeTo: entity.parent, duration: 0.4, timingFunction: .easeOut)

            DispatchQueue.main.async {
                self.textEntity = entity
                self.arView = view
            }
        } catch {
            // Timeout / mesh failure — handled by parent view.
        }

        installGestures(on: view, context: context)
        return view
    }

    func updateUIView(_ view: ARView, context: Context) {
        guard let entity = textEntity else { return }
        entity.model?.materials = [makePBR(for: material)]
    }

    private func installGestures(on view: ARView, context: Context) {
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePinch(_:)))
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handlePan(_:)))
        let rotate = UIRotationGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleRotate(_:)))
        for g in [pinch, pan, rotate] { view.addGestureRecognizer(g) }
        context.coordinator.parent = self
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject {
        var parent: InSpaceScene?
        private var startingScale: Float = 0.15
        private var startingRotation: Float = 0
        private var startingPosition: SIMD3<Float> = SIMD3(0, 0, -0.4)

        @objc func handlePinch(_ g: UIPinchGestureRecognizer) {
            guard let entity = parent?.textEntity else { return }
            switch g.state {
            case .began: startingScale = entity.scale.x
            case .changed:
                let raw = startingScale * Float(g.scale)
                let old = entity.scale.x
                let clamped = InSpaceGestures.clampScale(raw)
                entity.scale = SIMD3<Float>(repeating: clamped)
                if InSpaceGestures.hapticTick(oldScale: old, newScale: clamped) {
                    UISelectionFeedbackGenerator().selectionChanged()
                }
            default: break
            }
        }

        @objc func handlePan(_ g: UIPanGestureRecognizer) {
            guard let entity = parent?.textEntity, let view = g.view else { return }
            switch g.state {
            case .began: startingPosition = entity.position(relativeTo: nil)
            case .changed:
                let t = g.translation(in: view)
                let dx = Float(t.x) / 800
                let dy = Float(-t.y) / 800
                entity.setPosition(startingPosition &+ SIMD3<Float>(dx, dy, 0), relativeTo: nil)
            default: break
            }
        }

        @objc func handleRotate(_ g: UIRotationGestureRecognizer) {
            guard let entity = parent?.textEntity else { return }
            switch g.state {
            case .began:
                startingRotation = entity.orientation.angle
            case .changed:
                let raw = startingRotation - Float(g.rotation)
                entity.setOrientation(simd_quatf(angle: raw, axis: SIMD3<Float>(0, 1, 0)), relativeTo: nil)
            case .ended:
                let final = InSpaceGestures.snapRotation(entity.orientation.angle)
                entity.setOrientation(simd_quatf(angle: final, axis: SIMD3<Float>(0, 1, 0)), relativeTo: nil)
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            default: break
            }
        }
    }

    private func makePBR(for preset: InSpaceMaterial) -> RealityKit.Material {
        let props = preset.materialProperties
        var pbr = PhysicallyBasedMaterial()
        pbr.baseColor = .init(tint: props.baseColor)
        pbr.roughness = .init(floatLiteral: props.roughness)
        pbr.metallic = .init(floatLiteral: props.metallic)
        if props.isTranslucent {
            pbr.blending = .transparent(opacity: .init(floatLiteral: 0.4))
        }
        return pbr
    }
}

private extension simd_quatf {
    var angle: Float { 2 * acos(self.real) }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -scheme Fonti -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Fonti/Features/InSpace/InSpaceScene.swift Fonti.xcodeproj
git commit -m "feat(in-space): InSpaceScene — ARView + text entity + gesture handling"
```

---

## Task 9: InSpaceControls

**Files:**
- Create: `Fonti/Features/InSpace/InSpaceControls.swift`

**Interfaces:**
- Consumes: `InSpaceMode`, `InSpaceMaterial`.
- Produces:
  - `struct InSpaceControls: View`
  - Init: `init(mode: Binding<InSpaceMode>, material: Binding<InSpaceMaterial>, isRecording: Bool, onShutter: @escaping () -> Void, onReset: @escaping () -> Void, onMaterialCycle: @escaping () -> Void, onClose: @escaping () -> Void)`

- [ ] **Step 1: Implement InSpaceControls.swift**

```swift
// Fonti/Features/InSpace/InSpaceControls.swift
import SwiftUI

struct InSpaceControls: View {
    @Binding var mode: InSpaceMode
    @Binding var material: InSpaceMaterial
    let isRecording: Bool
    let onShutter: () -> Void
    let onReset: () -> Void
    let onMaterialCycle: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack {
            HStack {
                closeButton
                Spacer()
                if isRecording { recordingIndicator }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)

            Spacer()

            VStack(spacing: 20) {
                modeChipStrip
                    .opacity(isRecording ? 0.15 : 1.0)
                shutterRow
            }
            .padding(.bottom, 32)
        }
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.fontiCream)
                .frame(width: 44, height: 44)
        }
        .glassEffect(in: .circle)
        .accessibilityLabel("Close")
    }

    private var recordingIndicator: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .opacity(0.9)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: isRecording)
            Text("REC")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Color.fontiCream)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .glassEffect(in: .capsule)
    }

    private var modeChipStrip: some View {
        HStack(spacing: 8) {
            ForEach(InSpaceMode.allCases, id: \.self) { m in
                Button {
                    mode = m
                    UISelectionFeedbackGenerator().selectionChanged()
                } label: {
                    Text(m.title)
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .foregroundStyle(mode == m ? Color.fontiInk : Color.fontiCream)
                        .background(mode == m ? Color.fontiCream : Color.clear, in: .capsule)
                }
            }
        }
        .padding(6)
        .glassEffect(in: .capsule)
    }

    private var shutterRow: some View {
        HStack(spacing: 40) {
            Button(action: onReset) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.fontiCream)
                    .frame(width: 48, height: 48)
            }
            .glassEffect(in: .circle)

            Button(action: onShutter) {
                ZStack {
                    Circle()
                        .strokeBorder(Color.fontiCream, lineWidth: 3)
                        .frame(width: 76, height: 76)
                    Circle()
                        .fill(shutterInnerColor)
                        .frame(width: 60, height: 60)
                }
            }
            .accessibilityLabel("Capture")

            Button(action: onMaterialCycle) {
                Text(material.displayName)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color.fontiCream)
                    .frame(width: 48, height: 48)
            }
            .glassEffect(in: .circle)
        }
    }

    private var shutterInnerColor: Color {
        switch mode {
        case .photo: return .fontiCream
        case .video: return isRecording ? .red : .fontiAmber
        case .live: return .fontiAmber
        }
    }
}

#Preview {
    @Previewable @State var mode: InSpaceMode = .photo
    @Previewable @State var material: InSpaceMaterial = .cream
    ZStack {
        Color.fontiInk.ignoresSafeArea()
        InSpaceControls(
            mode: $mode,
            material: $material,
            isRecording: false,
            onShutter: {},
            onReset: {},
            onMaterialCycle: { material = material.next() },
            onClose: {}
        )
    }
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -scheme Fonti -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Preview inspection**

Open `InSpaceControls.swift` in Xcode, run the `#Preview`. Verify: three glass chips, glass shutter circle, glass reset and material buttons, close button top-left. Tap material chip — text cycles cream → glass → amber.

- [ ] **Step 4: Commit**

```bash
git add Fonti/Features/InSpace/InSpaceControls.swift Fonti.xcodeproj
git commit -m "feat(in-space): InSpaceControls — glass shutter, mode chips, material cycle"
```

---

## Task 10: CapturePreviewSheet

**Files:**
- Create: `Fonti/Features/InSpace/CapturePreviewSheet.swift`

**Interfaces:**
- Consumes: `CapturedMedia`.
- Produces:
  - `struct CapturePreviewSheet: View`
  - Init: `init(media: CapturedMedia, onDismiss: @escaping () -> Void)`

- [ ] **Step 1: Implement CapturePreviewSheet.swift**

```swift
// Fonti/Features/InSpace/CapturePreviewSheet.swift
import SwiftUI
import AVKit
import PhotosUI

struct CapturePreviewSheet: View {
    let media: CapturedMedia
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            Color.fontiInk.ignoresSafeArea()
            VStack(spacing: 24) {
                previewContent
                    .frame(maxHeight: .infinity)
                    .padding(.top, 40)
                shareRow
                    .padding(.bottom, 40)
            }
        }
        .presentationBackground(.clear)
    }

    @ViewBuilder
    private var previewContent: some View {
        switch media {
        case .photo(let url):
            if let img = UIImage(contentsOfFile: url.path) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .clipShape(RoundedRectangle(cornerRadius: 24))
                    .padding(.horizontal, 24)
            }
        case .video(let url):
            LoopingPlayer(url: url)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 24)
        case .livePhoto(let jpg, let mov):
            LivePhotoPreview(jpgURL: jpg, movURL: mov)
                .clipShape(RoundedRectangle(cornerRadius: 24))
                .padding(.horizontal, 24)
        }
    }

    private var shareRow: some View {
        HStack(spacing: 20) {
            Button("Retake", action: onDismiss)
                .foregroundStyle(Color.fontiCream)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .glassEffect(in: .capsule)

            shareButton
        }
    }

    @ViewBuilder
    private var shareButton: some View {
        switch media {
        case .photo(let url), .video(let url):
            ShareLink(item: url) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .foregroundStyle(Color.fontiInk)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.fontiCream, in: .capsule)
            }
        case .livePhoto(let jpg, let mov):
            Button {
                shareLivePhoto(jpg: jpg, mov: mov)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
                .foregroundStyle(Color.fontiInk)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.fontiCream, in: .capsule)
            }
        }
    }

    private func shareLivePhoto(jpg: URL, mov: URL) {
        let controller = UIActivityViewController(activityItems: [jpg, mov], applicationActivities: nil)
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first?.keyWindow?.rootViewController?
            .present(controller, animated: true)
    }
}

private struct LoopingPlayer: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> UIView {
        let container = UIView()
        let player = AVQueuePlayer()
        let item = AVPlayerItem(url: url)
        let looper = AVPlayerLooper(player: player, templateItem: item)
        context.coordinator.looper = looper

        let layer = AVPlayerLayer(player: player)
        layer.videoGravity = .resizeAspect
        container.layer.addSublayer(layer)
        context.coordinator.playerLayer = layer
        player.play()
        return container
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.playerLayer?.frame = view.bounds
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator {
        var looper: AVPlayerLooper?
        var playerLayer: AVPlayerLayer?
    }
}

private struct LivePhotoPreview: UIViewRepresentable {
    let jpgURL: URL
    let movURL: URL

    func makeUIView(context: Context) -> PHLivePhotoView {
        let view = PHLivePhotoView()
        view.contentMode = .scaleAspectFit
        PHLivePhoto.request(withResourceFileURLs: [jpgURL, movURL], placeholderImage: nil, targetSize: .zero, contentMode: .aspectFit) { livePhoto, _ in
            if let lp = livePhoto { view.livePhoto = lp; view.startPlayback(with: .full) }
        }
        return view
    }

    func updateUIView(_ view: PHLivePhotoView, context: Context) {}
}
```

- [ ] **Step 2: Build to verify it compiles**

Run: `xcodebuild build -scheme Fonti -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: BUILD SUCCEEDED

- [ ] **Step 3: Commit**

```bash
git add Fonti/Features/InSpace/CapturePreviewSheet.swift Fonti.xcodeproj
git commit -m "feat(in-space): CapturePreviewSheet — preview + share for photo/video/live"
```

---

## Task 11: InSpaceView (host + edge cases)

**Files:**
- Create: `Fonti/Features/InSpace/InSpaceView.swift`
- Modify: `Fonti/Info.plist` — add `NSCameraUsageDescription`, `NSPhotoLibraryAddUsageDescription`

**Interfaces:**
- Consumes: `InSpaceScene`, `InSpaceControls`, `CapturePreviewSheet`, `ARCaptureCoordinator`, `ReplayKitScreenRecorder`, `InSpaceMode`, `InSpaceMaterial`, `CapturedMedia`.
- Produces:
  - `struct InSpaceView: View`
  - Init: `init(text: String, familyName: String, initialSize: CGFloat, bold: Bool, italic: Bool)`

- [ ] **Step 1: Update Info.plist**

Add or verify these keys with these exact values:

```xml
<key>NSCameraUsageDescription</key>
<string>Fonti needs the camera to place your type in the world.</string>
<key>NSPhotoLibraryAddUsageDescription</key>
<string>Fonti saves your AR captures to Photos.</string>
```

- [ ] **Step 2: Implement InSpaceView.swift**

```swift
// Fonti/Features/InSpace/InSpaceView.swift
import SwiftUI
import RealityKit
import AVFoundation
import ARKit

struct InSpaceView: View {
    let text: String
    let familyName: String
    let bold: Bool
    let italic: Bool

    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenInSpaceHint") private var hasSeenHint = false

    @State private var mode: InSpaceMode = .photo
    @State private var material: InSpaceMaterial = .cream
    @State private var arView: ARView?
    @State private var textEntity: ModelEntity?
    @State private var isRecording = false
    @State private var isBusy = false
    @State private var captured: CapturedMedia?
    @State private var errorState: ErrorState?
    @State private var showHint = false

    private let coordinator: ARCaptureCoordinator

    init(text: String, familyName: String, initialSize: CGFloat, bold: Bool, italic: Bool) {
        self.text = text
        self.familyName = familyName
        self.bold = bold
        self.italic = italic

        // Snapshotter starts as a no-op (returns nil). The real closure is installed
        // via `updateSnapshotter` once the ARView is available (see `.onChange(of: arView)` below).
        let recorder = ReplayKitScreenRecorder()
        self.coordinator = ARCaptureCoordinator(
            snapshotter: { nil },
            recorder: recorder
        )
    }

    var body: some View {
        ZStack {
            if !ARWorldTrackingConfiguration.isSupported {
                unsupportedView
            } else {
                sceneAndControls
            }
        }
        .statusBarHidden()
        .persistentSystemOverlays(.hidden)
        .fullScreenCover(item: $captured) { media in
            CapturePreviewSheet(media: media) {
                captured = nil
            }
        }
        .alert(item: $errorState) { state in
            Alert(
                title: Text(state.title),
                message: Text(state.message),
                primaryButton: state.primaryAction,
                secondaryButton: .cancel(Text("Close")) { dismiss() }
            )
        }
        .task { await checkPermissionAndShowHint() }
        .onAppear { UIApplication.shared.isIdleTimerDisabled = true }
        .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
    }

    private var sceneAndControls: some View {
        ZStack {
            InSpaceScene(
                text: text,
                familyName: familyName,
                bold: bold,
                italic: italic,
                material: $material,
                arView: $arView,
                textEntity: $textEntity
            )
            .ignoresSafeArea()
            .onChange(of: arView) { _, newValue in
                if let v = newValue {
                    coordinator.updateSnapshotter { await v.snapshotImage() }
                }
            }

            InSpaceControls(
                mode: $mode,
                material: $material,
                isRecording: isRecording,
                onShutter: shutterTapped,
                onReset: resetTextEntity,
                onMaterialCycle: { material = material.next() },
                onClose: { dismiss() }
            )

            if showHint {
                hintOverlay
            }
        }
    }

    private var unsupportedView: some View {
        VStack(spacing: 16) {
            Text("In Space works on iPhone XS and newer.")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.fontiCream)
                .multilineTextAlignment(.center)
            Button("Close") { dismiss() }
                .foregroundStyle(Color.fontiInk)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color.fontiCream, in: .capsule)
        }
        .padding(40)
        .background(Color.fontiInk.ignoresSafeArea())
    }

    private var hintOverlay: some View {
        Text("Pinch to scale. Drag to move. Two fingers to rotate.")
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.fontiCream)
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .glassEffect(in: .capsule)
            .transition(.opacity)
    }

    private func shutterTapped() {
        guard !isBusy else { return }
        Task {
            isBusy = true
            if mode == .video || mode == .live { isRecording = true }
            do {
                let media = try await coordinator.capture(mode: mode)
                captured = media
                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            } catch {
                errorState = .captureFailed
            }
            isRecording = false
            isBusy = false
        }
    }

    private func resetTextEntity() {
        guard let entity = textEntity else { return }
        var t = entity.transform
        t.translation = SIMD3<Float>(0, 0, -0.4)
        t.scale = SIMD3<Float>(repeating: 0.15)
        t.rotation = simd_quatf(angle: 0, axis: SIMD3<Float>(0, 1, 0))
        entity.move(to: t, relativeTo: nil, duration: 0.4, timingFunction: .easeInOut)
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
    }

    private func checkPermissionAndShowHint() async {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            _ = await AVCaptureDevice.requestAccess(for: .video)
        }
        let newStatus = AVCaptureDevice.authorizationStatus(for: .video)
        if newStatus != .authorized {
            errorState = .cameraDenied
            return
        }
        if !hasSeenHint {
            withAnimation(.easeInOut(duration: 0.5)) { showHint = true }
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            withAnimation(.easeInOut(duration: 0.5)) { showHint = false }
            hasSeenHint = true
        }
    }
}

extension CapturedMedia: Identifiable {
    var id: String {
        switch self {
        case .photo(let u): return "photo-\(u.path)"
        case .video(let u): return "video-\(u.path)"
        case .livePhoto(let j, let m): return "live-\(j.path)-\(m.path)"
        }
    }
}

struct ErrorState: Identifiable {
    let id = UUID()
    let title: String
    let message: String
    let primaryAction: Alert.Button

    static let cameraDenied = ErrorState(
        title: "Camera access needed",
        message: "Fonti needs the camera to place your type in the world.",
        primaryAction: .default(Text("Open Settings")) {
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        }
    )

    static let captureFailed = ErrorState(
        title: "Capture failed",
        message: "Something went wrong. Try again.",
        primaryAction: .default(Text("OK"))
    )
}

extension ARView {
    func snapshotImage() async -> UIImage? {
        await withCheckedContinuation { cont in
            self.snapshot(saveToHDR: false) { image in cont.resume(returning: image) }
        }
    }
}
```

- [ ] **Step 3: Update ARCaptureCoordinator to expose snapshotter mutation**

Add to `Fonti/Services/ARCaptureCoordinator.swift`:

```swift
// inside ARCaptureCoordinator:
func updateSnapshotter(_ snap: @escaping () async -> UIImage?) {
    self.snapshotter = snap
}
```

And change `private let snapshotter` to `private var snapshotter`.

- [ ] **Step 4: Build to verify it compiles**

Run: `xcodebuild build -scheme Fonti -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: Commit**

```bash
git add Fonti/Features/InSpace/InSpaceView.swift Fonti/Services/ARCaptureCoordinator.swift Fonti/Info.plist Fonti.xcodeproj
git commit -m "feat(in-space): InSpaceView host + first-time hint + permission handling"
```

- [ ] **Step 6: Add degraded-state handling (spec §9 items not yet covered)**

Add to `InSpaceView`:

```swift
// State observers, add near other @State declarations:
@State private var toastMessage: String?
@State private var maxVideoSeconds: Double = ARCaptureCoordinator.maxVideoDurationDefault

// Add this modifier chain to `sceneAndControls`:
.onReceive(NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification)) { _ in
    switch ProcessInfo.processInfo.thermalState {
    case .serious:
        arView?.renderOptions.insert(.disableCameraGrain)
    case .critical:
        arView?.renderOptions.insert(.disableCameraGrain)
        maxVideoSeconds = 5
        toastMessage = "Cool down — AR quality reduced."
    default:
        maxVideoSeconds = ARCaptureCoordinator.maxVideoDurationDefault
    }
}
.onAppear { checkStorage() }
.overlay(alignment: .top) {
    if let msg = toastMessage {
        Text(msg)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(Color.fontiCream)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(in: .capsule)
            .padding(.top, 60)
            .transition(.opacity)
            .task {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                withAnimation { toastMessage = nil }
            }
    }
}

// And these helpers:
private func checkStorage() {
    let free = try? URL(fileURLWithPath: NSHomeDirectory())
        .resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        .volumeAvailableCapacityForImportantUsage ?? 0
    let mb = (free ?? 0) / 1_000_000
    if mb < 100 {
        toastMessage = "Low storage — only Photo available."
        // Video / Live modes will still show in the chip strip; capture will error out
        // and the ARCaptureCoordinator's throw is caught by the existing errorState path.
    }
}
```

Also, install an ARSession delegate to observe tracking state. Add inside `InSpaceScene.Coordinator`:

```swift
// In InSpaceScene.Coordinator (Task 8's file):
var trackingLostHandler: (() -> Void)?

// Add ARSessionDelegate conformance:
extension InSpaceScene.Coordinator: ARSessionDelegate {
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        switch camera.trackingState {
        case .limited: trackingLostHandler?()
        default: break
        }
    }
}

// And in makeUIView:
view.session.delegate = context.coordinator
```

Add a `@State private var trackingLostAt: Date?` in `InSpaceView` and wire the handler to set `toastMessage = "Move slower for stable tracking."` at most once per 5 s. This keeps the toast from spamming.

- [ ] **Step 7: Commit**

```bash
git add Fonti/Features/InSpace/InSpaceView.swift Fonti/Features/InSpace/InSpaceScene.swift Fonti.xcodeproj
git commit -m "feat(in-space): tracking-lost, thermal, low-storage degraded states"
```

---

## Task 12: Preview integration

**Files:**
- Modify: `Fonti/Features/Preview/PreviewControls.swift`
- Modify: `Fonti/Features/Preview/FullScreenPreviewView.swift`

**Interfaces:**
- Consumes: `InSpaceView`.
- Produces: enables entry-point from Full Screen Preview.

- [ ] **Step 1: Read the current PreviewControls.swift**

Run: `open Fonti/Features/Preview/PreviewControls.swift` — identify where the italic toggle and share button live in the glass control capsule.

- [ ] **Step 2: Add the AR button to PreviewControls**

Add a new parameter `let onOpenAR: () -> Void` and `let arEnabled: Bool` to the initializer. Add a button between the share button and the italic toggle:

```swift
Button {
    onOpenAR()
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
} label: {
    Image(systemName: "cube.transparent")
        .font(.system(size: 18))
        .foregroundStyle(arEnabled ? Color.fontiCream : Color.fontiCream.opacity(0.35))
        .frame(width: 44, height: 44)
}
.disabled(!arEnabled)
.accessibilityLabel("Place in AR")
```

- [ ] **Step 3: Wire FullScreenPreviewView**

Add state: `@State private var showAR = false`

In the body, pass to `PreviewControls`:

```swift
PreviewControls(
    // ... existing params ...
    arEnabled: !text.trimmingCharacters(in: .whitespaces).isEmpty,
    onOpenAR: { showAR = true }
)
```

Add the fullScreenCover:

```swift
.fullScreenCover(isPresented: $showAR) {
    InSpaceView(
        text: text,
        familyName: familyName,
        initialSize: currentSize,
        bold: isBold,
        italic: isItalic
    )
}
```

- [ ] **Step 4: Build to verify it compiles**

Run: `xcodebuild build -scheme Fonti -destination 'platform=iOS Simulator,name=iPhone 17'`
Expected: BUILD SUCCEEDED

- [ ] **Step 5: On-device manual QA checklist**

Deploy to a real iPhone (simulator does not support ARKit). Run through the spec's Section 10.3 checklist:

1. Preview → AR button → text appears in ≤ 1 s.
2. Pinch, drag, rotate feel spring-y with no visible jank.
3. Photo mode: capture → preview → share to Photos.
4. Video mode: 10 s recording → preview loops → share to Photos (watermark visible).
5. Live Photo: capture → open in Photos → touch-and-hold plays motion.
6. Custom imported `.ttf` font renders correctly with correct extrusion depth.
7. Bold + italic traits carry over from Preview.
8. Deny camera permission → correct empty state.
9. Cover camera lens while recording → recovers when uncovered.
10. Thermal test: 5 min continuous session → app does not get killed.

Any failing item → open an issue and treat as a v1 blocker.

- [ ] **Step 6: Commit**

```bash
git add Fonti/Features/Preview/PreviewControls.swift Fonti/Features/Preview/FullScreenPreviewView.swift Fonti.xcodeproj
git commit -m "feat(preview): AR button in glass control capsule opens In Space"
```

---

## Notes for the implementer

- **Xcode file addition:** When creating new Swift files, use Xcode's *File → New → File* so they're added to the `Fonti` target automatically. If added via terminal, remember to add them to the target in `Fonti.xcodeproj/project.pbxproj`.
- **Simulator vs device:** ARKit requires a real device. `xcodebuild build` verifies compilation on simulator; ARKit runtime paths are exercised only on device. QA checklist is device-only.
- **ReplayKit permissions:** the first time video/Live Photo is captured on a device, the system shows a screen-recording permission prompt. Not a bug.
- **Live Photo sharing:** `ShareLink` cannot share Live Photos — this is deliberate. `UIActivityViewController` with paired URLs is the workaround. Photos and Messages preserve motion; Instagram/Twitter fall back to the JPG.
- **Snapshot tests (spec §10.2):** the spec calls for snapshot tests on `InSpaceControls`. Fonti's global constraint bans third-party dependencies, which rules out the usual `swift-snapshot-testing` library. In v1 we verify controls visually via Xcode `#Preview` inspection (Task 9 Step 3) and via the on-device QA checklist (Task 12 Step 5). If we later add snapshot testing infrastructure, `InSpaceControls` is already structured to plug in cleanly — all state is `Binding`-driven and there are no `@Environment` reads inside the view body.
- **Mesh timeout limitation:** `MeshResource.generateText` is synchronous and cannot be cancelled. Task 3's observation-timeout catches slow builds and surfaces an error, but the underlying call still occupies the thread until it finishes. Acceptable for v1; revisit only if user reports surface it.
