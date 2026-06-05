import UIKit

enum FontTraitSupport {
    static func supportsBold(family: String) -> Bool {
        supports(family: family, trait: .traitBold)
    }

    static func supportsItalic(family: String) -> Bool {
        supports(family: family, trait: .traitItalic)
    }

    private static func supports(family: String, trait: UIFontDescriptor.SymbolicTraits) -> Bool {
        let base = UIFontDescriptor(fontAttributes: [.family: family])
        guard let variant = base.withSymbolicTraits(trait) else { return false }
        let font = UIFont(descriptor: variant, size: 16)
        return font.fontDescriptor.symbolicTraits.contains(trait)
            && font.familyName == family
    }
}
