import Foundation

/// Lightweight bridge for `fonti://preview?family=` deep links from widgets.
enum DeepLinkRouter {
    static let pendingFamilyKey = "fonti.pendingPreviewFamily"

    static func handle(_ url: URL) {
        guard url.scheme == "fonti" else { return }

        // fonti://preview?family=Georgia
        let family: String?
        if url.host == "preview" {
            family = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "family" })?
                .value
        } else if url.path == "/preview" {
            family = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "family" })?
                .value
        } else {
            family = nil
        }

        guard let family, !family.isEmpty else { return }
        UserDefaults.standard.set(family, forKey: pendingFamilyKey)
        NotificationCenter.default.post(name: .fontiPendingDeepLink, object: family)
    }

    static func consumePendingFamily() -> String? {
        let value = UserDefaults.standard.string(forKey: pendingFamilyKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value, !value.isEmpty else { return nil }
        UserDefaults.standard.removeObject(forKey: pendingFamilyKey)
        return value
    }
}
