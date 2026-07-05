# In Space — Design Spec

**Date:** 2026-07-05
**Status:** Awaiting user review
**Feature name:** In Space
**Parent app:** Fonti (iOS 26+, SwiftUI, Liquid Glass)

---

## 1. Concept

*In Space* extends Fonti's Full Screen Preview with an augmented-reality mode. The user's current font, text, and size lift off the screen and appear as an extruded 3D object floating in the real world. They can walk around it, resize and rotate it with gestures, and capture the moment as a photo, video, or Live Photo — each output carries a small "FONTI" wordmark. The primary goal is to produce short, striking content that designers naturally share, which in turn drives App Store discovery for a v1.1 app already generating organic downloads.

Fonti already turns each font into a 1080×1080 specimen. *In Space* turns each font into a physical-feeling object in the world — the next level of shareable output.

---

## 2. Goals & non-goals

### Goals

- Give designers a one-tap way to place any Fonti-previewed text in 3D space and share it as photo, video, or Live Photo.
- Preserve font fidelity — including custom `.ttf`/`.otf` fonts imported in v1.1.
- Ship with a small, always-on "FONTI" wordmark on outputs to seed organic acquisition.
- Feel premium — matches Fonti's dark, cream-and-amber, glass-heavy language.

### Non-goals (v1)

- Plane detection / surface anchoring. Text floats in world space.
- Multiple text objects in a single scene.
- Free material customization beyond three curated presets (cream / glass / amber).
- Editing text or font from within AR (user backs out to Preview to change these).
- Landscape orientation.

---

## 3. User flow (golden path)

1. User opens the Full Screen Preview for a font (e.g., `New York Extra Large`) and types their text (e.g., *morning coffee*).
2. Taps the new **AR icon** in the glass control capsule.
3. Camera view launches full-screen; extruded 3D text materialises ~40 cm in front of the camera with a spring-scale entrance (0 → 1 over 0.4 s).
4. User pinches to scale, drags to reposition, two-finger rotates. Text is world-anchored — walking around it works.
5. User selects a capture **mode chip**: `Photo`, `Video`, or `Live`.
6. User taps the shutter. Depending on mode:
   - **Photo:** flash + snapshot; preview sheet slides up.
   - **Video:** tap-to-start, tap-to-stop, up to 15 s auto-cap. Controls fade to 15 % opacity during recording; a small red dot pulses top-right.
   - **Live:** "3-2-1" countdown, then a 3 s capture with the middle frame as the key.
7. Preview sheet shows the result with a `Share` button (`ShareLink` for photo/video, `UIActivityViewController` for Live Photo).
8. User posts to Instagram / TikTok / Threads / Messages.

---

## 4. Architecture

### 4.1 New files

```
Fonti/
├── Features/
│   └── InSpace/
│       ├── InSpaceView.swift          // SwiftUI screen host, presented via fullScreenCover
│       ├── InSpaceScene.swift         // RealityView + entity management
│       ├── InSpaceControls.swift      // shutter, mode chip, material chip, reset, close
│       ├── InSpaceGestures.swift      // pinch scale, drag translate, two-finger rotate
│       └── CapturePreviewSheet.swift  // post-capture preview + share
├── Services/
│   ├── ARTextMeshBuilder.swift        // (text, CTFont, extrusion, material) -> ModelEntity
│   ├── ARCaptureCoordinator.swift     // orchestrates photo / video / Live Photo
│   ├── ScreenRecorder.swift           // ReplayKit RPScreenRecorder wrapper
│   └── LivePhotoComposer.swift        // pairs .jpg + .mov via matching content identifier
├── Models/
│   └── CapturedMedia.swift            // enum { photo(URL), video(URL), livePhoto(jpg, mov) }
└── Theme/
    └── WatermarkOverlay.swift         // reusable "FONTI" wordmark, composited into outputs
```

### 4.2 Integration point

