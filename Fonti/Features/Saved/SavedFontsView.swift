import SwiftUI
import SwiftData

struct SavedFontsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedFont.savedAt, order: .reverse) private var saved: [SavedFont]

    @Binding var tabBarProgress: CGFloat
    @Binding var hideFloatingTabBar: Bool

    @State private var liftedFamilyId: String?
    @State private var path: [FontFamily] = []
    @State private var didAppear = false
    @Namespace private var cardNamespace

    @AppStorage("fonti.hapticsEnabled") private var hapticsEnabled: Bool = true

    init(
        tabBarProgress: Binding<CGFloat> = .constant(0),
        hideFloatingTabBar: Binding<Bool> = .constant(false)
    ) {
        _tabBarProgress = tabBarProgress
        _hideFloatingTabBar = hideFloatingTabBar
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if saved.isEmpty {
                    emptyState
                        .hideNativeTabBar()
                        .safeAreaPadding(.bottom, 50)
                } else {
                    grid
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.fontiInk.ignoresSafeArea())
            .navigationTitle("Saved")
            .toolbarTitleDisplayMode(.inlineLarge)
            .navigationDestination(for: FontFamily.self) { family in
                FullScreenPreviewView(family: family, initialText: "")
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
    }

    private var grid: some View {
        ScrollView {
            StaggeredGrid(
                items: saved,
                columns: 2,
                spacing: 14,
                estimatedHeight: { SavedFontCard.Style.forFamily($0.familyName).minHeight }
            ) { entry in
                let family = FontFamily(id: entry.familyName, displayName: entry.familyName)
                let index = saved.firstIndex(where: { $0.id == entry.id }) ?? 0

                SavedFontCard(
                    family: family,
                    isLifted: liftedFamilyId == family.id,
                    isDimmed: liftedFamilyId != nil && liftedFamilyId != family.id,
                    namespace: cardNamespace,
                    style: .forFamily(family.id)
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
                .transition(.scale.combined(with: .opacity))
                .contextMenu {
                    Button(role: .destructive) { delete(entry) } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .padding(.bottom, 70)
        }
        .adoptForIGTabBar($tabBarProgress)
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
            path.append(family)
        }
    }

    private func delete(_ entry: SavedFont) {
        withAnimation(.snappy(duration: 0.25)) {
            modelContext.delete(entry)
        }
    }
}

#Preview("Empty") {
    SavedFontsView()
        .modelContainer(for: SavedFont.self, inMemory: true)
}
