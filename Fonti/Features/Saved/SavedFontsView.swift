import SwiftUI
import SwiftData

struct SavedFontsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedFont.savedAt, order: .reverse) private var saved: [SavedFont]

    @State private var liftedFamilyId: String?
    @State private var selectedFamily: FontFamily?
    @Namespace private var cardNamespace

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        Group {
            if saved.isEmpty {
                emptyState
            } else {
                grid
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fontiInk.ignoresSafeArea())
        .navigationTitle("Saved")
        .toolbarTitleDisplayMode(.inlineLarge)
        .navigationDestination(item: $selectedFamily) { family in
            FullScreenPreviewView(family: family, initialText: "")
                .navigationTransition(.zoom(sourceID: family.id, in: cardNamespace))
        }
        .onChange(of: selectedFamily) { _, newValue in
            if newValue == nil {
                withAnimation(.easeOut(duration: 0.25)) {
                    liftedFamilyId = nil
                }
            }
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(saved) { entry in
                    let family = FontFamily(id: entry.familyName, displayName: entry.familyName)
                    SavedFontCard(
                        family: family,
                        isLifted: liftedFamilyId == family.id,
                        isDimmed: liftedFamilyId != nil && liftedFamilyId != family.id,
                        namespace: cardNamespace
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { tapped(family) }
                    .transition(.scale.combined(with: .opacity))
                    .contextMenu {
                        Button(role: .destructive) { delete(entry) } label: {
                            Label("Remove", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private var emptyState: some View {
        Text("Heart a font to keep it here.")
            .font(.body)
            .foregroundStyle(Color.fontiCream.opacity(0.5))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 32)
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

    private func delete(_ entry: SavedFont) {
        withAnimation(.snappy(duration: 0.25)) {
            modelContext.delete(entry)
        }
    }
}

#Preview("Empty") {
    NavigationStack { SavedFontsView() }
        .modelContainer(for: SavedFont.self, inMemory: true)
}
