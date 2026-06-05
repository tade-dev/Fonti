import SwiftUI

struct RootView: View {
    var body: some View {
        TabView {
            Tab("Browse", systemImage: "textformat") {
                NavigationStack { BrowseView() }
            }
            Tab("Saved", systemImage: "heart") {
                NavigationStack { SavedFontsView() }
            }
        }
        .tint(.fontiAmber)
        .preferredColorScheme(.dark)
        .tabBarMinimizeBehavior(.onScrollDown)
    }
}

#Preview {
    RootView()
}
