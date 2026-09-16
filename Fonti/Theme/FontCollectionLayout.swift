import SwiftUI

/// How a screen arranges its font cards.
///
/// Persisted per screen — browsing eighty faces and arranging a dozen
/// favourites are different tasks, so Home and Saved remember separately.
enum FontCollectionLayout: String, CaseIterable {
    case list
    case grid

    var toggled: FontCollectionLayout {
        self == .list ? .grid : .list
    }

    /// Symbol for the layout this switches *to*, following the platform
    /// convention of showing the destination rather than the current state.
    var toggleSymbol: String {
        self == .list ? "square.grid.2x2" : "list.bullet"
    }

    var toggleLabel: String {
        self == .list ? "Switch to grid" : "Switch to list"
    }
}

/// One tap flips between the two layouts.
///
/// A segmented control would be more chrome than two options deserve, and the
/// symbol replace transition already communicates the change.
struct FontCollectionLayoutToggle: View {
    @Binding var layout: FontCollectionLayout

    @AppStorage("fonti.hapticsEnabled") private var hapticsEnabled: Bool = true

    var body: some View {
        Button {
            withAnimation(.smooth(duration: 0.35)) {
                layout = layout.toggled
            }
        } label: {
            Image(systemName: layout.toggleSymbol)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(Color.fontiCream)
                .contentTransition(.symbolEffect(.replace))
        }
        .accessibilityLabel(layout.toggleLabel)
        .sensoryFeedback(trigger: layout) { _, _ in
            hapticsEnabled ? .selection : nil
        }
    }
}
