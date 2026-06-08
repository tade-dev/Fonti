import UIKit

struct FontFamily: Identifiable, Hashable {
    let id: String              // family name (e.g. "Georgia")
    let displayName: String
    let isImported: Bool

    init(id: String, displayName: String, isImported: Bool = false) {
        self.id = id
        self.displayName = displayName
        self.isImported = isImported
    }

    // Hash + equality by id so navigation paths, queries, etc. treat the same
    // family as equal even if isImported was toggled.
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
    static func == (lhs: FontFamily, rhs: FontFamily) -> Bool { lhs.id == rhs.id }
}

enum SystemFontProvider {
    static func families() -> [FontFamily] {
        UIFont.familyNames
            .filter { !$0.isEmpty && !$0.hasPrefix(".") }
            .sorted()
            .map { FontFamily(id: $0, displayName: $0) }
    }
}
