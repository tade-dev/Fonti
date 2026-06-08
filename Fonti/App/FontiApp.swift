import SwiftUI
import SwiftData

@main
struct FontiApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(for: [SavedFont.self, ImportedFont.self])
    }
}