`Fonti/Features/Preview/PreviewControls.swift` receives one new glass icon button (`cube.transparent`) between the share button and the italic toggle. Tapping presents `InSpaceView(font:, text:, size:, bold:, italic:)` via `.fullScreenCover`. Font family, text, size, and traits pass down as parameters — no new global stores are introduced.

### 4.3 Key architectural decisions

1. **`RealityView` over `ARView`.** iOS 26+ gives us the SwiftUI-native API; state binding is direct and gestures compose cleanly without `UIViewRepresentable`.
2. **World tracking, no plane detection.** `ARWorldTrackingConfiguration` is used for stable world-space anchoring, but plane detection is disabled. Text is placed once at world position `(0, 0, -0.4 m)` when the scene loads; the user walks around it.
3. **Three capture paths, one coordinator.** `ARCaptureCoordinator` presents a single interface to the view layer (`capture(mode:) async throws -> CapturedMedia`) and hides the mode-specific plumbing.
4. **`MeshResource.generateText` for text geometry.** Extrusion depth of `0.02 m`. Environment texturing (`.automatic`) supplies image-based lighting from the camera feed — no manual lights.
5. **ReplayKit + `AVAssetWriter` for video.** ReplayKit captures the screen; `AVAssetWriter` re-encodes with a `CALayer` watermark overlay burned in. Adds ~2–3 s post-processing per clip, shown as a preview-sheet loading state.
6. **Live Photo via content-identifier pairing.** `LivePhotoComposer` embeds a matching UUID in the JPG's `kCGImagePropertyMakerAppleDictionary` and the MOV's `com.apple.quicktime.content.identifier` metadata, then hands the paired URLs to `PHAssetCreationRequest`.
7. **Reuse existing font infrastructure.** `SystemFontProvider` and `FontTraitSupport` already resolve system and imported fonts with correct traits — custom `.ttf`/`.otf` fonts from v1.1 work in AR with zero extra work.

### 4.4 Materials (three curated presets)

| Preset | Type | Base color | Roughness | Metallic |
|---|---|---|---|---|
| Cream | `PhysicallyBasedMaterial` | `fontiCream` | 0.85 | 0.0 |
| Glass | `PhysicallyBasedMaterial` (translucent) | white 40 % | 0.05 | 0.0 |
| Amber | `PhysicallyBasedMaterial` | `fontiAmber` | 0.25 | 1.0 |

Material chip cycles Cream → Glass → Amber → Cream on tap, with a selection haptic and the same spring shape-morph used elsewhere in the app.

---

## 5. Data model

```swift
enum CapturedMedia {
    case photo(URL)
    case video(URL)
    case livePhoto(jpgURL: URL, movURL: URL)
}

enum InSpaceMode {
    case photo, video, live
}

enum InSpaceMaterial: CaseIterable {
    case cream, glass, amber
}
```

No `SwiftData` model is added. All AR-session state is transient and lives inside `InSpaceView`; captured media is passed to `CapturePreviewSheet` and released when the sheet dismisses. First-time onboarding hint uses `@AppStorage("hasSeenInSpaceHint")`.

---

## 6. Text mesh pipeline

```
Font family + traits + size + text
        │
        ▼
CTFont resolution
  (SystemFontProvider + FontTraitSupport;
   custom-imported fonts already registered in v1.1)
        │
        ▼
MeshResource.generateText(
    text,
    extrusionDepth: 0.02,
    font: .init(ctFont),
    containerFrame: .zero,       // auto-size
    alignment: .center,
    lineBreakMode: .byWordWrapping
)
        │
        ▼
ModelEntity(mesh:, materials: [selectedMaterial])
        │
        ▼
Pivot corrected to geometric center
Placed at world position (0, 0, -0.4)
Initial scale 0.15 with spring entrance (0 → 1 over 0.4 s, overshoot to 1.05, settle)
```

Font trait handling: if bold or italic is on in Preview, resolve via `UIFontDescriptor.withSymbolicTraits(...)`. Fonts that do not support the requested trait fall back to the plain family — matching the existing Preview behavior of dimming unsupported toggles.

