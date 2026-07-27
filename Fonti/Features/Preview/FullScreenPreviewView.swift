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
    @State private var showAR: Bool = false
    @State private var showComposer: Bool = false
    @State private var compareSession: CompareSession?
    @FocusState private var composerFocused: Bool

    @State private var background: PreviewBackground = .ink
    @State private var customImage: UIImage?
    @State private var cardRotationY: Double = 0
    @State private var isFlipping = false

    @Namespace private var capsuleNamespace

    @AppStorage("fonti.hapticsEnabled") private var hapticsEnabled: Bool = true

    init(family: FontFamily, initialText: String) {
        self.family = family
        self.initialText = initialText
        _text = State(initialValue: initialText)
        let stored = UserDefaults.standard.double(forKey: "fonti.defaultPreviewSize")
        _size = State(initialValue: stored == 0 ? 48 : CGFloat(stored))
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
                    AnimatedSpecimenText(
                        text: previewText,
                        font: styledFont,
                        color: background.glyphColor
                    )
                    .accessibilityHint("Double tap to edit")
                    .accessibilityAddTraits(.isButton)
                }
                .frame(maxHeight: showComposer ? geo.size.height * 0.36 : geo.size.height * 0.46)
                .sensoryFeedback(trigger: text.count) { old, new in
                    (hapticsEnabled && showComposer && old != new) ? .selection : nil
                }

                if !showComposer {
                    BackgroundChipStrip(
                        selection: $background,
                        customImage: $customImage,
                        isFlipping: isFlipping,
                        onSelect: flip
                    )
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }

                Spacer(minLength: 0)

                if !showComposer {
                    controlCapsule
                        .matchedGeometryEffect(id: "previewCapsule", in: capsuleNamespace)

                    PairingsStrip(family: family)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, showComposer ? 4 : 12)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .background(Color.fontiInk.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { endEditing() }
        .safeAreaInset(edge: .bottom, spacing: 12) {
            if showComposer {
                controlCapsule
                    .matchedGeometryEffect(id: "previewCapsule", in: capsuleNamespace)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
        }
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
        .fullScreenCover(isPresented: $showAR) {
            InSpaceView(
                text: previewText,
                familyName: family.id,
                initialSize: size,
                bold: isBold,
                italic: isItalic
            )
        }
        .fullScreenCover(item: $compareSession) { session in
            CompareView(session: session)
        }
        .sensoryFeedback(trigger: showComposer) { _, open in
            (hapticsEnabled && open) ? .impact(weight: .light) : nil
        }
        .animation(.spring(response: 0.45, dampingFraction: 0.86), value: showComposer)
    }

    private var controlCapsule: some View {
        PreviewControls(
            family: family,
            size: $size,
            isBold: $isBold,
            isItalic: $isItalic,
            text: $text,
            shareSlot: shareSlot,
            arEnabled: true,
            isEditing: showComposer,
            composerFocused: $composerFocused,
            onEdit: { beginEditing() },
            onDone: { endEditing() },
            onOpenAR: { showAR = true },
            onCompare: {
                compareSession = CompareSession.make(from: family, text: previewText)
            }
        )
    }

    private var styledFont: Font {
        var font = Font.custom(family.id, size: size)
        if isBold { font = font.bold() }
        if isItalic { font = font.italic() }
        return font
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
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            showComposer = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(120))
            composerFocused = true
        }
    }

    private func endEditing() {
        guard showComposer else { return }
        composerFocused = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.86)) {
            showComposer = false
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
