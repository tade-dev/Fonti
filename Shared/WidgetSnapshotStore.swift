import Foundation
import WidgetKit

/// Shared App Group payload for Home Screen widgets.
struct WidgetFontEntry: Codable, Hashable, Identifiable {
    var id: String { familyName }
    var familyName: String
    var displayName: String
    var sampleText: String
}

enum WidgetSnapshotStore {
    static let appGroupID = "group.com.tade.Fonti"
    static let storageKey = "fonti.widget.snapshot"
    static let maxEntries = 3

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    static func load() -> [WidgetFontEntry] {
        guard
            let data = defaults.data(forKey: storageKey),
            let decoded = try? JSONDecoder().decode([WidgetFontEntry].self, from: data),
            !decoded.isEmpty
        else {
            return [fallback]
        }
        return decoded
    }

    static func save(_ entries: [WidgetFontEntry]) {
        let trimmed = Array(entries.prefix(maxEntries))
        guard let data = try? JSONEncoder().encode(trimmed) else { return }
        defaults.set(data, forKey: storageKey)
        reloadWidgets()
    }

    /// Push a font to the front of the widget rotation (deduped).
    static func publish(
        familyName: String,
        displayName: String? = nil,
        sampleText: String? = nil
    ) {
        let name = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let entry = WidgetFontEntry(
            familyName: name,
            displayName: (displayName ?? name),
            sampleText: resolvedSample(sampleText, fallbackName: displayName ?? name)
        )

        var next = load().filter { $0.familyName.caseInsensitiveCompare(name) != .orderedSame }
        // Replace the seed Georgia card once the user has a real favourite/preview.
        if next.count == 1,
           next[0].familyName == fallback.familyName,
           name.caseInsensitiveCompare(fallback.familyName) != .orderedSame {
            next = []
        }
        next.insert(entry, at: 0)
        save(next)
    }

    static func replaceAll(with entries: [WidgetFontEntry]) {
        if entries.isEmpty {
            save([fallback])
        } else {
            save(entries)
        }
    }

    static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    static let fallback = WidgetFontEntry(
        familyName: "Georgia",
        displayName: "Georgia",
        sampleText: "Find your type."
    )

    private static func resolvedSample(_ sample: String?, fallbackName: String) -> String {
        let trimmed = sample?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty { return "Aa" }
        if trimmed.count > 48 { return String(trimmed.prefix(48)) }
        return trimmed
    }
}
