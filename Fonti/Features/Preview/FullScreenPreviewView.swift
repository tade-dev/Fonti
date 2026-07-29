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
    @State private var showComposer: Bool = false
    @State private var compareSession: CompareSession?
    @FocusState private var composerFocused: Bool

    @State private var background: PreviewBackground = .ink
    @State private var customImage: UIImage?
    @State private var cardRotationY: Double = 0
    @State private var isFlipping = false

    /// Point size actually drawn — snapped while text is hidden.
    @State private var livePointSize: CGFloat
    /// Per-glyph springs only while typing — off during morph.
    @State private var glyphAnimationEnabled = false
    /// Specimen glyphs hide for the morph, then fade back in.
    @State private var specimenTextOpacity: Double = 1
    @State private var isMorphing = false

    @AppStorage("fonti.hapticsEnabled") private var hapticsEnabled: Bool = true

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
                    VStack(spacing: showComposer ? 8 : 0) {
                        AnimatedSpecimenText(
                            text: previewText,
                            font: styledFont(size: livePointSize),
                            color: background.glyphColor,
                            animates: glyphAnimationEnabled
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .accessibilityHint("Double tap to edit")
                        .accessibilityAddTraits(.isButton)

                        if showComposer {
                            Text(family.displayName)
                                .font(.caption2.weight(.medium))
                                .tracking(0.6)
                                .foregroundStyle(background.secondaryGlyphColor)
                                .transition(.opacity)
                        }
                    }
                    .opacity(specimenTextOpacity)
                }
                .frame(maxHeight: showComposer ? 132 : geo.size.height * 0.46)

                if !showComposer {
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
        .sensoryFeedback(trigger: text.count) { old, new in
            (hapticsEnabled && showComposer && old != new) ? .selection : nil
        }
        .onChange(of: size) { _, newSize in
            guard !showComposer else { return }
            snapPointSize(newSize)
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
            customImage: customImage
        ) {
            ShareLink(
                item: Image(uiImage: image),
                preview: SharePreview("Fonti — \(family.displayName)", image: Image(uiImage: image))
            ) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
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
