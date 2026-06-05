import SwiftUI
import SwiftData

struct SavedFontsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedFont.savedAt, order: .reverse) private var saved: [SavedFont]

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
        .navigationDestination(for: FontFamily.self) { family in
            FullScreenPreviewView(family: family, initialText: "")
        }
    }

    private var grid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 14) {
                ForEach(saved) { entry in
                    let family = FontFamily(id: entry.familyName, displayName: entry.familyName)
                    NavigationLink(value: family) {
                        SavedFontCard(family: family)
                    }
                    .buttonStyle(.plain)
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
