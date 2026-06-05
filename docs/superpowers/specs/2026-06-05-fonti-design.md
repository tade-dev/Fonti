# Fonti — Design Spec

**Date:** 2026-06-05
**Status:** Approved for implementation planning
**Tagline:** Find your type.

---

## 1. Concept

Fonti is a SwiftUI font previewer for designers. The user types or pastes any text and instantly sees it rendered across every system font in a scrollable, gallery-like list. Each font is a card; users can save favourites and open any font into a full-screen preview with size, weight, and share controls.

The aesthetic is dark, premium, design-studio — not utilitarian. Liquid Glass is the dominant material throughout the UI: cards, buttons, controls, and the system tab bar.

## 2. Branding

| Token | Value | Use |
|---|---|---|
| `fontiInk` | `#0D0D0D` | App background |
| `fontiCream` | `#F5F0E8` | Primary text, glyphs |
| `fontiAmber` | `#E8A040` | Accent — heart-saved, slider thumb, active toggle |

Voice: short, confident, lowercase-friendly. Copy is minimal.

## 3. Technical foundation

- **Platform:** iOS 26+ (required for native Liquid Glass).
- **UI:** SwiftUI throughout. UIKit only at the `UIFont.familyNames` source and inside `ImageRenderer`'s backing path (transparent to us).
- **Persistence:** SwiftData.
- **Dependencies:** none. Adding any third-party package requires user approval.

## 4. Folder structure

```
Fonti/
├── App/
│   ├── FontiApp.swift              // @main, attaches SwiftData modelContainer
│   └── RootView.swift              // TabView host (Browse + Saved)
├── Theme/
│   ├── FontiColors.swift           // Color extensions: .fontiInk, .fontiCream, .fontiAmber
│   └── FontiTypography.swift       // shared label / caption text styles
├── Models/
│   └── SavedFont.swift             // @Model SwiftData class
├── Services/
│   ├── SystemFontProvider.swift    // UIFont.familyNames → [FontFamily]
│   └── SpecimenRenderer.swift      // ImageRenderer-based PNG export
├── Features/
│   ├── Browse/
│   │   ├── BrowseView.swift        // sticky input + LazyVStack of FontCard
│   │   ├── BrowseModel.swift       // @Observable: input text, fonts list
│   │   └── FontCard.swift          // glass card cell
│   ├── Preview/
│   │   ├── FullScreenPreviewView.swift
│   │   └── PreviewControls.swift   // size slider, bold/italic toggles, share
│   └── Saved/
│       ├── SavedFontsView.swift    // LazyVGrid + empty state
│       └── SavedFontCard.swift     // compact 2-col grid card
└── Assets.xcassets                 // AccentColor (amber), AppIcon
```

## 5. Data model

```swift
import SwiftData

@Model
final class SavedFont {
    @Attribute(.unique) var familyName: String   // unique → idempotent saves
    var savedAt: Date

    init(familyName: String, savedAt: Date = .now) {
        self.familyName = familyName
        self.savedAt = savedAt
    }
}
```

The unique constraint makes the heart-tap a true toggle: insert if missing, delete if present, with no risk of duplicates.

## 6. Font source

```swift
struct FontFamily: Identifiable, Hashable {
    let id: String          // family name (e.g. "Georgia")
    let displayName: String
}

enum SystemFontProvider {
    static func families() -> [FontFamily] {
        UIFont.familyNames
            .filter { !$0.isEmpty && !$0.hasPrefix(".") }   // strip private UI fonts
            .sorted()
            .map { FontFamily(id: $0, displayName: $0) }
    }
}
```

The `.`-prefix filter is intentional — Apple uses dot-prefixed family names for private UI fonts (`.SF UI Text`, `.AppleSystemUIFont`) which should not appear in a designer-facing list. This goes beyond the original spec ("filter out fonts with empty names") and is part of this design.

`SystemFontProvider.families()` is called once at app start; results are cached on `BrowseModel`.

## 7. Navigation

```swift
TabView {
    Tab("Browse", systemImage: "textformat") {
        NavigationStack { BrowseView() }
    }
    Tab("Saved", systemImage: "heart") {
        NavigationStack { SavedFontsView() }
    }
}
```

- Native iOS 26 Liquid Glass tab bar — no custom chrome.
- Independent `NavigationStack` inside each tab so back-stacks don't cross.
- `FullScreenPreviewView` is pushed onto whichever stack the user came from.

