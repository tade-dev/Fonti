import SwiftUI

/// A snapshot entry resolved against what this process can actually render.
///
/// `Font.custom` fails silently, so every layout asks here first. When the real
/// typeface isn't available the fallback is chosen deliberately and the UI can
/// say so, rather than passing off Helvetica as the user's imported face.
struct ResolvedFont {
    let entry: WidgetFontEntry

    /// Family name to hand to `Font.custom`, or nil when the real face can't
    /// be shown in this process.
    let renderableFamily: String?

    var canRenderTypeface: Bool { renderableFamily != nil }

    var displayName: String { entry.displayName }
    var sampleText: String { entry.sampleText }

    /// The pairing to show beside this face, if the curated table has one that
    /// is also renderable here.
    var pairing: String? { FeaturedFont.pairing(for: entry.familyName) }

    init(_ entry: WidgetFontEntry) {
        self.entry = entry
        self.renderableFamily = FontAvailability.resolve(entry)
    }

    /// Specimen face. Scales with Dynamic Type — callers pair this with
    /// `minimumScaleFactor` so large accessibility sizes shrink rather than clip.
    func font(size: CGFloat) -> Font {
        guard let renderableFamily else {
            // Serif reads as an intentional editorial choice rather than a
            // broken custom-font load.
            return .system(size: size, weight: .regular, design: .serif)
        }
        return .custom(renderableFamily, size: size)
    }
}
