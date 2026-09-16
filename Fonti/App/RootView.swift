import SwiftUI
import SwiftData
import StoreKit

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview

    private var navigator = FontiNavigator.shared

    @State private var activeTab: FontiTab = .browse
    @State private var progress: CGFloat = 0
    @State private var hideFloatingTabBar = false
    /// Compare is presented here rather than from the preview screen so an
    /// intent can open it directly, without first navigating into a font.
    @State private var compareSession: CompareSession?

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
            // After registering imports, so imported faces are indexed too.
            await FontSpotlightIndexer.indexAllIfNeeded()
        }
        // Every external entry point — widget tap, Siri, App Shortcut,
        // Spotlight — arrives as a FontiDestination here.
        .onChange(of: navigator.pending) { _, destination in
            guard let destination else { return }
            route(to: destination)
        }
        .task {
            // A cold launch from an intent sets the destination before any view
            // exists, so pick up whatever was already waiting.
            if let destination = navigator.pending {
                route(to: destination)
            }
        }
        .task {
            await maybeRequestReview(initialDelay: 2.0)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await maybeRequestReview(initialDelay: 1.2) }
        }
        .fullScreenCover(item: $compareSession) { session in
            CompareView(session: session)
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

    /// Send a destination to the tab that owns it.
    ///
    /// The only place that knows how Fonti's UI is arranged — intents, widgets
    /// and Spotlight all just name a destination.
    private func route(to destination: FontiDestination) {
        switch destination {
        case .font, .search:
            activeTab = .browse
        case .saved:
            activeTab = .saved
            // Nothing further to resolve, so clear it here; Browse consumes
            // its own destinations once its list is ready.
            _ = navigator.consume()
        case .compare(let left, let right):
            _ = navigator.consume()
            compareSession = CompareSession(
                left: FontFamily(id: left, displayName: left),
                right: FontFamily(id: right, displayName: right),
                initialText: UserDefaults.standard
                    .string(forKey: "fonti.defaultSampleText") ?? ""
            )
        }
    }

    /// Keep the widget and the shared saved-fonts mirror in step with SwiftData.
    ///
    /// The mirror is what lets an App Intent answer "what have I saved?" — the
    /// SwiftData store lives in the app container and intents can't read it.
    private func syncWidgetsFromSaved() {
        let saved = (try? modelContext.fetch(
            FetchDescriptor<SavedFont>(sortBy: [SortDescriptor(\.savedAt, order: .reverse)])
        )) ?? []

        WidgetPublisher.syncFromSaved(
            saved,
            sampleText: UserDefaults.standard.string(forKey: "fonti.defaultSampleText")
        )
        SavedFontsMirror.replaceAll(with: saved.map(\.familyName))
    }
}

#Preview {
    RootView()
        .modelContainer(for: SavedFont.self, inMemory: true)
}
