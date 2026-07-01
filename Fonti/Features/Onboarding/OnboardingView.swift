import SwiftUI

struct OnboardingView: View {
    let onComplete: () -> Void

    @State private var pageIndex = 0

    private let steps = OnboardingStep.all

    var body: some View {
        GeometryReader { proxy in
            VStack(spacing: 0) {
                TabView(selection: $pageIndex) {
                    ForEach(steps) { step in
                        OnboardingStepView(
                            step: step,
                            illustrationHeight: proxy.size.height * 0.45
                        )
                        .tag(step.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageIndicator
                    .padding(.top, 20)

                continueButton
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 16)
            }
        }
        .background(Color.fontiInk.ignoresSafeArea())
    }

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(steps) { step in
                Capsule()
                    .fill(step.id == pageIndex ? Color.fontiAmber : Color.fontiCream.opacity(0.25))
                    .frame(width: step.id == pageIndex ? 20 : 6, height: 6)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: pageIndex)
    }

    private var continueButton: some View {
        Button(action: advance) {
            Text(pageIndex == steps.count - 1 ? "Get Started" : "Next")
                .font(.headline)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
        .tint(.fontiAmber)
        .controlSize(.large)
    }

    private func advance() {
        if pageIndex == steps.count - 1 {
            onComplete()
        } else {
            withAnimation(.easeInOut(duration: 0.3)) {
                pageIndex += 1
            }
        }
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
