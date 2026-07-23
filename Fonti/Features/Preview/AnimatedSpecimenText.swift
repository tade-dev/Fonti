import SwiftUI

/// Renders specimen text as individual glyphs so newly typed characters
/// spring in (and deletions spring out), with wrapping + center alignment.
struct AnimatedSpecimenText: View {
    let text: String
    let font: Font
    var color: Color = .fontiCream

    @State private var allowsAnimation = false

    private struct Glyph: Identifiable, Hashable {
        let id: Int
        let character: Character
    }

    private var glyphs: [Glyph] {
        text.enumerated().map { Glyph(id: $0.offset, character: $0.element) }
    }

    var body: some View {
        GlyphFlow(lineSpacing: 4) {
            ForEach(glyphs) { glyph in
                glyphView(glyph)
            }
        }
        .animation(
            allowsAnimation
                ? .spring(response: 0.36, dampingFraction: 0.58)
                : nil,
            value: text
        )
        .task {
            // Skip the waterfall on first appear — only animate real edits.
            try? await Task.sleep(for: .milliseconds(60))
            allowsAnimation = true
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }

    @ViewBuilder
    private func glyphView(_ glyph: Glyph) -> some View {
        let isNewline = glyph.character == "\n"
        Text(String(isNewline ? " " : glyph.character))
            .font(font)
            .foregroundStyle(isNewline ? .clear : color)
            .frame(width: isNewline ? 0 : nil, height: isNewline ? 0 : nil)
            .layoutValue(key: GlyphCharacterKey.self, value: glyph.character)
            .transition(.asymmetric(
                insertion: .modifier(
                    active: GlyphAppear(progress: 0),
                    identity: GlyphAppear(progress: 1)
                ),
                removal: .modifier(
                    active: GlyphAppear(progress: 0),
                    identity: GlyphAppear(progress: 1)
                )
            ))
    }
}

// MARK: - Per-glyph spring

private struct GlyphAppear: ViewModifier {
    var progress: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(progress)
            .scaleEffect(0.35 + 0.65 * progress, anchor: .bottom)
            .offset(y: (1 - progress) * 16)
            .blur(radius: (1 - progress) * 2.5)
    }
}

// MARK: - Layout value

private struct GlyphCharacterKey: LayoutValueKey {
    static let defaultValue: Character? = nil
}

// MARK: - Centered wrapping flow

private struct GlyphFlow: Layout {
    var lineSpacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = makeRows(maxWidth: proposal.width ?? .infinity, subviews: subviews)
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        guard !rows.isEmpty else { return .zero }
        let height = rows.reduce(CGFloat(0)) { $0 + $1.height }
            + lineSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = makeRows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            let x0 = bounds.minX + max((bounds.width - row.width) / 2, 0)
            var x = x0
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y + (row.height - size.height) / 2),
                    proposal: ProposedViewSize(size)
                )
                x += size.width
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int]
        var width: CGFloat
        var height: CGFloat
    }

    private func makeRows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0

        func flush() {
            guard !indices.isEmpty else { return }
            rows.append(Row(indices: indices, width: width, height: height))
            indices = []
            width = 0
            height = 0
        }

        for (index, subview) in subviews.enumerated() {
            if subview[GlyphCharacterKey.self] == "\n" {
                flush()
                continue
            }

            let size = subview.sizeThatFits(.unspecified)
            if !indices.isEmpty, width + size.width > maxWidth {
                flush()
            }
            indices.append(index)
            width += size.width
            height = max(height, size.height)
        }
        flush()
        return rows
    }
}

#Preview {
    ZStack {
        Color.fontiInk.ignoresSafeArea()
        AnimatedSpecimenText(
            text: "Find your type.",
            font: .custom("Georgia", size: 48)
        )
        .padding()
    }
}
