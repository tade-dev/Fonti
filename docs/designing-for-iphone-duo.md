# Fonti on iPhone Duo

Apple's iPhone Duo guidance reduced to what actually changes in this codebase.
Compiled 24 September 2026 against iOS 27.1 / Xcode 27.1 beta.

Web version: <https://claude.ai/code/artifact/b2d2e432-b310-4e20-b5f0-d109cc763bf9>

---

## 1. The SDK gate

Nothing else matters until this is right. Apple: build with the **iOS 27.1 SDK**.
Apps compiled against 27.0 or earlier "have limited functionality on dual-screen
devices" — confined to the space left of the status bar and camera, and never
reaching the inner display at all.

Xcode 27.1 is already on this machine (`~/Downloads/Xcode.app`, build 27A9269,
carrying `iPhoneSimulator27.1.sdk`). The active toolchain is 27.0, which is why
every screenshot so far shows a 386pt canvas on a 466pt display.

```sh
mv ~/Downloads/Xcode.app /Applications/Xcode-27.1.app
sudo xcode-select -s /Applications/Xcode-27.1.app/Contents/Developer
```

> **Shipping caveat.** 27.1 is beta. Apps built against a beta SDK cannot be
> submitted to the App Store — keep 27.0 for release builds until 27.1 ships.

---

## 2. Two displays

A hinge in the centre; each display has its own front-facing camera. The inner
panel is close to A-series paper proportions — aspect ratio **1.42**, within half
a percent of √2. Good for documents and two-pane layouts, awkward for 16:9 video.

| Display                     | Points      | Aspect    | Simulator framebuffer |
| --------------------------- | ----------- | --------- | --------------------- |
| Outer (closed, portrait)    | **466×678** | 1 : 1.455 | 1398×2034 @3×         |
| Inner (open, portrait)      | **669×951** | 1 : 1.422 | 2007×2853 @3×         |
| iPhone 17 Pro, for contrast | 393×852     | 1 : 2.168 | 1179×2556 @3×         |

Both panels are far squatter than any previous iPhone. The outer display is
normal phone *width* but 174pt shorter than a 17 Pro — which is exactly what
broke onboarding (see commit `ade59c4`).

---

## 3. Adapt by size class, never by device

The rule Apple repeats most. People hold the Duo folded like a book, flat on a
table, standing on edge. Don't design a layout per pose — let size classes carry it.

| State            | Horizontal  | Vertical    | Bars                |
| ---------------- | ----------- | ----------- | ------------------- |
| Outer, portrait  | compact     | regular     | vertical, trailing  |
| Outer, landscape | compact     | compact     | vertical, trailing  |
| Inner, portrait  | **regular** | **regular** | standard horizontal |
| Inner, landscape | **regular** | **regular** | vertical, trailing  |

The inner display is regular in **both** dimensions regardless of orientation —
it behaves like an iPad, which is why sidebars and split views belong there. It
also does **not** honour `UISupportedInterfaceOrientations`, so orientation-based
branching is dead code on that panel.

Don't reference the main screen on a dual-display device — ambiguous and being
deprecated. Read it from the scene: `window?.windowScene?.screen`.

---

## 4. Controls move to a vertical strip

The biggest visual change. Because the outer display is wider and shorter, the
system relocates toolbars, tab bars and navigation controls to a strip down the
**trailing edge**, preserving vertical space and keeping controls in thumb reach.
They stay there on the inner display in landscape, so the experience is
continuous as the device opens.

The strip carries, top to bottom: **Dynamic Island → status bar → toolbar → tab bar.**
That is the black column with the clock in it in every Fonti screenshot so far.

Standard system components get this for free. Fonti does not — see §8.

**Placement order**

- Top of the axis: primary navigation (Back, Close)
- Then prominent actions (Done)
- Remaining items keep original groupings; the system spaces top-bar from
  bottom-bar items automatically
- Items overflow **bottom to top**; reorder with `ToolbarItemVisibilityPriority`

**When space runs out.** Navigation-focused screens keep the tab bar and push
toolbar items to overflow (the default). Task-focused screens minimise the tab
bar to preserve toolbar actions. Controlled by `ToolbarVerticalCompressionBehavior`.