Timeout: `MeshResource.generateText` is wrapped in a 2 s timeout. On failure show the "This font doesn't work in AR yet" toast and dismiss.

---

## 7. Capture pipelines

### 7.1 Photo

```swift
arView.snapshot(saveToHDR: false) { image in
    guard let image else { return }
    let watermarked = WatermarkOverlay.compose(over: image)
    coordinator.emit(.photo(watermarked))
}
```

Shutter animates a subtle white flash and triggers a medium haptic. Preview sheet slides up immediately.

### 7.2 Video (up to 15 s)

```
User taps shutter (mode = Video)
        │
        ▼
Controls fade to 15 % opacity; small red dot appears top-right
        │
        ▼
RPScreenRecorder.shared().startRecording()
        │
        ▼
User taps shutter again (or 15 s elapses)
        │
        ▼
stopRecording(handler:) → temp .mov URL
        │
        ▼
AVAssetWriter re-encodes with CALayer overlay:
  - Watermark burned in
  - Optional subtle vignette + color grade
        │
        ▼
coordinator.emit(.video(finalURL))
```

`UIApplication.shared.isIdleTimerDisabled` is set to `true` during AR to prevent the screen sleeping mid-record.

### 7.3 Live Photo (3 s)

```
User taps shutter (mode = Live)
        │
        ▼
Countdown overlay: "3... 2... 1..." (1.5 s)
        │
        ▼
Simultaneously:
  - Start ReplayKit recording (target duration: 3 s)
  - Schedule arView.snapshot() at t = 1.5 s (middle of clip)
        │
        ▼
At t = 1.5 s: capture JPG (key frame)
At t = 3.0 s: stop video
        │
        ▼
LivePhotoComposer:
  - Generate content identifier UUID
  - Embed identifier in JPG via kCGImagePropertyMakerAppleDictionary
  - Embed identifier in MOV via AVMetadataItem
    ("com.apple.quicktime.content.identifier")
  - Save paired URLs to temp dir
        │
        ▼
PHPhotoLibrary.performChanges {
    PHAssetCreationRequest with .photo + .pairedVideo resources
}
        │
        ▼
coordinator.emit(.livePhoto(jpgURL, movURL))
```

Sharing: iOS's `ShareLink` does not natively share Live Photos, so we present `UIActivityViewController` with the paired URLs. Messages and Photos preserve motion; Instagram and Twitter fall back to the JPG. This is documented in-app as expected behavior.

### 7.4 Watermark overlay

`WatermarkOverlay` renders `FONTI` in caps, `fontiCream` at 70 % opacity, 32 pt, bottom-right, 24 pt inset. Composited into:

- **Photo / Live Photo key JPG:** via `ImageRenderer` at 3× scale.
- **Video:** as a `CALayer` in the `AVAssetWriter` output composition.

---

## 8. UI

### 8.1 Layout (portrait-locked)

```
┌─────────────────────────────────────┐
│  ✕                            ● REC │  ← close btn (glass), recording dot
│                                     │
│                                     │
│                                     │
│                                     │
│            MORNING                  │  ← extruded 3D text, world-anchored
│            COFFEE                   │
│                                     │
│                                     │
│                                     │
│                                     │
│                                     │
│         Photo   Video   Live        │  ← glass mode chip strip
│                                     │
│      ⟲       ●              ◐      │  ← reset, shutter, material cycle
│                                     │
│      pinch · drag · rotate          │  ← first-time hint, fades in 4 s
└─────────────────────────────────────┘
```

### 8.2 Gestures on the text

| Gesture | Action | Notes |
|---|---|---|
| Pinch | Scale (0.02× to 5×) | Springs at bounds. Selection haptic on each 0.5× tick. |
| Drag (1 finger) | Translate parallel to camera plane | Fixed depth — feels controllable, not free 3D. |
| Rotation (2 fingers) | Y-axis spin | Snaps to nearest 15° with light haptic. |
| Reset button | Recenter text at `(0, 0, -0.4)`, scale 1.0 | Spring animation, medium haptic. |
| Long-press on text | (reserved for future) | No action in v1. |
| Tap on empty space | No action | Prevents accidental deselection. |

