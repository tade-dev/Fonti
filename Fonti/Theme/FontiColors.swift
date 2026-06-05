import SwiftUI
import UIKit

extension Color {
    /// Adaptive canvas. Near-black ink in dark mode, warm cream in light mode.
    /// Used as the app background; in light mode the palette inverts so cards,
    /// text, and chrome read on a cream surface instead of ink.
    static let fontiInk = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? .brandInkUI : .brandCreamUI
    })

    /// Adaptive foreground. Warm cream in dark mode, near-black ink in light mode.
    /// Used for primary text and glyphs.
    static let fontiCream = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark ? .brandCreamUI : .brandInkUI
    })

    /// Amber accent — heart-saved, slider thumb, active toggles.
    /// Stable across modes; saturated enough to read on either canvas.
    static let fontiAmber = Color(red: 0xE8 / 255, green: 0xA0 / 255, blue: 0x40 / 255)

    // MARK: - Static brand constants
    //
    // These do NOT adapt. Use them for surfaces that represent the brand outside
    // the live UI — exported specimen images, app icon generation, etc. — where
    // the user's current appearance preference must not bleed into the output.

    /// Brand ink — always #0D0D0D regardless of color scheme.
    static let brandInk = Color(red: 0x0D / 255, green: 0x0D / 255, blue: 0x0D / 255)

    /// Brand cream — always #F5F0E8 regardless of color scheme.
    static let brandCream = Color(red: 0xF5 / 255, green: 0xF0 / 255, blue: 0xE8 / 255)
}

private extension UIColor {
    static let brandInkUI = UIColor(red: 0x0D / 255, green: 0x0D / 255, blue: 0x0D / 255, alpha: 1)
    static let brandCreamUI = UIColor(red: 0xF5 / 255, green: 0xF0 / 255, blue: 0xE8 / 255, alpha: 1)
}
