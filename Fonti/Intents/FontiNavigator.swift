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

    /// A font file handed to Fonti from outside — Files, Mail, a share sheet.
    ///
    /// Separate from `pending` because it isn't a destination: nothing has been
    /// imported yet, and the user still has to confirm.
    private(set) var pendingFontFile: URL?

    private init() {}

    func go(to destination: FontiDestination) {
        pending = destination
    }

    /// Route anything the system opens Fonti with.
    ///
    /// Two kinds arrive here: `fonti://` deep links, and font files from
    /// `CFBundleDocumentTypes`. A file URL is offered for import rather than
    /// imported outright — adding to someone's library off a single tap in
    /// Files is too much to assume.
    func handle(_ url: URL) {
        if let destination = FontiDestination(url: url) {
            go(to: destination)
            return
        }
        guard url.isFileURL else { return }
        pendingFontFile = url
    }

    func consumeFontFile() -> URL? {
        defer { pendingFontFile = nil }
        return pendingFontFile
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
    case noPairings(String)
    case noSimilarFonts(String)
    case sameFontTwice(String)

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .fontUnavailable(let name):
            return "\(name) isn't available on this device."
        case .noPairings(let name):
            return "Fonti doesn't have a pairing for \(name) yet."
        case .noSimilarFonts(let name):
            return "Fonti couldn't find anything close to \(name) on this device."
        case .sameFontTwice(let name):
            return "Pick two different typefaces — both were \(name)."
        }
    }
}
