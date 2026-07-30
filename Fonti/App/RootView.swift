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
            syncWidgetsFromSaved()
        }
        .onReceive(NotificationCenter.default.publisher(for: .fontiPendingDeepLink)) { _ in
            activeTab = .browse
            NotificationCenter.default.post(name: .fontiConsumeDeepLink, object: nil)
        }
    }

    /// Keep the Home Screen widget stocked with up to 3 saved fonts.
    private func syncWidgetsFromSaved() {
        let saved = (try? modelContext.fetch(
            FetchDescriptor<SavedFont>(sortBy: [SortDescriptor(\.savedAt, order: .reverse)])
        )) ?? []

        let sample = UserDefaults.standard.string(forKey: "fonti.defaultSampleText")
        let entries = saved.prefix(3).map {
            WidgetFontEntry(
                familyName: $0.familyName,
                displayName: $0.familyName,
                sampleText: {
                    let trimmed = sample?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    return trimmed.isEmpty ? "Aa" : trimmed
                }()
            )
        }
        WidgetSnapshotStore.replaceAll(with: Array(entries))
    }
}

extension Notification.Name {
    static let fontiPendingDeepLink = Notification.Name("fonti.pendingDeepLink")
    static let fontiConsumeDeepLink = Notification.Name("fonti.consumeDeepLink")
}

#Preview {
    RootView()
        .modelContainer(for: SavedFont.self, inMemory: true)
}
