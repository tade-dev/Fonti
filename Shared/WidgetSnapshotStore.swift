import Foundation
import WidgetKit

/// Shared App Group payload for Home Screen widgets.
///
/// Deliberately the smallest thing the widget can render from — a few strings
/// per font. The widget never reaches into SwiftData or the font database.
struct WidgetFontEntry: Codable, Hashable, Identifiable {
    var id: String { familyName }
    var familyName: String
    var displayName: String
    var sampleText: String
    /// Imported faces need their file registered with Core Text inside the
    /// extension before `Font.custom` resolves; system faces never do.
    var isImported: Bool
    /// Filename inside `SharedFontContainer.fontsDirectory`, imported fonts only.
    var fileName: String?

    init(
        familyName: String,
        displayName: String,
        sampleText: String,
        isImported: Bool = false,
        fileName: String? = nil
    ) {
        self.familyName = familyName
        self.displayName = displayName
        self.sampleText = sampleText
        self.isImported = isImported
        self.fileName = fileName
    }

    // Hand-rolled so snapshots written by builds that predate `isImported`
    // still decode instead of throwing and blanking the widget.
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        familyName = try container.decode(String.self, forKey: .familyName)
        displayName = try container.decode(String.self, forKey: .displayName)
        sampleText = try container.decode(String.self, forKey: .sampleText)
        isImported = try container.decodeIfPresent(Bool.self, forKey: .isImported) ?? false
        fileName = try container.decodeIfPresent(String.self, forKey: .fileName)
    }
}

enum WidgetSnapshotStore {
    static let appGroupID = "group.com.tade.Fonti"
    static let storageKey = "fonti.widget.snapshot"
    static let maxEntries = 3

    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    /// True while the user hasn't saved or previewed anything — `load()` is
    /// still handing back the seed card rather than real taste. Lets the widget
    /// show a deliberate empty state instead of pretending Georgia is a choice.
    static var hasNoUserFonts: Bool {
        defaults.data(forKey: storageKey) == nil
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

        // Only reload when the payload actually changed. `publish` fires on
        // every preview appearance, and reloading on each one spent the
        // widget's refresh budget redrawing identical pixels.
        guard load() != trimmed else { return }

        defaults.set(data, forKey: storageKey)
        reloadWidgets()
    }

    /// Push a font to the front of the widget rotation (deduped).
    static func publish(
        familyName: String,
        displayName: String? = nil,
        sampleText: String? = nil,
        isImported: Bool = false,
        fileName: String? = nil
    ) {
        let name = familyName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }

        let entry = WidgetFontEntry(
            familyName: name,
            displayName: (displayName ?? name),
            sampleText: resolvedSample(sampleText),
            isImported: isImported,
            fileName: fileName
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
        save(entries.isEmpty ? [fallback] : entries)
    }

    static func reloadWidgets() {
        WidgetCenter.shared.reloadAllTimelines()
    }

    static let fallback = WidgetFontEntry(
        familyName: "Georgia",
        displayName: "Georgia",
        sampleText: "Find your type."
    )

    private static func resolvedSample(_ sample: String?) -> String {
        let trimmed = sample?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty { return "Aa" }
        if trimmed.count > 48 { return String(trimmed.prefix(48)) }
        return trimmed
    }
}
