import Foundation

/// Payload for launching Compare mode — two families, same starting text.
struct CompareSession: Identifiable, Hashable {
    let left: FontFamily
    let right: FontFamily
    let initialText: String

    var id: String { "\(left.id)|\(right.id)" }

    /// Prefer a curated pairing; otherwise pick a different system family.
    static func make(from family: FontFamily, text: String) -> CompareSession {
        let right: FontFamily
        if let pairName = FontPairings.pairings(for: family.id).first {
            right = FontFamily(id: pairName, displayName: pairName)
        } else if let other = SystemFontProvider.families().first(where: { $0.id != family.id }) {
            right = other
        } else {
            right = FontFamily(id: "Helvetica Neue", displayName: "Helvetica Neue")
        }
        return CompareSession(left: family, right: right, initialText: text)
    }
}
