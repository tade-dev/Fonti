import SwiftUI
import SwiftData

struct SavedFontsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Query(sort: \SavedFont.savedAt, order: .reverse) private var saved: [SavedFont]

    @State private var liftedFamilyId: String?
    @State private var path: [FontFamily] = []
    @State private var didAppear = false
    @Namespace private var cardNamespace

    @AppStorage("fonti.hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("fonti.savedLayout")    private var layoutRaw: String = FontCollectionLayout.grid.rawValue

    private var layout: FontCollectionLayout {
        get { FontCollectionLayout(rawValue: layoutRaw) ?? .grid }
        nonmutating set { layoutRaw = newValue.rawValue }
    }

    var body: some View {
        // Mirrors BrowseView: the collapse a single NavigationSplitView would
        // do at compact width depends on a List-driven selection, and these are
        // custom cards, so the compact path stays an explicit NavigationStack.
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                sidebar
                    // A tight range, because `ideal` is only a hint: given
                    // min 340 / max 480 the system picked 456 and ignored an
                    // ideal of 400. min/max are what actually bind.
                    //
                    // 400pt keeps a two-column card at ~177pt, within 4pt of
                    // the 173.5pt it gets full-width on a normal iPhone, so
                    // cards don't shrink just because there's more screen. At
                    // 280 the names truncate; the detail still gets 551pt.
                    .navigationSplitViewColumnWidth(min: 390, ideal: 400, max: 410)
            } detail: {
                // The detail column needs its own stack, not just a view. A
                // "Pairs well with" chip is a NavigationLink, and with nothing
                // to push into it had no destination and did nothing at all on
                // the inner display and iPad. Rooted at the placeholder, with
                // the same `path` driving it, so a sidebar tap pushes the
                // specimen and a chip pushes the next face on top of it.
                NavigationStack(path: $path) {
                    detailRoot
                        .navigationDestination(for: FontFamily.self) { family in
                            specimen(for: family)
                                // At depth 1 the sidebar is the way back, so a
                                // Back button to an empty placeholder would be
                                // noise. From depth 2 it returns to the face
                                // you came from, which is the point.
                                .navigationBarBackButtonHidden(path.count <= 1)
                        }
                }
            }
        } else {
            NavigationStack(path: $path) {
                sidebar
                    .navigationDestination(for: FontFamily.self) { family in
                        specimen(for: family)
                    }
            }
        }
    }

    private var sidebar: some View {
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
        .toolbar {
            if !saved.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    FontCollectionLayoutToggle(
                        layout: Binding(get: { layout }, set: { layout = $0 })
                    )
                }
            }
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
        .task(id: "saved-enter") {
            guard !didAppear, !saved.isEmpty else { return }
            try? await Task.sleep(for: .milliseconds(40))
            didAppear = true
        }
        .onChange(of: saved.count) { _, count in
            // First heart from empty → play the cascade once.
            if count > 0, !didAppear {
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(40))
                    didAppear = true
                }
            }
        }
    }

    /// Root of the detail stack. No featured face here: Saved can only select
    /// what has been hearted, and the font of the day usually hasn't been — a
    /// tap that does nothing is worse than no tap. The prompt is suppressed on
    /// an empty library, where the sidebar already says "Heart a font to keep
    /// it here" and two prompts is one too many.
    private var detailRoot: some View {
        DetailPlaceholder(hint: saved.isEmpty ? "" : "Pick a typeface.")
    }

    @ViewBuilder
    private func specimen(for family: FontFamily) -> some View {
        FullScreenPreviewView(family: family, initialText: "")
            .id(family.id)
            .navigationTransition(.zoom(sourceID: family.id, in: cardNamespace))
            .environment(\.cardNamespace, cardNamespace)
            .toolbarVisibility(
                horizontalSizeClass == .compact ? .hidden : .automatic,
                for: .tabBar
            )
    }

    private var grid: some View {
        // Built once per body evaluation; reading the computed property inside
        // the cell closure would rebuild it for every card.
        let indices = savedIndices

        return ScrollView {
            FontCollectionView(
                items: saved,
                layout: layout,
                spacing: 14
            ) { (entry: SavedFont) in
                let family = FontFamily(id: entry.familyName, displayName: entry.familyName)
                let index = indices[entry.id] ?? 0
                // Uniform rows in list mode; varied heights are what makes the
                // grid a masonry.
                let style: SavedFontCard.Style = layout == .list
                    ? .compact
                    : .forFamily(family.id)

                SavedFontCard(
                    family: family,
                    isLifted: liftedFamilyId == family.id,
                    isDimmed: horizontalSizeClass == .compact
                        && liftedFamilyId != nil && liftedFamilyId != family.id,
                    namespace: cardNamespace,
                    style: style
                )
                .contentShape(Rectangle())
                .onTapGesture { tapped(family) }
                .opacity(didAppear ? 1 : 0)
                .blur(radius: didAppear ? 0 : 8)
                .offset(y: didAppear ? 0 : 48)
                .scaleEffect(didAppear ? 1 : 0.92)
                .animation(
                    .smooth(duration: 0.7).delay(Double(min(index, 10)) * 0.06 + 0.12),
                    value: didAppear
                )
                // Add/remove only — switching layout re-frames these cards
                // rather than replacing them, so no transition runs for it.
                .transition(.opacity)
                .contextMenu {
                    Button(role: .destructive) { delete(entry) } label: {
                        Label("Remove", systemImage: "trash")
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
            path = [family]
        }
    }

    private func delete(_ entry: SavedFont) {
        // The split view keeps showing whatever is selected, so removing the
        // selected face would leave its specimen on screen with nothing in the
        // list behind it.
        if path.last?.id == entry.familyName {
            path.removeAll()
        }
        withAnimation(.snappy(duration: 0.25)) {
            modelContext.delete(entry)
        }
        WidgetPublisher.refreshSavedMirror(from: modelContext)
    }

    /// Position by persistent id, so the entrance stagger doesn't cost a linear
    /// search per card.
    private var savedIndices: [PersistentIdentifier: Int] {
        Dictionary(uniqueKeysWithValues: saved.enumerated().map { ($0.element.id, $0.offset) })
    }

}

#Preview("Empty") {
    SavedFontsView()
        .modelContainer(for: SavedFont.self, inMemory: true)
}
