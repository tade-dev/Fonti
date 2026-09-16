import SwiftUI
import SwiftData

struct BrowseView: View {
    @Binding var tabBarProgress: CGFloat
    @Binding var hideFloatingTabBar: Bool

    private var navigator = FontiNavigator.shared

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

    init(
        tabBarProgress: Binding<CGFloat> = .constant(0),
        hideFloatingTabBar: Binding<Bool> = .constant(false)
    ) {
        _tabBarProgress = tabBarProgress
        _hideFloatingTabBar = hideFloatingTabBar
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
        NavigationStack(path: $path) {
            ScrollView {
                FontCollectionView(
                    items: allFonts,
                    layout: layout,
                    spacing: 14
                ) { family in
                    let index = fontIndices[family.id] ?? 0

                    FontCard(
                        family: family,
                        displayText: model.displayText(for: family, fallback: defaultSampleText),
                        isLifted: liftedFamilyId == family.id,
                        isDimmed: liftedFamilyId != nil && liftedFamilyId != family.id,
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
                .padding(.bottom, 24)
            }
            .adoptForIGTabBar($tabBarProgress)
            .scrollDismissesKeyboard(.immediately)
            .background(Color.fontiInk.ignoresSafeArea())
            .dismissKeyboardOnBackgroundTap()
            .navigationDestination(for: FontFamily.self) { family in
                FullScreenPreviewView(family: family, initialText: model.input)
                    .navigationTransition(.zoom(sourceID: family.id, in: cardNamespace))
                    .environment(\.cardNamespace, cardNamespace)
            }
            .onChange(of: path) { _, newPath in
                hideFloatingTabBar = !newPath.isEmpty
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
                path.append(family)
            }

        case .search(let query):
            _ = navigator.consume()
            // Drop back to the list so the results are visible, then seed the
            // existing search field — Fonti already owns the filtering.
            path.removeAll()
            model.input = query

        case .saved, .none:
            break
        }
    }
}

#Preview {
    BrowseView()
        .modelContainer(for: SavedFont.self, inMemory: true)
}
