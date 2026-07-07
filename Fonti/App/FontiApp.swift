import SwiftUI
import SwiftData

@main
struct FontiApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var splashDone = false
    @AppStorage("fonti.hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("fonti.hasRequestedNotifications") private var hasRequestedNotifications = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                if splashDone && hasCompletedOnboarding {
                    RootView()
                        .transition(.opacity)
                }

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
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                handleActive()
            }
        }
        .modelContainer(for: [SavedFont.self, ImportedFont.self])
    }

    // Called every time the app becomes active. Reschedules the "come back"
    // reminder so it always sits 5 days past the user's most recent session,
    // and — once, after onboarding — requests notification permission.
    private func handleActive() {
        NotificationScheduler.rescheduleEngagementReminder()
        guard hasCompletedOnboarding, !hasRequestedNotifications else { return }
        hasRequestedNotifications = true
        Task { _ = await NotificationScheduler.requestPermissionIfNeeded() }
    }
}
