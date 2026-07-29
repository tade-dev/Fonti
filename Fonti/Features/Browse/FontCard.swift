import SwiftUI
import SwiftData

struct FontCard: View {
    let family: FontFamily
    let displayText: String
    let isLifted: Bool
    let isDimmed: Bool
    let namespace: Namespace.ID
    let onTap: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Query private var matches: [SavedFont]
    @AppStorage("fonti.hapticsEnabled") private var hapticsEnabled: Bool = true

    init(
        family: FontFamily,
        displayText: String,
        isLifted: Bool,
        isDimmed: Bool,
        namespace: Namespace.ID,
        onTap: @escaping () -> Void
    ) {
        self.family = family
        self.displayText = displayText
        self.isLifted = isLifted
        self.isDimmed = isDimmed
        self.namespace = namespace
        self.onTap = onTap
        let name = family.id
        _matches = Query(
            filter: #Predicate<SavedFont> { $0.familyName == name }
        )
    }

    private var isSaved: Bool { !matches.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(displayText)
                .font(.custom(family.id, size: 28))
                .foregroundStyle(Color.fontiCream)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .id(displayText)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.25), value: displayText)

            HStack(spacing: 6) {
                if family.isImported {
                    Circle()
                        .fill(Color.fontiAmber)
                        .frame(width: 6, height: 6)
                        .accessibilityLabel("Imported font")
                }
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
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 22))
        .matchedTransitionSource(id: family.id, in: namespace)
        .cardLift(isLifted: isLifted, isDimmed: isDimmed)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .scrollTransition { content, phase in
            content
                .opacity(phase.isIdentity ? 1 : 0.35)
                .scaleEffect(phase.isIdentity ? 1 : 0.96)
        }
        .sensoryFeedback(trigger: isSaved) { _, _ in
            hapticsEnabled ? .selection : nil
        }
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
    @Previewable @Namespace var ns
    ZStack {
        Color.fontiInk.ignoresSafeArea()
        FontCard(
            family: FontFamily(id: "Georgia", displayName: "Georgia"),
            displayText: "The quick brown fox",
            isLifted: false,
            isDimmed: false,
            namespace: ns,
            onTap: {}
        )
        .padding()
    }
    .modelContainer(for: SavedFont.self, inMemory: true)
}
