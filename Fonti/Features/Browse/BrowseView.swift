import SwiftUI
import SwiftData

struct BrowseView: View {
    private var navigator = FontiNavigator.shared

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var model = BrowseModel()
    @State private var liftedFamilyId: String?
    @State private var selection: FontFamily?
    @State private var didAppear = false
    @Namespace private var cardNamespace

    @Query(sort: \ImportedFont.familyName) private var imports: [ImportedFont]

    @AppStorage("fonti.defaultSampleText") private var defaultSampleText: String = ""
    @AppStorage("fonti.hapticsEnabled")    private var hapticsEnabled: Bool = true
    @AppStorage("fonti.browseLayout")      private var layoutRaw: String = FontCollectionLayout.list.rawValue

    /// Built once per imports change rather than on every body evaluation —
    /// it filters, maps and sorts every installed family.
    @State private var allFonts: [FontFamily] = []
    /// Position by family id, so the entrance stagger doesn't cost a linear
    /// search per card.
    @State private var fontIndices: [String: Int] = [:]

    private var layout: FontCollectionLayout {
        get { FontCollectionLayout(rawValue: layoutRaw) ?? .list }
        nonmutating set { layoutRaw = newValue.rawValue }
    }

    private func rebuildFonts() {
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
        let sorted = (system + imported).sorted { $0.id.lowercased() < $1.id.lowercased() }
        allFonts = sorted
        fontIndices = Dictionary(
            uniqueKeysWithValues: sorted.enumerated().map { ($0.element.id, $0.offset) }
        )
    }

