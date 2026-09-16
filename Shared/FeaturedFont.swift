import Foundation

/// Fonti's font of the day.
///
/// Curated, not random: the pool is `FontPairings.curatedFamilies` — faces a
/// designer deliberately wrote a pairing for — and the choice is seeded by the
/// calendar day. The same face shows from local midnight to local midnight, on
/// every launch and in every process, with nothing persisted.
enum FeaturedFont {
    /// The featured family for a given day, or nil if nothing in the pool can
    /// actually be rendered on this device.
    static func familyName(on date: Date = .now, calendar: Calendar = .current) -> String? {
        // Wrapped in a closure rather than passed as `filter(FontAvailability
        // .isAvailable)`: handing a main-actor function to `filter` makes it a
        // nonisolated call, which Swift 6 rejects.
        let pool = FontPairings.curatedFamilies.filter { FontAvailability.isAvailable($0) }
        guard !pool.isEmpty else { return nil }
        return pool[dayIndex(for: date, calendar: calendar, modulo: pool.count)]
    }

    static func entry(on date: Date = .now, calendar: Calendar = .current) -> WidgetFontEntry {
        guard let family = familyName(on: date, calendar: calendar) else {
            return WidgetSnapshotStore.fallback
        }
        return WidgetFontEntry(
            familyName: family,
            displayName: family,
            sampleText: specimenLine(on: date, calendar: calendar)
        )
    }

    /// The pairing to show alongside the featured face, if we have one.
    static func pairing(for familyName: String) -> String? {
        FontPairings.pairings(for: familyName)
            .first { FontAvailability.isAvailable($0) }
    }

    /// Editorial specimen copy, rotated on the same daily seed so the whole
    /// composition changes together rather than one piece at a time.
    private static let specimenLines = [
        "Typography is\nvisual language.",
        "Letters carry\nmore than words.",
        "Every face has\na voice.",
        "Type is what\nwords look like.",
        "Form follows\nthe reading eye.",
        "White space is\nnot empty space.",
        "Good type goes\nunnoticed."
    ]

    /// The day's specimen copy. Shared by every source so the featured font and
    /// a hand-picked one read with the same editorial voice.
    static func specimenLine(on date: Date = .now, calendar: Calendar = .current) -> String {
        specimenLines[dayIndex(for: date, calendar: calendar, modulo: specimenLines.count)]
    }

    /// Days elapsed since the reference date, wrapped into `0..<modulo`.
    private static func dayIndex(for date: Date, calendar: Calendar, modulo: Int) -> Int {
        let startOfDay = calendar.startOfDay(for: date)
        let days = Int((startOfDay.timeIntervalSinceReferenceDate / 86_400).rounded(.down))
        // Swift's % keeps the sign of the dividend; dates before 2001 would
        // otherwise index negatively.
        return ((days % modulo) + modulo) % modulo
    }
}
