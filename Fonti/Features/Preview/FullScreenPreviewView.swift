import AppIntents
import SwiftUI
import UIKit

@MainActor
struct FullScreenPreviewView: View {
    let family: FontFamily
    let initialText: String

    @State private var text: String
    @State private var size: CGFloat
    @State private var isBold: Bool = false
    @State private var isItalic: Bool = false
    @State private var tracking: CGFloat = 0
    @State private var leading: CGFloat = 4
    @State private var showComposer: Bool = false
    @State private var compareSession: CompareSession?
    @FocusState private var composerFocused: Bool

    @State private var background: PreviewBackground = .ink
    @State private var customImage: UIImage?
    @State private var cardRotationY: Double = 0
    @State private var isFlipping = false

    @State private var livePointSize: CGFloat
    /// Per-glyph springs only while typing — off during morph.
    @State private var glyphAnimationEnabled = false
    /// Specimen glyphs hide for morph / layout switch, then fade back in.
    @State private var specimenTextOpacity: Double = 1
    @State private var isMorphing = false
    @State private var isSwitchingLayout = false

    @AppStorage("fonti.specimenTemplate") private var templateRaw: String = SpecimenTemplate.wordmark.rawValue
    @AppStorage("fonti.hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("fonti.typewriterHapticsEnabled") private var typewriterHapticsEnabled: Bool = true

    private var template: SpecimenTemplate {
        SpecimenTemplate(rawValue: templateRaw) ?? .wordmark
    }

    private var layoutPointSize: CGFloat {
        if showComposer {
            return min(livePointSize, 34)
        }
        return livePointSize * template.sizeMultiplier
    }

    private let morphSpring = Animation.spring(response: 0.48, dampingFraction: 0.88)
    private let textFade = Animation.easeInOut(duration: 0.16)

    init(family: FontFamily, initialText: String) {
        self.family = family
        self.initialText = initialText
        _text = State(initialValue: initialText)
        let stored = UserDefaults.standard.double(forKey: "fonti.defaultPreviewSize")
        let initialSize = stored == 0 ? 48 : CGFloat(stored)
        _size = State(initialValue: initialSize)
        _livePointSize = State(initialValue: initialSize)
    }

    /// Empty field falls back to whatever the active template was drawn for,
    /// so the specimen (and AR / share) always have something meaningful to
    /// render — the font's own name for most, a paragraph for Body.
    private var previewText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.isEmpty else { return text }
        return template.fallbackText(familyName: family.displayName)
    }

