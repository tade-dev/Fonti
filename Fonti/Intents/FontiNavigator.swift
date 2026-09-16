import Foundation
import Observation

/// The one way anything outside the UI asks Fonti to navigate.
///
/// Intents, widget taps and Spotlight results all post a `FontiDestination`
/// here; `RootView` observes it and does the actual SwiftUI work. That keeps
/// the intent layer free of navigation detail and means there's a single place
/// to change when the UI is restructured.
///
/// A pending destination survives a cold launch: an intent can set it before
/// any view exists, and the first `RootView` to appear consumes it.
@MainActor
@Observable
final class FontiNavigator {
    static let shared = FontiNavigator()

    /// Set by intents and deep links; cleared once the UI has acted on it.
    private(set) var pending: FontiDestination?

    private init() {}

    func go(to destination: FontiDestination) {
        pending = destination
    }

    func handle(_ url: URL) {
        guard let destination = FontiDestination(url: url) else { return }
        go(to: destination)
    }

    /// Take the pending destination, if any. Consuming clears it so a tab
    /// switch or a re-render doesn't navigate a second time.
    func consume() -> FontiDestination? {
        defer { pending = nil }
        return pending
    }
}

/// Failures an intent can report.
///
/// `CustomLocalizedStringResourceConvertible` is what makes the message
/// actually surface to the user — a plain `Error` shows a generic failure.
enum FontiIntentError: Error, CustomLocalizedStringResourceConvertible {
    case fontUnavailable(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .fontUnavailable(let name):
            return "\(name) isn't available on this device."
        }
    }
}
