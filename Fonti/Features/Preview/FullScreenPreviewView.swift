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
        VStack(spacing: 12) {
            SpecimenCard(
                background: background,
                customImage: customImage,
                rotationY: cardRotationY,
                compact: showComposer
            ) {
                AnimatedSpecimenText(
                    text: previewText,
                    font: styledFont,
                    color: background.glyphColor
                )
                .contentShape(Rectangle())
                .onTapGesture { beginEditing() }
                .accessibilityHint("Double tap to edit")
                .accessibilityAddTraits(.isButton)
            }
            .frame(maxHeight: showComposer ? 240 : .infinity)
            .layoutPriority(1)
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
        .padding(.top, 8)
        .padding(.bottom, showComposer ? 4 : 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fontiInk.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { endEditing() }
        // Same capsule, lifted above the keyboard while editing.
        .safeAreaInset(edge: .bottom, spacing: 16) {
            if showComposer {
                controlCapsule
                    .matchedGeometryEffect(id: "previewCapsule", in: capsuleNamespace)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 14)
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
                    .accessibilityHidden(true) // navigationTitle already announces this
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
            onOpenAR: { showAR = true }
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
            // Let the capsule morph before the keyboard arrives.
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
                Image(systemName: "square.and.arrow.up")
                    .padding(.horizontal, 6)
            }
            .buttonStyle(.glass)
            .tint(.fontiCream)
            .accessibilityLabel("Share specimen image")
        } else {
            EmptyView()
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
