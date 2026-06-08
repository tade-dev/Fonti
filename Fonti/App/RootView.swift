import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    // Light/System modes are intentionally disabled — Fonti is dark-only for v1.
    // Re-enable by uncommenting the AppStorage above and reading appearance.colorScheme
    // below, and unhiding the Appearance section in SettingsView.
    // @AppStorage("fonti.appearance") private var appearance: AppAppearance = .dark

    var body: some View {
        TabView {
            // Browse and Saved own their own NavigationStack so they can
            // manage a typed [FontFamily] path (lets pair-chip taps in the
            // Preview push more previews through a single destination).
            Tab("Browse", systemImage: "textformat") {
                BrowseView()
            }
            Tab("Saved", systemImage: "heart") {
                SavedFontsView()
            }
            Tab("Settings", systemImage: "gear") {
                NavigationStack { SettingsView() }
            }
        }
        .tint(.fontiAmber)
        .preferredColorScheme(.dark)
        .tabBarMinimizeBehavior(.onScrollDown)
        .task {
            // Register every persisted ImportedFont with Core Text once at
            // launch. CTFont registration doesn't survive across app launches.
            let imports = (try? modelContext.fetch(FetchDescriptor<ImportedFont>())) ?? []
            CustomFontManager.registerAll(imports)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: SavedFont.self, inMemory: true)
}