    var body: some View {
        // Two containers rather than one. `NavigationSplitView` collapses to a
        // stack at compact width only when its sidebar drives selection through
        // a `List` — Fonti's sidebar is a custom `ScrollView` of cards, so the
        // collapse can't be relied on. Branching keeps the compact path exactly
        // what shipped before, zoom transition and all, and confines the split
        // to the regular-width environments that gain from it: iPhone Duo's
        // inner display, and iPad.
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                sidebar
            } detail: {
                detail
            }
        } else {
            NavigationStack(path: pathBinding) {
                sidebar
                    .navigationDestination(for: FontFamily.self) { family in
                        specimen(for: family)
                    }
            }
        }
    }

    /// The stack's path, projected from `selection` so both containers read one
    /// source of truth. A back-swipe empties the path, which clears selection.
    private var pathBinding: Binding<[FontFamily]> {
        Binding(
            get: { selection.map { [$0] } ?? [] },
            set: { selection = $0.last }
        )
    }

    private var sidebar: some View {
        ScrollView {
            FontCollectionView(
                items: model.filtered(allFonts),
                layout: layout,
                spacing: 14
            ) { family in
                let index = fontIndices[family.id] ?? 0

                FontCard(
                    family: family,
                    displayText: model.displayText(for: family, fallback: defaultSampleText),
                    isLifted: liftedFamilyId == family.id,
                    // Compact only. The dim is the back half of the lift-and-push
                    // transition, and the pushed specimen covers the list a moment
                    // later. In a split view nothing ever covers it, so the sidebar
                    // would sit blurred at 35% for as long as a font is selected.
                    isDimmed: horizontalSizeClass == .compact
                        && liftedFamilyId != nil && liftedFamilyId != family.id,
                    namespace: cardNamespace,
                    isCompact: layout == .grid,
                    onTap: { tapped(family) }
                )
                .opacity(didAppear ? 1 : 0)
                .blur(radius: didAppear ? 0 : 8)
                .offset(y: didAppear ? 0 : 60)
                .scaleEffect(didAppear ? 1 : 0.92)
                .animation(
                    .smooth(duration: 0.75).delay(Double(min(index, 8)) * 0.08 + 0.2),
                    value: didAppear
                )
            }
            .padding(.horizontal, 16)
        }
        .scrollDismissesKeyboard(.immediately)
        .background(Color.fontiInk.ignoresSafeArea())
        .dismissKeyboardOnBackgroundTap()
        .onChange(of: selection) { _, newValue in
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
            VStack(spacing: 8) {
                inputBar
                filterChip
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .opacity(didAppear ? 1 : 0)
            .offset(y: didAppear ? 0 : -30)
            .blur(radius: didAppear ? 0 : 6)
            .animation(.smooth(duration: 0.6).delay(0.1), value: didAppear)
        }
        .task(id: "browse-enter") {
            rebuildFonts()
            guard !didAppear else { return }
            try? await Task.sleep(for: .milliseconds(60))
            didAppear = true
            openPendingDeepLinkIfNeeded()
        }
        .onChange(of: imports.count) { _, _ in
            rebuildFonts()
        }
        .onChange(of: navigator.pending) { _, _ in
            openPendingDeepLinkIfNeeded()
        }
        .navigationTitle("Fonti")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                FontCollectionLayoutToggle(
                    layout: Binding(get: { layout }, set: { layout = $0 })
                )
            }
        }
    }

    @ViewBuilder
    private var detail: some View {
        if let family = selection {
            specimen(for: family)
        } else {
            ZStack {
                Color.fontiInk.ignoresSafeArea()
                Text("Pick a typeface.")
                    .font(.title3)
                    .foregroundStyle(Color.fontiCream.opacity(0.4))
            }
        }
    }

    @ViewBuilder
    private func specimen(for family: FontFamily) -> some View {
        FullScreenPreviewView(family: family, initialText: model.input)
            // A split view keeps one detail view alive across selection
            // changes, and FullScreenPreviewView seeds nine @State properties
            // from `family` and `initialText`. Without re-keying, picking a new
            // face would inherit the previous one's text, size and template.
            .id(family.id)
            .navigationTransition(.zoom(sourceID: family.id, in: cardNamespace))
            .environment(\.cardNamespace, cardNamespace)
            // Hidden only when collapsed: at regular width this bar is iPhone
            // Duo's vertical strip on the trailing edge and has to stay.
            .toolbarVisibility(
                horizontalSizeClass == .compact ? .hidden : .automatic,
                for: .tabBar
            )
    }

    /// Shows what a search request narrowed the list to, and how to undo it.
    ///
    /// A filter arrives from outside the app — Siri, Spotlight, a deep link —
    /// so without this the list would silently be missing fonts with nothing
    /// on screen to explain why.
    @ViewBuilder
    private var filterChip: some View {
        if model.isFiltering {
            let count = model.filtered(allFonts).count

            HStack(spacing: 8) {
                Text(model.filter)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.fontiCream)
                    .lineLimit(1)

                Text("\(count)")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.fontiCream.opacity(0.5))
                    .monospacedDigit()

                Button {
                    withAnimation(.smooth(duration: 0.3)) { model.filter = "" }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color.fontiCream.opacity(0.7))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear filter")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .glassEffect(in: .capsule)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Filtering by \(model.filter), \(count) fonts")
            .transition(.opacity.combined(with: .move(edge: .top)))
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
            selection = family
        }
    }

    /// Act on whatever Siri, a widget or Spotlight asked for.
    ///
    /// Only consumes destinations Browse actually owns, so a `.saved`
    /// destination is left for the Saved tab rather than being swallowed here.
    private func openPendingDeepLinkIfNeeded() {
        switch navigator.pending {
        case .font(let name):
            _ = navigator.consume()
            let family = allFonts.first { $0.id.caseInsensitiveCompare(name) == .orderedSame }
                ?? FontFamily(id: name, displayName: name)
            liftedFamilyId = family.id
            if selection?.id != family.id {
                selection = family
            }

        case .search(let query):
            _ = navigator.consume()
            // Drop back to the list so results are visible, then narrow it.
            // Sets `filter`, never `input` — `input` is the specimen text, so
            // writing the query there would rewrite every card instead of
            // filtering anything.
            selection = nil
            withAnimation(.smooth(duration: 0.3)) {
                model.filter = query
            }

        case .saved, .compare, .none:
            // Owned elsewhere: Saved by the tab, compare by RootView's cover.
            break
        }
    }
}

#Preview {
    BrowseView()
        .modelContainer(for: SavedFont.self, inMemory: true)
}
