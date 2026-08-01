import Foundation

/// Decides when to ask the user for an App Store rating.
///
/// Peak-delight triggers: a completed share, or the user's Nth saved font.
/// The actual `requestReview` call happens in a SwiftUI view via
/// `@Environment(\.requestReview)`; this manager only owns the policy.
enum ReviewPromptManager {
    private enum Key {
        static let installDate = "fonti.review.installDate"
        static let lastPromptedVersion = "fonti.review.lastPromptedVersion"
        static let pendingIntent = "fonti.review.pendingIntent"
    }

    private static let minInstallAge: TimeInterval = 3 * 24 * 60 * 60
    static let savedFontsThreshold = 5

    /// Call once at app launch. Stamps the install date the first time it runs.
    static func bootstrap() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Key.installDate) == nil {
            defaults.set(Date(), forKey: Key.installDate)
        }
    }

    /// Records that the user just tapped Share on a specimen.
    static func noteShareCompleted() {
        UserDefaults.standard.set(true, forKey: Key.pendingIntent)
    }

    /// Records that the user just saved a font. Flags an intent once the
    /// running total reaches the threshold.
    static func noteSavedFontCount(_ count: Int) {
        guard count >= savedFontsThreshold else { return }
        UserDefaults.standard.set(true, forKey: Key.pendingIntent)
    }

    /// True when a trigger has fired *and* all guardrails pass.
    static func shouldRequestReview() -> Bool {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: Key.pendingIntent) else { return false }
        guard defaults.bool(forKey: "fonti.hasCompletedOnboarding") else { return false }

        if let installed = defaults.object(forKey: Key.installDate) as? Date,
           Date().timeIntervalSince(installed) < minInstallAge {
            return false
        }

        if let last = defaults.string(forKey: Key.lastPromptedVersion),
           last == currentVersion {
            return false
        }

        return true
    }

    /// Call after invoking `requestReview()`. Records the version so we don't
    /// re-ask on this build and clears the pending intent.
    static func markPrompted() {
        let defaults = UserDefaults.standard
        defaults.set(currentVersion, forKey: Key.lastPromptedVersion)
        defaults.set(false, forKey: Key.pendingIntent)
    }

    private static var currentVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }
}
