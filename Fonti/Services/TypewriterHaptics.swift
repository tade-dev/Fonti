import UIKit

/// Soft per-keystroke ticks while typing specimen text.
@MainActor
enum TypewriterHaptics {
    private static var lastTick: Date = .distantPast
    private static let minInterval: TimeInterval = 0.04
    private static let generator = UIImpactFeedbackGenerator(style: .soft)

    static func prepare() {
        generator.prepare()
    }

    /// Tick only on inserts (not deletes), rate-limited.
    static func tickIfNeeded(from old: String, to new: String, enabled: Bool) {
        guard enabled, new.count > old.count else { return }

        let now = Date()
        guard now.timeIntervalSince(lastTick) >= minInterval else { return }
        lastTick = now
        generator.impactOccurred(intensity: 0.42)
    }
}
