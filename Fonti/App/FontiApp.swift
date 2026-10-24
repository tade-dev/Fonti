import SwiftUI
import SwiftData

@main
struct FontiApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var splashDone = false
    @State private var showWelcome = false
    @AppStorage("fonti.hasSeenWelcome") private var hasSeenWelcome = false
    @AppStorage("fonti.hasRequestedNotifications") private var hasRequestedNotifications = false

    init() {
        ReviewPromptManager.bootstrap()

        // Anyone who finished the old onboarding is not a first-time user, so
        // don't greet them again on update. One-way and idempotent; the old
        // key is never written after this.
        let defaults = UserDefaults.standard
        if defaults.bool(forKey: "fonti.hasCompletedOnboarding"),
           !defaults.bool(forKey: "fonti.hasSeenWelcome") {
            defaults.set(true, forKey: "fonti.hasSeenWelcome")
        }
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                // Straight to Home after the splash. First-time users get the
                // welcome sheet over it rather than a screen in front of it.
                if splashDone {
                    RootView()
                        .transition(.opacity)
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
            // Presented here rather than in RootView, which already owns a
            // sheet for an incoming font file — two `.sheet` modifiers on one
            // view conflict and only one of them ever presents.
            //
            // Keyed to the splash finishing so it arrives over Home, with the
            // app already behind it, rather than on top of the splash.
            .onChange(of: splashDone) { _, done in
                guard done, !hasSeenWelcome else { return }
                showWelcome = true
            }
            .sheet(isPresented: $showWelcome) {
                WelcomeSheet { showWelcome = false }
                    // On disappear rather than in the button, so a swipe down
                    // counts as seen too and nobody is greeted twice.
                    .onDisappear { hasSeenWelcome = true }
            }
            .onOpenURL { url in
                FontiNavigator.shared.handle(url)
            }
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                handleActive()
            }
        }
        .modelContainer(for: [SavedFont.self, ImportedFont.self])
    }

    // Called every time the app becomes active. Reschedules the "come back"
    // reminder so it always sits 5 days past the user's most recent session,
    // and — once the welcome sheet is behind them — asks for notification
    // permission.
    private func handleActive() {
        // Detached, not `Task { }`: this target defaults to MainActor
        // isolation, so an inherited-context task would still run the blocking
        // XPC call on the main thread.
        Task.detached(priority: .utility) {
            NotificationScheduler.rescheduleEngagementReminder()
        }
        guard hasSeenWelcome, !hasRequestedNotifications else { return }
        hasRequestedNotifications = true
        Task { _ = await NotificationScheduler.requestPermissionIfNeeded() }
    }
}
