import Foundation

/// The user's saved font family names, readable from any process.
///
/// Fonti's SwiftData store lives in the app's own container, so an App Intent
/// running outside the app can't query `SavedFont`. Rather than relocate the
/// store — a migration, for one boolean's worth of information — the app
/// mirrors just the family names into the App Group. Same pattern as
/// [WidgetSnapshotStore], and deliberately the smallest thing that answers
/// "is this font saved?" and "what have I saved?".
///
/// Names only: no dates, no file paths, no imported font contents.
enum SavedFontsMirror {
    static let appGroupID = WidgetSnapshotStore.appGroupID
    static let storageKey = "fonti.savedFontNames"

    private static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    /// Saved family names, most recently saved first.
    static func load() -> [String] {
        defaults.stringArray(forKey: storageKey) ?? []
    }

    /// Replace the mirror. Called by the app whenever saved fonts change.
    static func replaceAll(with familyNames: [String]) {
        guard load() != familyNames else { return }
        defaults.set(familyNames, forKey: storageKey)
    }

}
