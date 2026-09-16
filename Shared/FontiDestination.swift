import Foundation

/// Somewhere in Fonti worth navigating to.
///
/// The one vocabulary shared by every entry point — widget taps, Siri, App
/// Shortcuts, Spotlight — so none of them needs to know how the SwiftUI side
/// is built. An intent says "open this font"; it does not know there's a tab
/// bar, a `NavigationStack`, or a `BrowseView` underneath.
///
/// Round-trips through a `fonti://` URL so the existing `onOpenURL` path and
/// the widget's `widgetURL` keep working unchanged.
enum FontiDestination: Hashable, Sendable {
    /// The full-screen specimen for one family.
    case font(familyName: String)
    /// The Saved tab.
    case saved
    /// Browse, with a search term applied.
    case search(query: String)

    static let scheme = "fonti"

    var url: URL {
        var components = URLComponents()
        components.scheme = Self.scheme

        switch self {
        case .font(let familyName):
            components.host = "preview"
            components.queryItems = [URLQueryItem(name: "family", value: familyName)]
        case .saved:
            components.host = "saved"
        case .search(let query):
            components.host = "search"
            components.queryItems = [URLQueryItem(name: "q", value: query)]
        }

        // Every case above produces a valid URL; the fallback only exists so
        // this stays non-optional at the call sites.
        return components.url ?? URL(string: "\(Self.scheme)://browse")!
    }

    init?(url: URL) {
        guard url.scheme == Self.scheme else { return nil }

        // Tolerate both `fonti://preview` and `fonti:///preview` — the widget
        // builds the former, hand-written links sometimes the latter.
        let host = url.host ?? url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        func value(_ name: String) -> String? {
            items.first { $0.name == name }?.value?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        switch host {
        case "preview":
            guard let family = value("family"), !family.isEmpty else { return nil }
            self = .font(familyName: family)
        case "saved":
            self = .saved
        case "search":
            guard let query = value("q"), !query.isEmpty else { return nil }
            self = .search(query: query)
        default:
            return nil
        }
    }
}
