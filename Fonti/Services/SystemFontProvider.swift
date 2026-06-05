import UIKit

struct FontFamily: Identifiable, Hashable {
    let id: String          // family name (e.g. "Georgia")
    let displayName: String
}

enum SystemFontProvider {
    static func families() -> [FontFamily] {
        UIFont.familyNames
            .filter { !$0.isEmpty && !$0.hasPrefix(".") }
            .sorted()
            .map { FontFamily(id: $0, displayName: $0) }
    }
}
