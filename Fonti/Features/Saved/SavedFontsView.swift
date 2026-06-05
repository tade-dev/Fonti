import SwiftUI

struct SavedFontsView: View {
    var body: some View {
        Text("Saved")
            .foregroundStyle(Color.fontiCream)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.fontiInk.ignoresSafeArea())
            .navigationTitle("Saved")
    }
}

#Preview {
    NavigationStack { SavedFontsView() }
}
