// Fonti/Services/RatingPrompt.swift
//
// Tracks a lifetime capture count so the caller can decide when to invoke
// SKStoreReviewController / RequestReviewAction. Apple already throttles
// review prompts to ~3 per year, so this file only handles "when does
// the app *want* to ask" — not the "when does the OS *allow* it" side.

import Foundation

@MainActor
enum RatingPrompt {
    private static let captureCountKey = "fonti.inSpace.captureCount"

    /// Increments the persistent capture count and returns the new total.
    @discardableResult
    static func recordCapture() -> Int {
        let count = UserDefaults.standard.integer(forKey: captureCountKey) + 1
        UserDefaults.standard.set(count, forKey: captureCountKey)
        return count
    }

    static var totalCaptures: Int {
        UserDefaults.standard.integer(forKey: captureCountKey)
    }
}
