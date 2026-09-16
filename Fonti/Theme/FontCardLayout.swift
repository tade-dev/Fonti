import SwiftUI

/// Arranges font cards as full-width rows or a multi-column masonry, and
/// animates between the two arrangements.
///
/// This replaces swapping a `LazyVStack` for a separate masonry view. Those are
/// two different view trees, so every toggle inserted and removed every card
/// and `matchedGeometryEffect` had to re-pair them across lazy containers —
/// which drew each card twice mid-transition, doubled text and all. Here the
/// cards are a single `ForEach` that never changes identity; only their frames
/// move, and interpolating `progress` is what makes them fly.
///
/// Note this is *not* lazy: a `Layout` measures every subview. That's the price
/// of a continuous transition, and it's why `estimatedHeight` is gone — real
/// measurements replace the packing guess.
struct FontCardLayout: Layout {
    /// 0 = rows, 1 = masonry. Animating this drives the whole transition.
    var progress: CGFloat
    /// The arrangement being animated *towards*. Cards change their own content
    /// at the moment the mode flips, so this also keys the measurement cache.
    var mode: FontCollectionLayout
    var spacing: CGFloat = 14
    var columns: Int = 2

    var animatableData: CGFloat {
        get { progress }
        set { progress = newValue }
    }

    /// Everything here depends only on the container width and the card
    /// content, never on `progress` — so an in-flight animation re-measures
    /// nothing and each frame is just a handful of lerps.
    struct Cache {
        var width: CGFloat = -1
        var count: Int = -1
        var mode: FontCollectionLayout?
        var rowHeights: [CGFloat] = []
        var cellHeights: [CGFloat] = []
        var rowOrigins: [CGPoint] = []
        var cellOrigins: [CGPoint] = []
        var rowTotal: CGFloat = 0
        var gridTotal: CGFloat = 0
        var columnWidth: CGFloat = 0
    }

    func makeCache(subviews: Subviews) -> Cache { Cache() }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) -> CGSize {
        let width = proposal.width ?? 0
        measureIfNeeded(width: width, subviews: subviews, cache: &cache)
        return CGSize(
            width: width,
            height: lerp(cache.rowTotal, cache.gridTotal)
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout Cache
    ) {
        measureIfNeeded(width: bounds.width, subviews: subviews, cache: &cache)
        guard !cache.rowOrigins.isEmpty else { return }

        for index in subviews.indices {
            let origin = CGPoint(
                x: bounds.minX + lerp(cache.rowOrigins[index].x, cache.cellOrigins[index].x),
                y: bounds.minY + lerp(cache.rowOrigins[index].y, cache.cellOrigins[index].y)
            )
            let size = CGSize(
                width: lerp(bounds.width, cache.columnWidth),
                height: lerp(cache.rowHeights[index], cache.cellHeights[index])
            )
            subviews[index].place(
                at: origin,
                anchor: .topLeading,
                proposal: ProposedViewSize(size)
            )
        }
    }

    private func measureIfNeeded(width: CGFloat, subviews: Subviews, cache: inout Cache) {
        guard width > 0 else { return }
        guard
            cache.width != width
                || cache.count != subviews.count
                || cache.mode != mode
        else { return }

        cache.width = width
        cache.count = subviews.count
        cache.mode = mode

        let columnCount = max(columns, 1)
        let columnWidth = (width - spacing * CGFloat(columnCount - 1)) / CGFloat(columnCount)
        cache.columnWidth = columnWidth

        cache.rowHeights = subviews.map {
            $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height
        }
        cache.cellHeights = subviews.map {
            $0.sizeThatFits(ProposedViewSize(width: columnWidth, height: nil)).height
        }

        // Rows: straight down the page.
        var rowOrigins: [CGPoint] = []
        rowOrigins.reserveCapacity(subviews.count)
        var y: CGFloat = 0
        for height in cache.rowHeights {
            rowOrigins.append(CGPoint(x: 0, y: y))
            y += height + spacing
        }
        cache.rowOrigins = rowOrigins
        cache.rowTotal = max(y - spacing, 0)

        // Masonry: each card into whichever column is currently shortest.
        var columnHeights = Array(repeating: CGFloat(0), count: columnCount)
        var cellOrigins: [CGPoint] = []
        cellOrigins.reserveCapacity(subviews.count)
        for height in cache.cellHeights {
            let target = columnHeights.enumerated().min { $0.element < $1.element }?.offset ?? 0
            cellOrigins.append(
                CGPoint(x: (columnWidth + spacing) * CGFloat(target), y: columnHeights[target])
            )
            columnHeights[target] += height + spacing
        }
        cache.cellOrigins = cellOrigins
        cache.gridTotal = max((columnHeights.max() ?? 0) - spacing, 0)
    }

    private func lerp(_ from: CGFloat, _ to: CGFloat) -> CGFloat {
        let t = min(max(progress, 0), 1)
        return from + (to - from) * t
    }
}