**Split View.** Two apps sharing the inner display each put controls on their own
*outer* edge — the left app's controls sit on the left. Don't hard-code trailing;
read `\.toolbarVerticalEdge` from the environment.

---

## 5. Reserved regions

Safe areas still apply, plus *reserved regions* — areas content avoids covering,
or that components adapt around.

- **Outer camera** — always present, expands into the Dynamic Island for Live
  Activities. An *occlusion* region.
- **Inner camera** — present only while the camera is active; UI moves aside when
  it wakes.
- **Folding region** — conditional. When partially open it divides the inner
  display into separate usable regions, excluding the centre. A *division* region.

Alerts, context menus, sheets and split views adapt automatically. Custom
components need `ReservedRegion`.

> **Third-party figures — verify at runtime.** One published reference gives the
> outer display closed in portrait a safe area of top 0, bottom 34, left 0,
> **right 84pt**, with corner radii 8pt top-left / 59pt elsewhere, and the inner
> display 55pt all round. The 84pt figure is consistent with the ~80pt strip
> measured from our screenshots, but Apple publishes no fixed table — insets vary
> by orientation, bars and window size. Read them at runtime.

---

## 6. New APIs (iOS 27.1, SwiftUI)

**Hinge**

```swift
@State private var hinge: DeviceHinge?

content
    .onHingeChange { oldContext, newContext in
        hinge = newContext.hinge
    }

// hinge.angle  -> Angle (180° when flat)
// hinge.status -> .closed | .partiallyOpen | .fullyOpen
```

**Reserved regions**

```swift
GeometryReader { proxy in
    let folds   = proxy.reservedRegions(kind: .division)
    let cutouts = proxy.reservedRegions(kind: .occlusion,
                                        options: [.includeInactive])

    ForEach(folds) { region in
        // region.frame, region.margins, region.isActive
    }
}
```

**Arrangement views.** A container holding a primary and secondary view that
reorganises by size, orientation and reserved regions. *Split* divides the area
(horizontally when wider than tall, vertically when taller than wide). *Overlay*
stacks them, separating to each side when partially folded.

```swift
ArrangementView {
    Sidebar()
        .splitArrangementLayoutRatio(0.4)
} secondary: {
    Detail()
}
.arrangementViewStyle(.split.axes([.horizontal, .vertical]))
```

An `HStack`/`VStack` translates to split; a `ZStack` to overlay. **Keep navigation
containers outside** — arrangement views lay out content, they don't navigate.

**Vertical bar**

```swift
.toolbarVerticalBehavior(.disabled)
.toolbarVerticalCompressionBehavior(.prefersTabBar)
.axisBehavior(.verticalPreferred)
.visibilityPriority(.high)

ToolbarItem(placement: .topBarPinnedTrailing) { … }

@Environment(\.toolbarVerticalEdge)   // .leading | .trailing | nil
```

**Container margins**

```swift
content.contentMargins(for: .container)
```

---

## 7. The rules, compressed

**Do**

- Build to resize — size classes, layout margins, safe area insets
- Keep functionality and element state identical across both displays
- Show an extra level of hierarchy on the inner display where it helps (Mail:
  list + message side by side when open, one at a time when closed)
- Prefer an **even** number of grid columns so content divides cleanly across the fold
- Give every non-text toolbar item both a title and a symbol — the system needs
  the title for overflow menus
- Keep controls near the content they affect; controls for a leading pane stay
  above that pane, not in the side strip

**Don't**

- Override default bar placement — vertical controls are a core platform pattern
- Make extreme layout changes as the device folds; move only what must move
- Assume symmetric safe areas — `bounds.width - insets.left * 2` is wrong; inset
  each edge independently
- Use fixed widths, device idiom checks, or anything tied to a specific display
- Add manual spacing between toolbar items — use `ToolbarItemGroup`
- Keep your own overflow menu; move those actions into the system one

One permitted exception: interfaces that don't need bars may span the full
display width — good for immersive, non-scrolling layouts, provided nothing
collides with the Dynamic Island or status bar. Calculator does this.

---

## 8. What Fonti breaks

Roughly ordered by how much work each represents.

