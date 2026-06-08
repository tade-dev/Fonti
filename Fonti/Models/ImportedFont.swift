import Foundation
import SwiftData

/// A font file the user dropped in via the Files picker.
///
/// The font file itself lives in `Application Support/Fonts/<filename>`. Core
/// Text registration happens at app launch (CustomFontManager.registerAll)
/// and at import time. We persist only the family name and the sandboxed
/// filename — that's enough to re-register on next launch and to delete.
@Model
final class ImportedFont {
    @Attribute(.unique) var familyName: String
    var filename: String
    var importedAt: Date

    init(familyName: String, filename: String, importedAt: Date = .now) {
        self.familyName = familyName
        self.filename = filename
        self.importedAt = importedAt
    }
}
