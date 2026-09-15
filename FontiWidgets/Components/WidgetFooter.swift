import SwiftUI

/// A quiet closing line — "Open Fonti →".
///
/// Not a button. The whole widget is the tap target via `widgetURL`, so this
/// is only an affordance hint and stays out of the accessibility tree.
struct WidgetFooter: View {
    @Environment(\.palette) private var palette

    var title: String = "Open Fonti"
    var size: CGFloat = 10

    var body: some View {
        HStack(spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: size, weight: .medium))
                .tracking(size * 0.12)
            Text("→")
                .font(.system(size: size, weight: .medium))
        }
        .foregroundStyle(palette.tertiary)
        .lineLimit(1)
        .accessibilityHidden(true)
    }
}
