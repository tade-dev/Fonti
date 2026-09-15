import WidgetKit
import SwiftUI

/// Preview fixtures — deliberately awkward, not a gallery of Helvetica.
///
/// Every case here is one we've had to design around: a high-contrast didone, a
/// script with enormous overshoot, a mono, a very long name, diacritics, and an
/// imported font whose file isn't in the container so it *must* fall back.
enum SpecimenPreviewData {
    static func entry(
        _ family: String,
        _ sample: String,
        source: WidgetFontSource = .featured,
        isImported: Bool = false
    ) -> SpecimenEntry {
        SpecimenEntry(
            date: .now,
            font: WidgetFontEntry(
                familyName: family,
                displayName: family,
                sampleText: sample,
                isImported: isImported,
                fileName: isImported ? "missing-on-purpose.otf" : nil
            ),
            source: source
        )
    }

    /// A high-contrast serif — thin hairlines are the stress test for tinted
    /// and vibrant rendering modes.
    static let didone = entry("Didot", "Typography is\nvisual language.")

    /// Geometric sans, wide caps.
    static let geometric = entry("Futura", "Form follows\nthe reading eye.", source: .favourite)

    /// Script: huge ascenders and descenders, the layout's worst case.
    static let script = entry("Snell Roundhand", "Letters carry\nmore than words.")

    /// Monospace — even advance widths, very different rhythm.
    static let mono = entry("Menlo", "Type is what\nwords look like.", source: .specific)

    /// Long name plus diacritics, to catch truncation and clipping.
    static let longName = entry(
        "Bodoni 72 Oldstyle Compressed Display",
        "Ǻŋ ëxtrëmely lóng nâme",
        source: .specific
    )

    /// An imported face whose file is absent — the widget must fall back
    /// deliberately and say the preview is unavailable, never pass off a
    /// substitute as the user's font.
    static let missingImport = entry(
        "Untitled Sans Trial",
        "Good type goes\nunnoticed.",
        source: .specific,
        isImported: true
    )

    /// Nothing saved yet.
    static let empty = SpecimenEntry(
        date: .now,
        font: WidgetSnapshotStore.fallback,
        source: .favourite,
        isEmpty: true
    )
}

// MARK: - Small

#Preview("Small", as: .systemSmall) {
    SpecimenWidget()
} timeline: {
    SpecimenPreviewData.didone
    SpecimenPreviewData.geometric
    SpecimenPreviewData.script
    SpecimenPreviewData.longName
    SpecimenPreviewData.empty
}

// MARK: - Medium

#Preview("Medium", as: .systemMedium) {
    SpecimenWidget()
} timeline: {
    SpecimenPreviewData.didone
    SpecimenPreviewData.mono
    SpecimenPreviewData.longName
    SpecimenPreviewData.missingImport
    SpecimenPreviewData.empty
}

// MARK: - Large

#Preview("Large", as: .systemLarge) {
    SpecimenWidget()
} timeline: {
    SpecimenPreviewData.didone
    SpecimenPreviewData.geometric
    SpecimenPreviewData.script
    SpecimenPreviewData.missingImport
    SpecimenPreviewData.empty
}

// MARK: - Poster (full-page iPhone widget, iOS 27)

@available(iOS 27.0, *)
#Preview("Poster", as: .systemExtraLargePortrait) {
    SpecimenWidget()
} timeline: {
    SpecimenPreviewData.didone
    SpecimenPreviewData.geometric
    SpecimenPreviewData.script
    SpecimenPreviewData.longName
    SpecimenPreviewData.missingImport
    SpecimenPreviewData.empty
}

// MARK: - Extra large (iPad / Mac)

#Preview("Extra Large", as: .systemExtraLarge) {
    SpecimenWidget()
} timeline: {
    SpecimenPreviewData.didone
    SpecimenPreviewData.geometric
}

// MARK: - Single-entry edge cases
//
// One entry each so the case under test is unambiguous — handy when checking a
// specific failure mode at a specific Dynamic Type size.

#Preview("Edge · Long name", as: .systemMedium) {
    SpecimenWidget()
} timeline: {
    SpecimenPreviewData.longName
}

#Preview("Edge · Missing import", as: .systemLarge) {
    SpecimenWidget()
} timeline: {
    SpecimenPreviewData.missingImport
}

#Preview("Edge · Empty", as: .systemMedium) {
    SpecimenWidget()
} timeline: {
    SpecimenPreviewData.empty
}
