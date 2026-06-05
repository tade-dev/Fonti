import SwiftUI
import SwiftData

struct RootView: View {
    @AppStorage("fonti.appearance") private var appearance: AppAppearance = .dark

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
        .preferredColorScheme(appearance.colorScheme)
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

#Preview {
    RootView()
        .modelContainer(for: SavedFont.self, inMemory: true)
}
