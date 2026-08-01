import Foundation

/// Recent preview strings — newest first. Shared across fonts.
@MainActor
enum PreviewTextHistory {
    static let key = "fonti.previewTextHistory"
    static let maxEntries = 12

    static let seeds: [String] = [
        "Find your type.",
        "The quick brown fox jumps over the lazy dog",
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
        "Pack my box with five dozen liquor jugs.",
    ]

    static func load() -> [String] {
        guard
            let data = UserDefaults.standard.data(forKey: key),
            let decoded = try? JSONDecoder().decode([String].self, from: data),
            !decoded.isEmpty
        else {
            return seeds
        }
        return decoded
    }

    static func save(_ entries: [String]) {
        let trimmed = Array(entries.prefix(maxEntries))
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    /// Push a finished edit to the front (deduped, non-empty).
    @discardableResult
    static func push(_ raw: String) -> [String] {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return load() }

        var entries = load().filter { $0.caseInsensitiveCompare(value) != .orderedSame }
        entries.insert(value, at: 0)
        save(entries)
        return entries
    }
}
