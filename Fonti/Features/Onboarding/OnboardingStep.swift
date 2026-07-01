import Foundation

struct OnboardingStep: Identifiable {
    let id: Int
    let title: String
    let description: String
}

extension OnboardingStep {
    static let all: [OnboardingStep] = [
        OnboardingStep(
            id: 0,
            title: "Every font, live",
            description: "Type anything and watch it render across every font on your device."
        ),
        OnboardingStep(
            id: 1,
            title: "Pairs that just work",
            description: "Open a pairable font to see designer-approved heading and body combinations."
        ),
        OnboardingStep(
            id: 2,
            title: "Keep what you love",
            description: "Heart your favorites, import your own, and preview any font full screen."
        )
    ]
}
