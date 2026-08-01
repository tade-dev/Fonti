import SwiftUI

/// Vertical masonry — items pack into the currently shorter column.
struct StaggeredGrid<Item: Identifiable, Content: View>: View {
    let items: [Item]
    var columns: Int = 2
    var spacing: CGFloat = 14
    /// Used only for packing; visual height still comes from the cell itself.
    var estimatedHeight: (Item) -> CGFloat = { _ in 160 }
    @ViewBuilder var content: (Item) -> Content

    var body: some View {
        let packed = packedColumns()
        HStack(alignment: .top, spacing: spacing) {
            ForEach(Array(packed.enumerated()), id: \.offset) { _, columnItems in
                LazyVStack(spacing: spacing) {
                    ForEach(columnItems) { item in
                        content(item)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .top)
            }
        }
    }

    private func packedColumns() -> [[Item]] {
        let count = max(columns, 1)
        var buckets = Array(repeating: [Item](), count: count)
        var heights = Array(repeating: CGFloat(0), count: count)

        for item in items {
            let target = heights.enumerated().min(by: { $0.element < $1.element })?.offset ?? 0
            buckets[target].append(item)
            heights[target] += estimatedHeight(item) + spacing
        }
        return buckets
    }
}
