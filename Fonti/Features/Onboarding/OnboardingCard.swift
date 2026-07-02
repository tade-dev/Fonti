import SwiftUI

struct OnboardingCard: Identifiable, Hashable {
    var id: String = UUID().uuidString
    var fontName: String
    var displayName: String
    var tint: Color
}

extension OnboardingCard {
    static let all: [OnboardingCard] = [
        OnboardingCard(fontName: "Didot",              displayName: "Didot",     tint: Color(red: 0.36, green: 0.18, blue: 0.42)),
        OnboardingCard(fontName: "Futura",             displayName: "Futura",    tint: Color(red: 0.82, green: 0.44, blue: 0.20)),
        OnboardingCard(fontName: "Chalkduster",        displayName: "Chalk",     tint: Color(red: 0.16, green: 0.34, blue: 0.30)),
        OnboardingCard(fontName: "SnellRoundhand",     displayName: "Snell",     tint: Color(red: 0.20, green: 0.27, blue: 0.47)),
        OnboardingCard(fontName: "MarkerFelt-Wide",    displayName: "Marker",    tint: Color(red: 0.76, green: 0.32, blue: 0.28)),
        OnboardingCard(fontName: "Papyrus",            displayName: "Papyrus",   tint: Color(red: 0.60, green: 0.42, blue: 0.24)),
    ]
}
