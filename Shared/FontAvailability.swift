import UIKit

/// Whether a family name will actually resolve to its real typeface.
///
/// `Font.custom` fails silently — ask for a face the process can't see and
/// SwiftUI quietly hands back the system font. In a typography app that's a
/// bug, not a fallback, so every render path checks first and falls back
/// *deliberately* instead.
enum FontAvailability {
    private static var cachedFamilies: Set<String>?

    private static var families: Set<String> {
        if let cachedFamilies { return cachedFamilies }
        // Core Text registration can add families mid-process, so this cache is
        // invalidated by `refresh()` after any registration.
        let names = Set(UIFont.familyNames)
        cachedFamilies = names
        return names
    }

    static func refresh() {
        cachedFamilies = nil
    }

    static func isAvailable(_ familyName: String) -> Bool {
        let name = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return false }
        return families.contains(name)
    }

    /// Resolve the face for an entry, registering an imported font first when
    /// needed. Returns nil when the real typeface can't be shown.
    static func resolve(_ entry: WidgetFontEntry) -> String? {
        if entry.isImported, let fileName = entry.fileName {
            guard SharedFontContainer.register(fileName: fileName) else { return nil }
            refresh()
        }
        return isAvailable(entry.familyName) ? entry.familyName : nil
    }
}
