import SwiftUI
import SwiftData

@main
struct FontiApp: App {
    @State private var splashDone = false

    var body: some Scene {
        WindowGroup {
            ZStack {
                RootView()
                if !splashDone {
                    SplashView {
                        withAnimation(.easeOut(duration: 0.45)) {
                            splashDone = true
                        }
                    }
                    .transition(.opacity)
                    .zIndex(1)
                }
            }
            .preferredColorScheme(.dark)
        }
        .modelContainer(for: [SavedFont.self, ImportedFont.self])
    }
}
