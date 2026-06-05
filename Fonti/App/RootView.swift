import SwiftUI
import SwiftData

struct RootView: View {
    // Light/System modes are intentionally disabled — Fonti is dark-only for v1.
    // Re-enable by uncommenting the AppStorage above and reading appearance.colorScheme
    // below, and unhiding the Appearance section in SettingsView.
    // @AppStorage("fonti.appearance") private var appearance: AppAppearance = .dark

    var body: some View {
        TabView {
            Tab("Browse", systemImage: "textformat") {
                NavigationStack { BrowseView() }
            }
            Tab("Saved", systemImage: "heart") {
                NavigationStack { SavedFontsView() }
            }
            Tab("Settings", systemImage: "gear") {
                NavigationStack { SettingsView() }
            }
        }
        .tint(.fontiAmber)
        .preferredColorScheme(.dark)
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

#Preview {
    RootView()
        .modelContainer(for: SavedFont.self, inMemory: true)
}
