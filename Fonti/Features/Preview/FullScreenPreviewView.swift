import SwiftUI

@MainActor
struct FullScreenPreviewView: View {
    let family: FontFamily
    let initialText: String

    @State private var text: String
    @State private var size: CGFloat
    @State private var isBold: Bool = false
    @State private var isItalic: Bool = false

    init(family: FontFamily, initialText: String) {
        self.family = family
        self.initialText = initialText
        _text = State(initialValue: initialText.isEmpty ? family.displayName : initialText)
        let stored = UserDefaults.standard.double(forKey: "fonti.defaultPreviewSize")
        _size = State(initialValue: stored == 0 ? 48 : CGFloat(stored))
    }

    var body: some View {
        VStack {
            Spacer()
            Text(text)
                .font(styledFont)
                .foregroundStyle(Color.fontiCream)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Spacer()
            PreviewControls(
                family: family,
                size: $size,
                isBold: $isBold,
                isItalic: $isItalic,
                shareSlot: shareSlot
            )
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
                    .accessibilityHidden(true) // navigationTitle already announces this
            }
        }
    }

    private var styledFont: Font {
        var font = Font.custom(family.id, size: size)
        if isBold { font = font.bold() }
        if isItalic { font = font.italic() }
        return font
    }

    @ViewBuilder
    private var shareSlot: some View {
        if let image = SpecimenRenderer.render(
            family: family.id,
            text: text,
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
