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

    @State private var historyEntries: [String] = PreviewTextHistory.load()
    @State private var historyIndex: Int = 0

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

    /// Empty field falls back to the font's own name so the specimen
    /// (and AR / share) always have something meaningful to render.
    private var previewText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? family.displayName : text
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 12) {
                SpecimenCard(
                    background: background,
                    customImage: customImage,
                    rotationY: cardRotationY,
                    isFlipping: isFlipping,
                    compact: showComposer,
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
                                pointSize: layoutPointSize,
                                font: styledFont(size: layoutPointSize),
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
                .frame(maxHeight: showComposer ? 148 : geo.size.height * 0.40)

                if !showComposer {
                    HistoryScrubBar(
                        entries: historyEntries,
                        currentText: previewText,
                        selectedIndex: $historyIndex,
                        onSelect: { entry in
                            withAnimation(.easeInOut(duration: 0.2)) {
                                text = entry
                            }
                        }
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))

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

                Spacer(minLength: 0)
                    .contentShape(Rectangle())
                    .onTapGesture { endEditing() }

                if !showComposer {
                    PairingsStrip(family: family)
                        .transition(.opacity)
                }

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
                        compareSession = CompareSession.make(from: family, text: previewText)
                    }
                )
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 12)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
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
            syncHistorySelectionToCurrentText()
            TypewriterHaptics.prepare()
            WidgetSnapshotStore.publish(
                familyName: family.id,
                displayName: family.displayName,
                sampleText: previewText
            )
        }
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

    private func syncHistorySelectionToCurrentText() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let match = historyEntries.firstIndex(where: {
            $0.caseInsensitiveCompare(trimmed) == .orderedSame
        }) {
            historyIndex = match
        } else {
            historyIndex = 0
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
            || PreviewTextHistory.seeds.contains { $0.caseInsensitiveCompare(trimmed) == .orderedSame }
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

        // Remember what they wrote (skip pure font-name fallback if field empty).
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            historyEntries = PreviewTextHistory.push(trimmed)
            historyIndex = 0
        }

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
