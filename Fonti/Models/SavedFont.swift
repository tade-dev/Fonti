import Foundation
import SwiftData

@Model
final class SavedFont {
    @Attribute(.unique) var familyName: String
    var savedAt: Date

    init(familyName: String, savedAt: Date = .now) {
        self.familyName = familyName
        self.savedAt = savedAt
    }
}
