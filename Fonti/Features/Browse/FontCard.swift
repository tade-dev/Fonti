import SwiftUI
import SwiftData

struct FontCard: View {
    let family: FontFamily
    let displayText: String
    let isLifted: Bool
    let isDimmed: Bool
    let namespace: Namespace.ID
    /// Half-width cell in the staggered grid — smaller specimen, tighter box.
    let isCompact: Bool
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
        isCompact: Bool = false,
        onTap: @escaping () -> Void
    ) {
        self.family = family
        self.displayText = displayText
        self.isLifted = isLifted
        self.isDimmed = isDimmed
        self.namespace = namespace
        self.isCompact = isCompact
        self.onTap = onTap
        let name = family.id
        _matches = Query(
            filter: #Predicate<SavedFont> { $0.familyName == name }
        )
    }

    private var isSaved: Bool { !matches.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: isCompact ? 10 : 14) {
            Text(displayText)
                .font(.custom(family.id, size: isCompact ? 20 : 28))
                .foregroundStyle(Color.fontiCream)
                // A narrow cell needs more lines to say the same thing.
                .lineLimit(isCompact ? 3 : 2)
                .minimumScaleFactor(isCompact ? 0.7 : 1)
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
                    .tracking(isCompact ? 0.8 : 1.2)
                    .foregroundStyle(Color.fontiCream.opacity(0.65))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Button(action: toggleSaved) {
                    Image(systemName: isSaved ? "heart.fill" : "heart")
                        .foregroundStyle(isSaved ? Color.fontiAmber : Color.fontiCream.opacity(0.65))
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.glass)
                .accessibilityLabel(isSaved ? "Remove from Saved" : "Save font")
            }
        }
        .padding(isCompact ? 14 : 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: isCompact ? 18 : 22))
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
        defer { WidgetPublisher.refreshSavedMirror(from: modelContext) }

        withAnimation(.snappy(duration: 0.25)) {
            if let existing = matches.first {
                modelContext.delete(existing)
            } else {
                modelContext.insert(SavedFont(familyName: family.id))
                let sample = UserDefaults.standard.string(forKey: "fonti.defaultSampleText")
                WidgetPublisher.publish(family: family, sampleText: sample)
                let total = (try? modelContext.fetchCount(FetchDescriptor<SavedFont>())) ?? 0
                ReviewPromptManager.noteSavedFontCount(total)
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
