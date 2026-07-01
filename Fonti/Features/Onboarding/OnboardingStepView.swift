import SwiftUI

struct OnboardingStepView: View {
    let step: OnboardingStep
    let illustrationHeight: CGFloat

    var body: some View {
        VStack(spacing: 28) {
            illustration
                .frame(height: illustrationHeight)
                .frame(maxWidth: .infinity)

            VStack(spacing: 12) {
                Text(step.title)
                    .font(.title2.bold())
                    .foregroundStyle(Color.fontiCream)
                    .multilineTextAlignment(.center)

                Text(step.description)
                    .font(.body)
                    .foregroundStyle(Color.fontiCream.opacity(0.65))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .padding(.top, 12)
    }

    @ViewBuilder
    private var illustration: some View {
        switch step.illustration {
        case .everyFontLive:
            EveryFontLiveIllustration()
        case .pairsThatWork:
            PairsThatWorkIllustration()
        case .keepWhatYouLove:
            KeepWhatYouLoveIllustration()
        }
    }
}

#Preview {
    OnboardingStepView(step: OnboardingStep.all[0], illustrationHeight: 340)
        .background(Color.fontiInk.ignoresSafeArea())
}