## 8. Browse screen

### Layout

```
┌─────────────────────────────────┐
│ ◉ ━━━ Glass input bar ━━━      │ ← safeAreaInset(.top), sticks while scrolling
│   "Find your type."             │
├─────────────────────────────────┤
│ ┌─ Glass card ───────────────┐  │
│ │  Georgia                   │  │ ← user text, or family name when input empty
│ │                            │  │
│ │  GEORGIA            ♡      │  │ ← small-caps family label · heart button
│ └────────────────────────────┘  │
│ ┌─ Glass card ───────────────┐  │
│ │  Helvetica                 │  │
│ │  ...                       │  │
└─────────────────────────────────┘
```

### Components

- **Input bar**: `TextField(text: $model.input, axis: .vertical)` with `.lineLimit(1...3)`, placeholder `"Find your type."`, wrapped in a `.glassEffect(in: .capsule)` container, pinned via `safeAreaInset(edge: .top)`. Cream text.
- **List**: `ScrollView { LazyVStack(spacing: 14) { ForEach(model.fonts) { FontCard(family: $0, displayText: model.displayText(for: $0)) } } }`.
- **FontCard**:
  - **User text** (or family name if input empty) rendered in `.custom(family.id, size: 28)`, cream, `.lineLimit(2)`.
  - **Family name** in a small-caps tracking-1 label below.
  - **Heart button** top-right: `.buttonStyle(.glass)`, `systemImage: isSaved ? "heart.fill" : "heart"`, amber tint when saved, cream when not. Tap action: if a `SavedFont` with this `familyName` exists in the model context, delete it; otherwise insert a new one. The unique constraint on `familyName` guarantees this is idempotent.
  - **Whole card** is a `NavigationLink(value: family)` → `FullScreenPreviewView`.
  - `.glassEffect(in: .rect(cornerRadius: 22))`.

### `BrowseModel`

```swift
@Observable
final class BrowseModel {
    var input: String = ""
    let fonts: [FontFamily] = SystemFontProvider.families()

    func displayText(for family: FontFamily) -> String {
        input.isEmpty ? family.displayName : input
    }
}
```

The model is owned by `BrowseView` and passed into `FullScreenPreviewView` via the navigation destination so the preview shares the same input text.

### Default-text rule

When `model.input.isEmpty`, each card renders its own family name in that font ("Georgia" in Georgia, "Helvetica" in Helvetica, …). When the user types anything, all cards switch to the user's text via the crossfade animation below.

### Animations

| Trigger | Animation |
|---|---|
| Input text changes | Per-card crossfade: `Text(displayText).id(displayText).animation(.easeInOut(0.25), value: displayText)` |
| Card scrolls in/out of viewport | `.scrollTransition { content, phase in content.opacity(phase.isIdentity ? 1 : 0.3).scaleEffect(phase.isIdentity ? 1 : 0.96) }` |
| Heart fill toggle | `withAnimation(.snappy(duration: 0.25))` |

## 9. Full Screen Preview

### Layout

```
┌─────────────────────────────────┐
│ ← Georgia                       │ ← navigation title = family name
│                                 │
│                                 │
│      The quick brown fox        │ ← centered, large, font-rendered
│      jumps over the lazy dog    │
│                                 │
│                                 │
│ ┌─ Glass capsule controls ────┐ │
│ │ 12 ──●────────────── 96     │ │
│ │  [ B ]  [ I ]    [ Share ↑ ]│ │
│ └──────────────────────────────┘ │
└─────────────────────────────────┘
```

### Behavior

- Shares the input text with Browse via the same `BrowseModel` (or a parent observable).
- **Size slider**: 12...96 pt, default 48. Amber thumb tint.
- **Bold / Italic glass toggles**: `.buttonStyle(.glass)` with `.tint(.fontiAmber)` when active. **Always visible**; disabled (grayed) when the family does not support that trait. This is deliberate — avoids layout shift as the user switches fonts.

  Trait support is detected via:
  ```swift
  let desc = UIFontDescriptor(name: family, size: 0)
  let boldDesc = desc.withSymbolicTraits(.traitBold)
  let supportsBold = boldDesc != nil
      && UIFont(descriptor: boldDesc!, size: 0)
          .fontDescriptor.symbolicTraits.contains(.traitBold)
  ```

