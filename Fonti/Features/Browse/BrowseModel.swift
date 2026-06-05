import Foundation
import Observation

@Observable
@MainActor
final class BrowseModel {
    var input: String = ""
    let fonts: [FontFamily]

    init(fonts: [FontFamily]) {
        self.fonts = fonts
    }

    convenience init() {
        self.init(fonts: SystemFontProvider.families())
    }

    func displayText(for family: FontFamily) -> String {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? family.displayName : trimmed
    }
}
