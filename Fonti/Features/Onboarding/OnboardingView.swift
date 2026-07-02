import SwiftUI
import Combine

struct OnboardingView: View {
    let onComplete: () -> Void

    private let cards = OnboardingCard.all
    private let cardWidth: CGFloat = 220
    private let cardSpacing: CGFloat = 10

    @State private var activeCard: OnboardingCard? = OnboardingCard.all.first
    @State private var scrollPosition: ScrollPosition = .init()
    @State private var currentScrollOffset: CGFloat = 0
    @State private var timer = Timer.publish(every: 0.01, on: .current, in: .default).autoconnect()
    @State private var initialAnimation: Bool = false
    @State private var titleProgress: CGFloat = 0
    @State private var scrollPhase: ScrollPhase = .idle

    var body: some View {
        ZStack {
            Color.fontiInk.ignoresSafeArea()

            AmbientTint()
                .animation(.easeInOut(duration: 1), value: activeCard)

            SplashBackdrop()
                .allowsHitTesting(false)

            BottomShelfGradient()
                .allowsHitTesting(false)

            VStack(spacing: 0) {
                Spacer(minLength: 60)

                InfiniteScrollView(spacing: cardSpacing) {
                    ForEach(cards) { card in
                        carouselCard(card)
                    }
                }
                .scrollIndicators(.hidden)
                .scrollPosition($scrollPosition)
                .scrollClipDisabled()
                .containerRelativeFrame(.vertical) { value, _ in value * 0.38 }
                .onScrollPhaseChange { _, newPhase in
                    scrollPhase = newPhase
                }
                .onScrollGeometryChange(for: CGFloat.self) {
                    $0.contentOffset.x + $0.contentInsets.leading
                } action: { _, newValue in
                    currentScrollOffset = newValue

                    if scrollPhase != .decelerating || scrollPhase != .animating {
                        let stride = cardWidth + cardSpacing
                        let activeIndex = Int((currentScrollOffset / stride).rounded()) % cards.count
                        let safeIndex = (activeIndex + cards.count) % cards.count
                        activeCard = cards[safeIndex]
                    }
                }
                .visualEffect { [initialAnimation] content, proxy in
                    content
                        .offset(y: !initialAnimation ? -(proxy.size.height + 200) : 0)
                }

                Spacer(minLength: 80)

                VStack(spacing: 8) {
                    Text("Welcome to")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(Color.fontiCream.opacity(0.75))
                        .blurOpacityEffect(initialAnimation)

                    Text("Fonti")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundStyle(Color.fontiCream)
                        .textRenderer(TitleTextRenderer(progress: titleProgress))
                        .padding(.bottom, 14)

                    Text("Every font on your device, live.\nPair, preview, and keep the ones you love.")
                        .font(.title3)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(Color.fontiCream.opacity(0.7))
                        .blurOpacityEffect(initialAnimation)
                        .lineLimit(2)
                        .minimumScaleFactor(0.5)
                }

                Spacer(minLength: 40)

                Button(action: onComplete) {
                    Text("Get Started")
                        .foregroundStyle(.black)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)
                .tint(.fontiAmber)
                .controlSize(.large)
                .padding(.horizontal, 8)
                .blurOpacityEffect(initialAnimation)

                Spacer(minLength: 32)
            }
            .safeAreaPadding(15)
        }
        .onReceive(timer) { _ in
            currentScrollOffset += 0.35
            scrollPosition.scrollTo(x: currentScrollOffset)
        }
        .task {
            try? await Task.sleep(for: .seconds(0.35))

            withAnimation(.smooth(duration: 0.75, extraBounce: 0)) {
                initialAnimation = true
            }

            withAnimation(.smooth(duration: 2.5, extraBounce: 0).delay(0.3)) {
                titleProgress = 1
            }
        }
    }

    @ViewBuilder
    private func AmbientTint() -> some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                ForEach(cards) { card in
                    RadialGradient(
                        colors: [card.tint.opacity(0.85), card.tint.opacity(0.0)],
                        center: .init(x: 0.5, y: 0.38),
                        startRadius: 40,
                        endRadius: max(size.width, size.height) * 0.7
                    )
                    .opacity(activeCard?.id == card.id ? 1 : 0)
                }
            }
            .blur(radius: 40)
            .opacity(0.85)
            .ignoresSafeArea()
        }
    }

    @ViewBuilder
    private func BottomShelfGradient() -> some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            LinearGradient(
                colors: [
                    Color.fontiInk.opacity(0),
                    Color.fontiInk.opacity(0.75),
                    Color.fontiInk
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 380)
        }
        .ignoresSafeArea()
    }

    @ViewBuilder
    private func carouselCard(_ card: OnboardingCard) -> some View {
        GeometryReader { proxy in
            let size = proxy.size

            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                card.tint,
                                card.tint.opacity(0.75)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Text(card.displayName)
                    .font(.custom(card.fontName, size: 56))
                    .foregroundStyle(Color.fontiCream)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .padding(.horizontal, 16)
            }
            .frame(width: size.width, height: size.height)
            .shadow(color: .black.opacity(0.4), radius: 10, x: 1, y: 0)
        }
        .frame(width: cardWidth)
        .scrollTransition(.interactive.threshold(.centered), axis: .horizontal) { content, phase in
            content
                .offset(y: phase == .identity ? -10 : 0)
                .rotationEffect(.degrees(phase.value * 5), anchor: .bottom)
        }
    }
}

private extension View {
    func blurOpacityEffect(_ show: Bool) -> some View {
        self
            .blur(radius: show ? 0 : 2)
            .opacity(show ? 1 : 0)
            .scaleEffect(show ? 1 : 0.9)
    }
}

#Preview {
    OnboardingView(onComplete: {})
}
