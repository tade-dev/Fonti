import SwiftUI

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
            Spacer()
            specimen
            Spacer()

            if showComposer {
                composer
            }

            PreviewControls(
                family: family,
                size: $size,
                isBold: $isBold,
                isItalic: $isItalic,
                shareSlot: shareSlot,
                arEnabled: true,
                isEditing: showComposer,
                onEdit: {
                    if showComposer { endEditing() } else { beginEditing() }
                },
                onOpenAR: { showAR = true }
            )

            if !showComposer {
                PairingsStrip(family: family)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fontiInk.ignoresSafeArea())
        .contentShape(Rectangle())
        .onTapGesture { endEditing() }
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
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: showComposer)
    }

    /// Always glyph `Text`s — never a TextField. Typing happens in the composer;
    /// each new character springs in via `AnimatedSpecimenText`.
    private var specimen: some View {
        AnimatedSpecimenText(text: previewText, font: styledFont)
            .padding(.horizontal, 24)
            .frame(maxWidth: .infinity)
            .scaleEffect(showComposer ? 1.04 : 1)
            .shadow(
                color: showComposer ? Color.fontiAmber.opacity(0.22) : .clear,
                radius: showComposer ? 32 : 0
            )
            .animation(.spring(response: 0.42, dampingFraction: 0.78), value: showComposer)
            .contentShape(Rectangle())
            .onTapGesture { beginEditing() }
            .accessibilityHint("Double tap to edit")
            .accessibilityAddTraits(.isButton)
            .sensoryFeedback(trigger: text.count) { old, new in
                // Soft tick on each typed/deleted character while composing.
                (hapticsEnabled && showComposer && old != new) ? .selection : nil
            }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("", text: $text, axis: .vertical)
                .lineLimit(1...4)
                .font(.system(size: 17))
                .foregroundStyle(Color.fontiCream)
                .tint(Color.fontiAmber)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .focused($composerFocused)
                .onSubmit { endEditing() }
                .overlay(alignment: .leading) {
                    if text.isEmpty {
                        Text("Your words.")
                            .font(.system(size: 17).italic())
                            .foregroundStyle(Color.fontiCream.opacity(0.35))
                            .allowsHitTesting(false)
                    }
                }

            Button {
                endEditing()
            } label: {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.glass)
            .tint(.fontiAmber)
            .accessibilityLabel("Done editing")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .glassEffect(in: .rect(cornerRadius: 22))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }

    private var styledFont: Font {
        var font = Font.custom(family.id, size: size)
        if isBold { font = font.bold() }
        if isItalic { font = font.italic() }
        return font
    }

    private func beginEditing() {
        guard !showComposer else {
            composerFocused = true
            return
        }
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            showComposer = true
        }
        Task { @MainActor in
            // Let the composer mount before claiming focus.
            try? await Task.sleep(for: .milliseconds(40))
            composerFocused = true
        }
    }

    private func endEditing() {
        guard showComposer else { return }
        composerFocused = false
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
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
            italic: isItalic
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