### 8.3 Mode chip strip

Three glass segments: `Photo | Video | Live`. Selected chip is filled with `fontiCream` background, ink text. Selection haptic on change. The active mode determines shutter behavior — matches the iOS Camera app mental model.

### 8.4 First-time onboarding

A single glass toast, gated by `@AppStorage("hasSeenInSpaceHint")`:

> "Pinch to scale. Drag to move. Two fingers to rotate."

Fades in over 0.5 s, sits for 4 s, fades out. Dismisses immediately on any gesture. No modal, no coach marks.

---

## 9. Edge cases

| Case | Handling |
|---|---|
| Camera permission denied | Sheet with cream illustration + copy *"Fonti needs the camera to place your type in the world."* + `Open Settings` button. Visual language matches existing onboarding cards. |
| AR world tracking unsupported | Card: *"In Space works on iPhone XS and newer."* Close returns to Preview. |
| Tracking lost mid-session | Toast: *"Move slower for stable tracking."* Auto-dismiss after 3 s. Text stays where it is. |
| Recording interrupted (call, alarm) | If ≥ 1 s captured, save what we have; else discard. Toast: *"Recording ended."* |
| Low storage (< 100 MB free) | Video and Live chips greyed with warning icon. Photo still works. |
| Photo Library permission denied for Live Photo | Fall back to sharing paired URLs via `UIActivityViewController` from app sandbox. |
| Thermal state `.serious` | Reduce render quality on the `RealityView`. |
| Thermal state `.critical` | Toast: *"Cool down — AR quality reduced."* Also drop max video length to 5 s. |
| Preview text is empty | The AR button on `PreviewControls` is disabled + greyed (matches existing bold/italic pattern). |
| Font meshing hangs (rare emoji / CJK cases) | 2 s timeout on `MeshResource.generateText`. On failure: *"This font doesn't work in AR yet."* + close. |

---

## 10. Testing

### 10.1 Unit tests

- `ARTextMeshBuilder`: given (text, font, extrusion) returns a `ModelEntity` with expected bounds; unsupported traits fall back to plain family.
- `LivePhotoComposer`: output JPG and MOV each contain the matching content identifier in their respective metadata dictionaries.
- `WatermarkOverlay.compose(over:)`: deterministic (same input image → identical pixel hash).
- `CapturedMedia`: enum correctly routes each case to the appropriate share sheet item.

### 10.2 Snapshot tests

- `InSpaceControls` in light + dark, portrait, each of the three modes selected.

### 10.3 On-device manual QA checklist

1. Preview → AR button → text appears in ≤ 1 s.
2. Pinch, drag, rotate all feel spring-y with no visible jank.
3. Photo mode: capture → preview → share to Photos.
4. Video mode: 10 s recording → preview loops → share to Photos (watermark visible in shared file).
5. Live Photo: capture → open in Photos → touch-and-hold plays motion.
6. Custom imported `.ttf` font renders correctly with correct extrusion depth.
7. Bold + italic traits carry over from Preview.
8. Deny camera permission → correct empty state.
9. Cover camera lens while recording → recovers when uncovered.
10. Thermal test: 5 min continuous session → app does not get killed.

---

## 11. Device requirements

- iOS 26.0+
- iPhone with A12 Bionic or newer (world tracking support).
- Camera and (for Live Photo library save) Photos permissions.
- Portrait orientation only.

---

## 12. Out of scope for this spec

The following related items were flagged in the same conversation but are **not** part of *In Space* v1. Each should get its own design pass:

- **Growth toolkit:** in-app rating prompt via `SKStoreReviewController`; occasional push notifications for daily-font or feature highlights. Bundled together because they overlap in intent.
- **Type Battle:** side-by-side font comparison as a shareable image.
- **Specimen Poster / Story:** 9:16 story-format specimen export.
- **Home-screen widget:** curated daily font.

*In Space* ships first because it is the single highest-leverage growth artifact for a font previewer app.
