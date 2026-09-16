import Foundation

/// The starter strings a specimen can show before the user types their own.
///
/// Used to answer one question: is the current preview text still a default, or
/// did the person actually write it? If it's still a seed, switching layout is
/// free to replace it with that layout's suggested copy.
enum PreviewTextSeeds {
    static let all: [String] = [
        "Find your type.",
        "The quick brown fox jumps over the lazy dog",
        "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
        "Pack my box with five dozen liquor jugs.",
    ]

    static func contains(_ text: String) -> Bool {
        all.contains { $0.caseInsensitiveCompare(text) == .orderedSame }
    }
}