- **Share** calls `SpecimenRenderer.render(...)` and presents `ShareLink(item: Image(uiImage:), preview: SharePreview("Fonti — \(family)"))`.

## 10. Saved Fonts screen

### Layout

```
┌─────────────────────────────────┐
│ Saved                           │ ← navigation title
│                                 │
│ ┌──────────┐  ┌──────────┐     │
│ │ Georgia  │  │Helvetica │     │
│ │   Aa Bb  │  │   Aa Bb  │     │
│ └──────────┘  └──────────┘     │
│ ┌──────────┐  ┌──────────┐     │
│ │ ...      │  │ ...      │     │
└─────────────────────────────────┘
```

### Behavior

- `LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14)`.
- Each `SavedFontCard`:
  - Family name rendered in itself (size ~22).
  - `Aa Bb` specimen rendered in itself (size ~18).
  - `.glassEffect(in: .rect(cornerRadius: 22))`.
- Data: `@Query(sort: \SavedFont.savedAt, order: .reverse)` → most-recent first.
- Tap → push `FullScreenPreviewView(family:)`.
- **Swipe-to-delete only** via `.swipeActions(edge: .trailing)`. No long-press menu.
- **Insert / remove animation**: `.transition(.scale.combined(with: .opacity))` driven by SwiftData reactivity.

### Empty state

Single centered line, cream at 50% opacity, body font:

> **Heart a font to keep it here.**

No illustration, no CTA button. The quietness matches the gallery feel.

## 11. Image export — `SpecimenRenderer`

```swift
enum SpecimenRenderer {
    @MainActor
    static func render(
        family: String,
        text: String,
        size: CGFloat,
        bold: Bool,
        italic: Bool
    ) -> UIImage? {
        let view = SpecimenView(
            family: family, text: text, size: size,
            bold: bold, italic: italic
        )
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3
        renderer.proposedSize = .init(width: 1080, height: 1080)
        return renderer.uiImage
    }
}
```

`SpecimenView` is a SwiftUI view sized to 1080×1080 points (rendered at scale 3 for sharp export):

- `.fontiInk` background.
- User text rendered in chosen font (with bold/italic traits applied), cream, centered. **Rendered at the user's chosen point size** — the export canvas is large enough to give the text generous negative space, which suits the premium feel.
- Family name at bottom in small-caps cream label, fixed at 18pt.
- `FONTI` wordmark top-left, cream at 30% opacity, fixed at 14pt.

Uses SwiftUI's `ImageRenderer`, which wraps `UIGraphicsImageRenderer` internally — same output as direct `UIGraphicsImageRenderer` use, but stays inside SwiftUI per the project's "no UIKit unless necessary" rule.

## 12. App icon

- 1024×1024 PNG, single source asset; system applies the squircle mask.
- Background: `#0D0D0D` flat fill.
- Glyph: capital **F** in New York Large (Apple's serif system font) at roughly 70% of canvas, `#F5F0E8`, optically centered (slight left bias to balance the F's right-side empty space).
- Tinted-mode variant is out of scope for v1.

## 13. Performance

- `UIFont.familyNames` returns ~80–250 families. `LazyVStack` realizes only visible cards, so no special caching is needed.
- `SystemFontProvider.families()` runs once at app start.
- All renders happen on-demand inside SwiftUI; no preload pipeline.

## 14. Out of scope (v1)

- Font search / filter / category bar.
- iCloud sync of saved fonts.
- Custom font import — system fonts only.
- Tinted app icon variant.
- iPad split-view layout adjustments (the design works there but isn't tuned).
- Localization beyond the system default.

## 15. Implementation order

1. Project foundation — deployment target, theme tokens, `SavedFont` model, `SystemFontProvider`.
2. Root `TabView` + empty `BrowseView` / `SavedFontsView` shells.
3. Browse screen — input bar, `FontCard`, populating from provider, scroll behavior.
4. Heart-save flow — toggle, SwiftData wiring, animation.
5. Full Screen Preview — layout, slider, bold/italic detection and toggles.
6. `SpecimenRenderer` + `ShareLink` integration.
7. Saved screen — grid, empty state, swipe-to-delete.
8. App icon asset.
9. Polish pass — scroll transitions, crossfade, snappy heart spring.
