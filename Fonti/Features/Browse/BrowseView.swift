import SwiftUI

struct BrowseView: View {
    @State private var model = BrowseModel()

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(model.fonts) { family in
                    FontCard(
                        family: family,
                        displayText: model.displayText(for: family)
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .background(Color.fontiInk.ignoresSafeArea())
        .navigationDestination(for: FontFamily.self) { family in
            FullScreenPreviewView(
                family: family,
                initialText: model.input
            )
        }
        .safeAreaInset(edge: .top) {
            inputBar
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
        }
        .navigationTitle("Fonti")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
    }

    private var inputBar: some View {
        TextField("", text: $model.input, axis: .vertical)
            .lineLimit(1...3)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .foregroundStyle(Color.fontiCream)
            .tint(.fontiAmber)
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .glassEffect(in: .capsule)
            .overlay(alignment: .leading) {
                if model.input.isEmpty {
                    Text("Find your type.")
                        .italic()
                        .foregroundStyle(Color.fontiCream.opacity(0.4))
                        .padding(.leading, 22)
                        .allowsHitTesting(false)
                }
            }
    }
}

#Preview {
    NavigationStack { BrowseView() }
}
