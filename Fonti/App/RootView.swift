import SwiftUI
import SwiftData
import StoreKit

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

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
            WidgetPublisher.indexImports(imports)
            syncWidgetsFromSaved()
        }
        .onReceive(NotificationCenter.default.publisher(for: .fontiPendingDeepLink)) { _ in
            activeTab = .browse
            NotificationCenter.default.post(name: .fontiConsumeDeepLink, object: nil)
        }
        .task {
            await maybeRequestReview(initialDelay: 2.0)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await maybeRequestReview(initialDelay: 1.2) }
        }
    }

    /// Fires the App Store review prompt if a delight-trigger flag is pending
    /// and all guardrails pass. Delay lets the current sheet/transition settle.
    private func maybeRequestReview(initialDelay seconds: Double) async {
        guard ReviewPromptManager.shouldRequestReview() else { return }
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
        guard ReviewPromptManager.shouldRequestReview() else { return }
        requestReview()
        ReviewPromptManager.markPrompted()
    }

    /// Keep the Home Screen widget stocked with the most recent saved fonts.
    private func syncWidgetsFromSaved() {
        let saved = (try? modelContext.fetch(
            FetchDescriptor<SavedFont>(sortBy: [SortDescriptor(\.savedAt, order: .reverse)])
        )) ?? []

        WidgetPublisher.syncFromSaved(
            saved,
            sampleText: UserDefaults.standard.string(forKey: "fonti.defaultSampleText")
        )
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
