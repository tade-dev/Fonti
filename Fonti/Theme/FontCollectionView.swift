import SwiftUI

/// Renders font cards as either rows or a staggered grid, animating between the
/// two.
///
/// Shared by Home and Saved so the screens can't drift apart. One `ForEach`
/// feeds `FontCardLayout`, which interpolates each card's frame — so toggling
/// layout never inserts or removes a card and the cards visibly fly to their
/// new positions.
struct FontCollectionView<Item: Identifiable, Content: View>: View {
    let items: [Item]
    var layout: FontCollectionLayout
    var spacing: CGFloat = 14
    var columns: Int = 2
    @ViewBuilder var content: (Item) -> Content

    /// Mirrors `layout` so the change can be animated as a continuous value;
    /// `FontCardLayout.animatableData` needs something to interpolate.
    @State private var progress: CGFloat

    init(
        items: [Item],
        layout: FontCollectionLayout,
        spacing: CGFloat = 14,
        columns: Int = 2,
        @ViewBuilder content: @escaping (Item) -> Content
    ) {
        self.items = items
        self.layout = layout
        self.spacing = spacing
        self.columns = columns
        self.content = content
        _progress = State(initialValue: layout == .grid ? 1 : 0)
    }

    var body: some View {
        FontCardLayout(
            progress: progress,
            mode: layout,
            spacing: spacing,
            columns: columns
        ) {
            ForEach(items) { content($0) }
        }
        .onChange(of: layout) { _, newLayout in
            withAnimation(.smooth(duration: 0.55)) {
                progress = newLayout == .grid ? 1 : 0
            }
        }
    }
}