    var body: some View {
        GeometryReader { geo in
            Group {
                if AdaptiveLayout.detailPrefersSideColumn(geo.size) && showComposer {
                    // Composing on a wide screen: canvas keeps the room, the
                    // composer docks beneath it. The settings column steps
                    // aside — nothing in it applies while you are typing.
                    VStack(spacing: 12) {
                        specimenHero(wide: true)
                            .padding(16)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)

                        previewControls
                            .padding([.horizontal, .bottom], 16)
                    }
                    .transition(.opacity)
                } else if AdaptiveLayout.detailPrefersSideColumn(geo.size) {
                    // Regular width: hero specimen ~2/3, settings column on the right.
                    HStack(spacing: 0) {
                        // Controls float over the canvas rather than sitting in
                        // the column. Their intrinsic width is ~349pt and the
                        // column only offers ~280pt inside its padding — and
                        // `.frame(width:)` does not clip, so the bar used to
                        // bleed out both sides, over the specimen on one and
                        // under the vertical tab bar on the other. Over the hero
                        // it has the full canvas width, and sits beside the type
                        // it adjusts rather than across the page from it.
                        specimenHero(wide: true)
                            .padding(16)
                            .frame(maxWidth: .infinity)
                            .overlay(alignment: .bottom) {
                                previewControls
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 20)
                            }

                        HairlineDivider()
                            .padding(.vertical, 16)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 16) {
                                styleStrips
                                PairingsStrip(family: family)
                            }
                            .padding(16)
                            // Bottom-aligned: the device is held in two hands
                            // and these are the controls you reach for most, so
                            // they sit near the thumbs instead of at the top of
                            // a 669pt column. Still scrolls if it ever outgrows
                            // the space.
                            .frame(minHeight: geo.size.height, alignment: .bottom)
                        }
                        .scrollIndicators(.hidden)
                        .frame(width: AdaptiveLayout.sideColumnWidth(for: geo.size.width))
                    }
                    .transition(.opacity)
                } else {
                    VStack(spacing: 12) {
                        specimenHero(wide: false)
                            .frame(maxHeight: showComposer ? 148 : geo.size.height * 0.46)

                        if !showComposer {
                            styleStrips
                        }

                        Spacer(minLength: 0)
                            .contentShape(Rectangle())
                            .onTapGesture { endEditing() }

                        if !showComposer {
                            PairingsStrip(family: family)
                                .transition(.opacity)
                        }

                        previewControls
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                    .transition(.opacity)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            .animation(AdaptiveLayout.transition, value: AdaptiveLayout.detailPrefersSideColumn(geo.size))
        }
        .background(Color.fontiInk.ignoresSafeArea())
        .navigationTitle(family.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(family.displayName)
                    .font(.custom(family.id, size: 17))
                    .foregroundStyle(Color.fontiCream)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .accessibilityHidden(true)
            }
        }
        .fullScreenCover(item: $compareSession) { session in
            CompareView(session: session)
        }
        .sensoryFeedback(trigger: showComposer) { _, open in
            (hapticsEnabled && open) ? .impact(weight: .light) : nil
        }
        .onChange(of: text) { old, new in
            guard showComposer, glyphAnimationEnabled else { return }
            TypewriterHaptics.tickIfNeeded(
                from: old,
                to: new,
                enabled: hapticsEnabled && typewriterHapticsEnabled
            )
        }
        .onChange(of: size) { _, newSize in
            guard !showComposer else { return }
            snapPointSize(newSize)
        }
        .onAppear {
            TypewriterHaptics.prepare()
            WidgetPublisher.publish(family: family, sampleText: previewText)
        }
        // What makes "this" resolvable. While this screen is up, the foreground
        // activity carries the identifier of the face being shown, so Apple
        // Intelligence can bind "what pairs with this?" or "find something
        // like this" to the right typeface without the user naming it.
        //
        // A single primary item, so the whole screen is annotated. A list would
        // instead annotate each row with a selection type, since collapsing
        // several visible items to one activity-level entity would make "the
        // second one" meaningless.
        .userActivity(Self.viewFontActivityType) { activity in
            activity.title = family.displayName
            activity.appEntityIdentifier = EntityIdentifier(
                for: FontEntity.self,
                identifier: family.id
            )
        }
    }

    /// Activity type for the specimen screen, used for onscreen annotation.
    static let viewFontActivityType = "com.tade.Fonti.viewFont"

    // MARK: - Adaptive pieces


    /// Full-bleed poster canvas; type scales with the canvas so the slider
    /// stays relative to the space it has.
    /// `wide` is about the screen, not the mode. Composing on a phone wants a
    /// small card so the keyboard has room; composing on a 951pt canvas does
    /// not, and the compact card there is a 148pt-tall sliver stranded in the
    /// corner of an otherwise empty screen.
    private func specimenHero(wide: Bool) -> some View {
        GeometryReader { canvas in
            let compactCard = showComposer && !wide
            let canvasScale = compactCard ? 1 : AdaptiveLayout.canvasScale(for: canvas.size)
            let heroSize = AdaptiveLayout.fittedPointSize(
                layoutPointSize * canvasScale, text: previewText, width: canvas.size.width - 56
            )
            SpecimenCard(
                    background: background,
                    customImage: customImage,
                    rotationY: cardRotationY,
                    isFlipping: isFlipping,
                    compact: compactCard,
                    fillsAvailable: !compactCard,
                    onTap: { beginEditing() }
                ) {
                    Group {
                        if showComposer {
                            // Write mode: word-aware fitted sample — no glyph flow.
                            EditSpecimenPreview(
                                text: previewText,
                                familyName: family.displayName,
                                font: styledFont(size: min(livePointSize, 28)),
                                color: background.glyphColor,
                                secondary: background.secondaryGlyphColor
                            )
                        } else {
                            SpecimenLayoutView(
                                template: template,
                                text: previewText,
                                familyName: family.displayName,
                                pointSize: heroSize,
                                font: styledFont(size: heroSize),
                                color: background.glyphColor,
                                secondary: background.secondaryGlyphColor,
                                animates: glyphAnimationEnabled,
                                compact: false,
                                tracking: tracking,
                                leading: leading
                            )
                            .accessibilityHint("Double tap to edit")
                            .accessibilityAddTraits(.isButton)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .opacity(specimenTextOpacity)
                    .scaleEffect(0.97 + 0.03 * specimenTextOpacity, anchor: .center)
                }
        }
    }

    @ViewBuilder
    private var styleStrips: some View {
        TemplateChipStrip(selection: template) { chosen in
            switchLayout(to: chosen)
        }
        .opacity(isSwitchingLayout ? 0.7 : 1)
        .allowsHitTesting(!isSwitchingLayout && !isMorphing)

        BackgroundChipStrip(
            selection: $background,
            customImage: $customImage,
            isFlipping: isFlipping,
            onSelect: flip
        )
        .transition(.opacity)
    }

    private var previewControls: some View {
        PreviewControls(
            family: family,
            size: $size,
            isBold: $isBold,
            isItalic: $isItalic,
            text: $text,
            tracking: $tracking,
            leading: $leading,
            shareSlot: shareSlot,
            isEditing: showComposer,
            composerFocused: $composerFocused,
            onEdit: { beginEditing() },
            onDone: { endEditing() },
            onCompare: {
                // Hand over the raw words, not `previewText`: an empty field falls
                // back to *this* font's name, which Compare would then render
                // in both columns as if it were the user's sample text.
                compareSession = CompareSession.make(from: family, text: text)
            }
        )
    }

    private func styledFont(size: CGFloat) -> Font {
        var font = Font.custom(family.id, size: size)
        if isBold { font = font.bold() }
        if isItalic { font = font.italic() }
        return font
    }

    /// Instant size change — never under a morph spring.
    private func snapPointSize(_ value: CGFloat) {
        var snap = Transaction()
        snap.disablesAnimations = true
        withTransaction(snap) {
            livePointSize = value
        }
    }

    /// Fade out → swap layout (and sample copy if still a seed) → fade in.
    private func switchLayout(to new: SpecimenTemplate) {
        guard new != template, !isSwitchingLayout, !isMorphing else { return }
        isSwitchingLayout = true

        if hapticsEnabled {
            UISelectionFeedbackGenerator().selectionChanged()
        }

        withAnimation(textFade) {
            specimenTextOpacity = 0
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))

            var snap = Transaction()
            snap.disablesAnimations = true
            withTransaction(snap) {
                templateRaw = new.rawValue
                applySuggestedCopyIfNeeded(for: new)
            }

            withAnimation(textFade) {
                specimenTextOpacity = 1
            }

            try? await Task.sleep(for: .milliseconds(160))
            isSwitchingLayout = false
        }
    }

    /// Swap in layout sample copy only when the field is empty or still a seed/suggestion.
    private func applySuggestedCopyIfNeeded(for template: SpecimenTemplate) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let replaceable = trimmed.isEmpty
            || PreviewTextSeeds.contains(trimmed)
            || SpecimenTemplate.allCases.contains { $0.suggestedCopy.caseInsensitiveCompare(trimmed) == .orderedSame }

        guard replaceable else { return }
        text = template.suggestedCopy
    }

    // MARK: - Card flip

    private func flip(to style: PreviewBackground) {
        guard !isFlipping, style != background else { return }
        if style == .custom, customImage == nil { return }

        isFlipping = true
        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }

        withAnimation(.easeInOut(duration: 0.28)) {
            cardRotationY = 90
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(280))

            var snap = Transaction()
            snap.disablesAnimations = true
            withTransaction(snap) {
                background = style
                cardRotationY = -90
            }

            withAnimation(.easeInOut(duration: 0.32)) {
                cardRotationY = 0
            }

            try? await Task.sleep(for: .milliseconds(340))
            isFlipping = false
        }
    }

    private func beginEditing() {
        guard !showComposer else {
            composerFocused = true
            return
        }
        guard !isMorphing else { return }
        runMorph(toEditing: true)
    }

    private func endEditing() {
        guard showComposer, !isMorphing else { return }
        composerFocused = false

        runMorph(toEditing: false)
    }

    /// Fade text out → morph layout → snap size → fade text back in.
    private func runMorph(toEditing: Bool) {
        isMorphing = true
        glyphAnimationEnabled = false

        withAnimation(textFade) {
            specimenTextOpacity = 0
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(160))

            // Size change while invisible — no visible reflow.
            snapPointSize(toEditing ? min(size, 34) : size)

            withAnimation(morphSpring) {
                showComposer = toEditing
            }

            try? await Task.sleep(for: .milliseconds(360))

            withAnimation(textFade) {
                specimenTextOpacity = 1
            }

            if toEditing {
                composerFocused = true
                TypewriterHaptics.prepare()
                // Let the fade finish before keystroke springs arm.
                try? await Task.sleep(for: .milliseconds(120))
                glyphAnimationEnabled = true
            }

            isMorphing = false
        }
    }

    @ViewBuilder
    private var shareSlot: some View {
        if let image = SpecimenRenderer.render(
            family: family.id,
            text: previewText,
            size: size,
            bold: isBold,
            italic: isItalic,
            background: background,
            customImage: customImage,
            template: template,
            tracking: tracking,
            leading: leading
        ) {
            ShareLink(
                item: Image(uiImage: image),
                preview: SharePreview("Fonti — \(family.displayName)", image: Image(uiImage: image))
            ) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            .simultaneousGesture(TapGesture().onEnded {
                ReviewPromptManager.noteShareCompleted()
            })
        }
    }
}

#Preview {
    NavigationStack {
        FullScreenPreviewView(
            family: FontFamily(id: "Georgia", displayName: "Georgia"),
            initialText: "The quick brown fox jumps over the lazy dog"
        )
    }
}
