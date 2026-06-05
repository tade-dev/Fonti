import SwiftUI
import SwiftData

struct FontCard: View {
    let family: FontFamily
    let displayText: String

    @Environment(\.modelContext) private var modelContext
    @Query private var matches: [SavedFont]

    init(family: FontFamily, displayText: String) {
        self.family = family
        self.displayText = displayText
        let name = family.id
        _matches = Query(
            filter: #Predicate<SavedFont> { $0.familyName == name }
        )
    }

    private var isSaved: Bool { !matches.isEmpty }

    var body: some View {
        NavigationLink(value: family) {
            VStack(alignment: .leading, spacing: 14) {
                Text(displayText)
                    .font(.custom(family.id, size: 28))
                    .foregroundStyle(Color.fontiCream)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack {
                    Text(family.displayName.uppercased())
                        .font(.caption2)
                        .tracking(1.2)
                        .foregroundStyle(Color.fontiCream.opacity(0.65))
                    Spacer()
                    Button(action: toggleSaved) {
                        Image(systemName: isSaved ? "heart.fill" : "heart")
                            .foregroundStyle(isSaved ? Color.fontiAmber : Color.fontiCream.opacity(0.65))
                            .contentTransition(.symbolEffect(.replace))
                    }
                    .buttonStyle(.glass)
                    .accessibilityLabel(isSaved ? "Remove from Saved" : "Save font")
                    // Nested Buttons inside NavigationLink can be swallowed; a
                    // high-priority gesture guarantees the heart tap wins.
                    .highPriorityGesture(TapGesture().onEnded { toggleSaved() })
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(in: .rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }

    private func toggleSaved() {
        withAnimation(.snappy(duration: 0.25)) {
            if let existing = matches.first {
                modelContext.delete(existing)
            } else {
                modelContext.insert(SavedFont(familyName: family.id))
            }
        }
    }
}

#Preview {
    ZStack {
        Color.fontiInk.ignoresSafeArea()
        FontCard(
            family: FontFamily(id: "Georgia", displayName: "Georgia"),
            displayText: "The quick brown fox"
        )
        .padding()
    }
    .modelContainer(for: SavedFont.self, inMemory: true)
}
