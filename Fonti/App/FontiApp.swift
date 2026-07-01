import SwiftUI
import SwiftData

@main
struct FontiApp: App {
    @State private var splashDone = false
    @AppStorage("fonti.hasCompletedOnboarding") private var hasCompletedOnboarding = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()

                if splashDone && !hasCompletedOnboarding {
                    OnboardingView {
                        withAnimation(.easeOut(duration: 0.35)) {
                            hasCompletedOnboarding = true
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }

                if !splashDone {
                    SplashView {
                        withAnimation(.easeOut(duration: 0.45)) {
                            splashDone = true
                        }
                    }
                    .transition(.opacity)
                    .zIndex(2)
                }
            }
            .preferredColorScheme(.dark)
        }
        .modelContainer(for: [SavedFont.self, ImportedFont.self])
    }
}
