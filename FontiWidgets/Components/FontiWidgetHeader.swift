import SwiftUI
import WidgetKit

/// The wordmark line: `FONTI` with an optional state label opposite it.
///
/// Small, tracked, quiet. It exists to attribute the widget, not to compete
/// with the typography below it.
struct FontiWidgetHeader: View {
    @Environment(\.palette) private var palette

    var label: String?
    var size: CGFloat = 10

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("FONTI")
                .font(.system(size: size, weight: .semibold))
                .tracking(size * 0.22)
                .foregroundStyle(palette.accent)

            if let label {
                Spacer(minLength: 8)
                Text(label.uppercased())
                    .font(.system(size: size - 1, weight: .medium))
                    .tracking((size - 1) * 0.14)
                    .foregroundStyle(palette.tertiary)
                    .lineLimit(1)
            }
        }
        .widgetAccentable()
        .accessibilityHidden(true)
    }
}
