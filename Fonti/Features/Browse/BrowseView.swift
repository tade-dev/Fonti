import SwiftUI

struct BrowseView: View {
    var body: some View {
        Text("Browse")
            .foregroundStyle(Color.fontiCream)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.fontiInk.ignoresSafeArea())
            .navigationTitle("Fonti")
    }
}

#Preview {
    NavigationStack { BrowseView() }
}