### `Fonti/Theme/CustomTabBar.swift` · `Fonti/App/RootView.swift`

**The custom floating tab bar is the central conflict.** Fonti calls
`hideNativeTabBar()` and overlays its own horizontal glass capsule via
`IGStyleTabBar`. The system wants that bar vertical on the trailing edge,
carrying the status bar and Dynamic Island with it. A bottom-pinned horizontal
capsule is exactly the pattern the HIG says not to hand-roll — and going custom
means reimplementing overflow, visibility priority and Split View edge-flipping
ourselves. **Decide this before building anything else.**

### `Fonti/Features/Browse/BrowseView.swift` + `FullScreenPreviewView`

**Browse → preview is a `NavigationStack` push.** On the inner display that's the
Mail pattern asking for `NavigationSplitView`: font list leading, specimen
trailing. Biggest win available — turns 283 extra points of width into product
value rather than wider cards.

### `Fonti/Features/Compare/CompareView.swift`

**Already an arrangement view in spirit.** Two typefaces side by side *is* the
split `ArrangementView` case; adopting it gets fold-awareness free, including
separating cleanly either side of the hinge when partially folded.

### `Fonti/Theme/FontCardLayout.swift`

**`columns: 2` is hard-coded.** Even-numbered (which the HIG likes) but fixed. At
669pt the masonry should widen to 4; on the outer display 2 still holds. Drive it
from the width the layout is handed.

### `Fonti/Features/Onboarding/OnboardingView.swift`

**Fixed for height, not width.** `OnboardingMetrics` (commit `ade59c4`) scales
against available height, which solved the outer display. The inner display is
regular/regular at 669×951 — the carousel's fixed `cardWidth: 220` and the
single-column stack will both look thin there.

### `Fonti/App/RootView.swift`

**Symmetric horizontal padding.** `.padding(.horizontal, 20)` on the tab bar
assumes both edges are equivalent. With controls on one edge, they aren't.

### `Fonti/Features/Preview/*` — `SpecimenLayoutView`, `PreviewControls`

**Unseen at Duo proportions.** Nobody has looked at the specimen screen, the chip
strips, Settings or Saved on either panel. The preview screen holds Fonti's most
complex layout and is where the fold is most likely to cut something in half.

---

## 9. Open questions

- **Letterbox or safe area?** The 80pt strip measured in our screenshots matches
  both the reported 84pt vertical-bar safe area *and* the described 27.0-SDK
  compatibility crop. The distinction matters: under the 27.1 SDK, backgrounds
  using `ignoresSafeArea()` should extend *under* the bar and fill all 466pt.
  Rebuilding and re-measuring settles it in one screenshot.
- **The inner display has never been observed.** Display 3 renders zero pixels
  under Xcode 27.0. Everything above about the 669×951 panel is from Apple's
  documentation, not from our own observation.
- **Posture switching can't be automated.** Neither 27.0's nor 27.1's `simctl`
  exposes a fold/posture command — only appearance, contrast and content size.
  Folding is Device Hub's toolbar buttons, ⌥ held for a hinge-angle slider.
  Per-posture captures need a hand on the controls.
- **Hardware pixel figures conflict.** Published specs give the inner display
  2670×1878 px; the simulator reports 2007×2853. Point sizes agree, so work in
  points and treat pixel figures as unconfirmed.

---

## Sources

- Apple — [Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo) (HIG, 9 Sep 2026)
- Apple — [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/TechnologyOverviews/preparing-your-app-for-iphone-duo)
- Apple — [Tech Talk 111461](https://developer.apple.com/videos/play/tech-talks/111461/)
- [iPhone Duo by Examples](https://github.com/artemnovichkov/iPhone-Duo-by-Examples) — API usage
- [SwiftLee — iPhone Duo Simulator](https://www.avanderlee.com/swiftui/iphone-duo-simulator/)
- [Blake Crosley — The 1.42 Problem and the SDK Gap](https://blakecrosley.com/blog/iphone-duo-for-developers)
- [Plurigent — Safe Area Insets & Layout Margins](https://plurigent.com/topics/iphone-duo/safe-area)

Measurements attributed to "our screenshots" were taken from the
`Fonti iPhone Duo` simulator under Xcode 27.0.
