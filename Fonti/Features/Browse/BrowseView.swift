import SwiftUI
import SwiftData

struct BrowseView: View {
    @State private var model = BrowseModel()
    @State private var liftedFamilyId: String?
    @State private var selectedFamily: FontFamily?
    @Namespace private var cardNamespace

    @AppStorage("fonti.defaultSampleText") private var defaultSampleText: String = ""
    @AppStorage("fonti.hapticsEnabled")    private var hapticsEnabled: Bool = true

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 14) {
                ForEach(model.fonts) { family in
                    FontCard(
                        family: family,
                        displayText: model.displayText(for: family, fallback: defaultSampleText),
                        isLifted: liftedFamilyId == family.id,
                        isDimmed: liftedFamilyId != nil && liftedFamilyId != family.id,
                        namespace: cardNamespace,
                        onTap: { tapped(family) }
                    )
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Color.fontiInk.ignoresSafeArea())
        .dismissKeyboardOnBackgroundTap()
        .navigationDestination(item: $selectedFamily) { family in
            FullScreenPreviewView(
                family: family,
                initialText: model.input
            )
            .navigationTransition(.zoom(sourceID: family.id, in: cardNamespace))
        }
        .onChange(of: selectedFamily) { _, newValue in
            if newValue == nil {
                withAnimation(.easeOut(duration: 0.25)) {
                    liftedFamilyId = nil
                }
            }
        }
        .sensoryFeedback(trigger: liftedFamilyId) { _, newValue in
            (hapticsEnabled && newValue != nil) ? .impact(weight: .light) : nil
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

    private func tapped(_ family: FontFamily) {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.72)) {
            liftedFamilyId = family.id
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            selectedFamily = family
        }
    }
}

#Preview {
    NavigationStack { BrowseView() }
        .modelContainer(for: SavedFont.self, inMemory: true)
}
