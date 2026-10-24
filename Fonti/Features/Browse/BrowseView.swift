import SwiftUI
import SwiftData

struct BrowseView: View {
    private var navigator = FontiNavigator.shared

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @State private var model = BrowseModel()
    @State private var liftedFamilyId: String?
    @State private var path: [FontFamily] = []
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
            VStack(spacing: 8) {
                inputBar
                filterChip
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            // The bar is a floating glass capsule, and the inset holding it had
            // no background — so cards scrolling underneath showed through the
            // margins either side of the capsule and were hard-clipped at the
            // screen edge. A scrim fades them out instead, mirroring
            // OnboardingView's BottomShelfGradient rather than inventing a new
            // treatment, and keeps the capsule floating rather than sitting on
            // an opaque bar. Invisible at the top of the list, where there is
            // nothing behind it to hide.
            .background {
                // Stops rather than even colours, and a shorter tail. The
                // even three-colour version faded across roughly half its
                // height, which on the 669pt-tall inner display left the first
                // card half-ghosted over ~42pt — readable enough to look like a
                // rendering fault rather than a deliberate fade. Holding opaque
                // to 82% and falling away over the last 18% keeps cards crisp
                // until they are nearly at the bar, then takes them quickly.
                LinearGradient(
                    stops: [
                        .init(color: Color.fontiInk, location: 0),
                        .init(color: Color.fontiInk, location: 0.82),
                        .init(color: Color.fontiInk.opacity(0), location: 1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .padding(.bottom, -18)
                .allowsHitTesting(false)
                .ignoresSafeArea(edges: .top)
            }
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
            // The wordmark replaces the title text. `navigationTitle` stays
            // set above so VoiceOver and the back button still have "Fonti" —
            // the principal item only changes what is drawn.
            ToolbarItem(placement: .principal) {
                Image("FontiWordmark")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 22)
                    .accessibilityLabel("Fonti")
            }

            ToolbarItem(placement: .topBarTrailing) {
                FontCollectionLayoutToggle(
                    layout: Binding(get: { layout }, set: { layout = $0 })
                )
            }
        }
    }

    /// Root of the detail stack. The specimen is pushed over this rather than
    /// swapped in, so the chips have somewhere to go.
    private var detailRoot: some View {
        DetailPlaceholder(
            hint: "Pick a typeface.",
            featured: featuredFamily,
            onPick: { path = [$0] }
        )
    }

    /// Today's curated face, resolved against what is actually installed —
    /// `FeaturedFont` returns nil when nothing in its pool can be rendered.
    private var featuredFamily: FontFamily? {
        guard let name = FeaturedFont.familyName() else { return nil }
        return allFonts.first { $0.id.caseInsensitiveCompare(name) == .orderedSame }
            ?? FontFamily(id: name, displayName: name)
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
            path = [family]
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
            if path.last?.id != family.id {
                path = [family]
            }

        case .search(let query):
            _ = navigator.consume()
            // Drop back to the list so results are visible, then narrow it.
            // Sets `filter`, never `input` — `input` is the specimen text, so
            // writing the query there would rewrite every card instead of
            // filtering anything.
            path.removeAll()
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
