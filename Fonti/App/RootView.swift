import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext

    @State private var activeTab: FontiTab = .browse
    @State private var progress: CGFloat = 0
    @State private var hideFloatingTabBar = false

    var body: some View {
        TabView(selection: $activeTab) {
            
            Tab(value: .browse) {
                BrowseView(tabBarProgress: $progress, hideFloatingTabBar: $hideFloatingTabBar)
            }

            Tab(value: .saved) {
                SavedFontsView(tabBarProgress: $progress, hideFloatingTabBar: $hideFloatingTabBar)
            }

            Tab(value: .settings) {
                NavigationStack {
                    SettingsView()
                        .hideNativeTabBar()
                }
            }

        }
        .preferredColorScheme(.dark)
        .overlay {
            if !hideFloatingTabBar {
                VStack(spacing: 0) {
                    Spacer(minLength: 0)
                    IGStyleTabBar(selection: $activeTab) { tab in
                        let image = UIImage(systemName: tab.symbolImage)?
                            .withConfiguration(UIImage.SymbolConfiguration(font: .systemFont(ofSize: 20)))
                        return image!
                    } onInteraction: {
                        if progress != 0 {
                            withAnimation(.smooth(duration: 0.45)) {
                                progress = 0
                            }
                        }
                    }
                    .padding(4)
                    .glassEffect(.regular.interactive(), in: .capsule)
                    .scaleEffect(1 - (progress * 0.15), anchor: .bottom)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 22)
                }
                .ignoresSafeArea(.container, edges: .bottom)
            }
        }
        .task {
            let imports = (try? modelContext.fetch(FetchDescriptor<ImportedFont>())) ?? []
            CustomFontManager.registerAll(imports)
        }
    }
}

#Preview {
    RootView()
        .modelContainer(for: SavedFont.self, inMemory: true)
}
