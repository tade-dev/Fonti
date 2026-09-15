import SwiftUI
import WidgetKit

/// Fonti's widget palette, resolved for the current rendering mode.
///
/// On the Home Screen the system may hand us `.accented` (user tint) or
/// `.vibrant` (Lock Screen / StandBy), both of which desaturate whatever we
/// draw. Brand colour is therefore only meaningful in `.fullColor`; in the
/// other modes we switch to opacity tiers so the *hierarchy* survives even
/// though the hues don't.
struct WidgetPalette {
    let mode: WidgetRenderingMode

    private var isFullColor: Bool { mode == .fullColor }

    /// Primary text — the typeface itself.
    var primary: Color {
        isFullColor ? .fontiCream : .white
    }

    /// Font names and supporting metadata.
    var secondary: Color {
        isFullColor ? .fontiCream.opacity(0.62) : .white.opacity(0.7)
    }

    /// Quietest tier — captions, footers.
    var tertiary: Color {
        isFullColor ? .fontiCream.opacity(0.4) : .white.opacity(0.5)
    }

    /// The wordmark and state labels.
    var accent: Color {
        isFullColor ? .fontiAmber : .white
    }

    /// Hairline rules. Editorial, never a heavy divider.
    var rule: Color {
        isFullColor ? .fontiCream.opacity(0.16) : .white.opacity(0.25)
    }

    var background: Color { .fontiInk }
}

private struct WidgetPaletteKey: EnvironmentKey {
    static let defaultValue = WidgetPalette(mode: .fullColor)
}

extension EnvironmentValues {
    var palette: WidgetPalette {
        get { self[WidgetPaletteKey.self] }
        set { self[WidgetPaletteKey.self] = newValue }
    }
}
