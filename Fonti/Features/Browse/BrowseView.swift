import SwiftUI
import SwiftData

struct BrowseView: View {
    @State private var model = BrowseModel()
    @State private var liftedFamilyId: String?
    @State private var path: [FontFamily] = []
    @Namespace private var cardNamespace

    @Query(sort: \ImportedFont.familyName) private var imports: [ImportedFont]

    @AppStorage("fonti.defaultSampleText") private var defaultSampleText: String = ""
    @AppStorage("fonti.hapticsEnabled")    private var hapticsEnabled: Bool = true

    private var allFonts: [FontFamily] {
        // Core Text registration makes imported fonts also appear in
        // UIFont.familyNames — strip the system duplicate so each family
        // shows up exactly once (with isImported=true winning, so the
        // amber dot renders).
        let importedNames = Set(imports.map { $0.familyName })
        let system = SystemFontProvider.families()
            .filter { !importedNames.contains($0.id) }
        let imported = imports.map {
            FontFamily(id: $0.familyName, displayName: $0.familyName, isImported: true)
        }
        return (system + imported).sorted { $0.id.lowercased() < $1.id.lowercased() }
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(allFonts) { family in
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
            .navigationDestination(for: FontFamily.self) { family in
                FullScreenPreviewView(family: family, initialText: model.input)
                    .navigationTransition(.zoom(sourceID: family.id, in: cardNamespace))
                    .environment(\.cardNamespace, cardNamespace)
            }
            .onChange(of: path) { _, newPath in
                if newPath.isEmpty {
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
            path.append(family)
        }
    }
}

#Preview {
    BrowseView()
        .modelContainer(for: SavedFont.self, inMemory: true)
}
