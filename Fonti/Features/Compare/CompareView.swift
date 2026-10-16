import SwiftUI

/// Side-by-side font compare — same text, size, and traits; swap either column.
struct CompareView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var left: FontFamily
    @State private var right: FontFamily
    @State private var text: String
    @State private var size: CGFloat
    @State private var isBold = false
    @State private var isItalic = false
    @State private var pickingSide: CompareSide?
    @State private var showComposer = false
    @FocusState private var composerFocused: Bool

    /// 0 = idle, 1 = cards have flown to opposite seats (then we snap data + reset).
    @State private var swapFlight: CGFloat = 0
    @State private var isSwapping = false
    @State private var swapIconRotation: Double = 0

    /// Live container size; the arrangement is decided by its shape.
    @State private var containerSize: CGSize = .zero

    @AppStorage("fonti.hapticsEnabled") private var hapticsEnabled: Bool = true

    init(session: CompareSession) {
        _left = State(initialValue: session.left)
        _right = State(initialValue: session.right)
        _text = State(initialValue: session.initialText)
        let stored = UserDefaults.standard.double(forKey: "fonti.defaultPreviewSize")
        _size = State(initialValue: stored == 0 ? 36 : min(CGFloat(stored), 48))
    }

    /// Empty text falls back to each column's *own* family name, matching
    /// the full-screen preview — never one shared fallback string.
    private func previewText(for family: FontFamily) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? family.displayName : text
    }

    /// Regular width (iPad, big phones in landscape) or compact height (any
    /// phone in landscape, Duo unfolded): go edge to edge.
    private var isWide: Bool {
        AdaptiveLayout.comparePrefersSideBySide(containerSize)
    }

    /// Lift in the middle of the flight (0→1→0 via sine).
    private var swapLift: CGFloat {
        sin(swapFlight * .pi)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isWide {
                    wideLayout
                } else {
                    compactLayout
                }
            }
            .animation(AdaptiveLayout.transition, value: isWide)
            .onGeometryChange(for: CGSize.self) { $0.size } action: { containerSize = $0 }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.fontiInk.ignoresSafeArea())
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .tint(.fontiAmber)
                        .disabled(isSwapping)
                }
                ToolbarItem(placement: .topBarLeading) {
                    swapButton
                }
            }
            .toolbar(isWide ? .visible : .hidden, for: .navigationBar)
            .sheet(item: $pickingSide) { side in
                CompareFontPicker(
                    excluding: side == .left ? right.id : left.id
                ) { picked in
                    withAnimation(.smooth(duration: 0.28)) {
                        switch side {
                        case .left: left = picked
                        case .right: right = picked
                        }
                    }
                    pickingSide = nil
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Layouts

    /// Portrait phone: the original stacked layout, cards over controls.
    /// Compact (portrait, folded Duo): both fonts always on screen, stacked
    /// top and bottom with a hairline. The split arrangement is skipped here:
    /// held to `.horizontal` in a narrow container it seats only one pane.
    private var compactLayout: some View {
        VStack(spacing: 0) {
            compactTopBar

            GeometryReader { geo in
                let half = (geo.size.height - 1) / 2
                VStack(spacing: 0) {
                    wideColumn(for: .left, family: left)
                        .frame(height: half)
                        .modifier(StackedSwapEffect(side: .left, flight: swapFlight, lift: swapLift, travel: half + 1))
                    HairlineDivider(axis: .horizontal)
                        .padding(.horizontal, 24)
                        .opacity(isSwapping ? 0 : 1)
                    wideColumn(for: .right, family: right)
                        .frame(height: half)
                        .modifier(StackedSwapEffect(side: .right, flight: swapFlight, lift: swapLift, travel: half + 1))
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            floatingControlBar
                .opacity(isSwapping ? 0.45 : 1)
                .allowsHitTesting(!isSwapping)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .transition(.opacity)
    }

    /// In-content top bar for compact: Swap and Done live together up top
    /// instead of the system relocating Swap to a side rail.
    private var compactTopBar: some View {
        HStack {
            swapButton
                .buttonStyle(.glass)
            Spacer()
            Text("Compare").font(.headline).foregroundStyle(Color.fontiCream)
            Spacer()
            Button("Done") { dismiss() }
                .buttonStyle(.glass)
                .tint(.fontiAmber)
                .disabled(isSwapping)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    private var swapButton: some View {
        Button {
            performSwap()
        } label: {
            Image(systemName: isWide ? "arrow.left.arrow.right" : "arrow.up.arrow.down")
                .rotationEffect(.degrees(swapIconRotation))
        }
        .tint(.fontiCream)
        .disabled(isSwapping)
        .accessibilityLabel("Swap fonts")
    }

    /// Wide: two full-bleed halves split by a hairline, controls floating in
    /// one compact glass bar at bottom centre.
    private var wideLayout: some View {
        comparePanes
            .overlay {
                HairlineDivider()
                    .padding(.vertical, 8)
                    .opacity(isSwapping ? 0 : 1)
                    .animation(.smooth(duration: 0.2), value: isSwapping)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                floatingControlBar
                    .opacity(isSwapping ? 0.45 : 1)
                    .allowsHitTesting(!isSwapping)
                    .padding(.bottom, 8)
            }
            .transition(.opacity)
    }

    // MARK: - Panes

    /// fileprivate so SwapFlightEffect, which lives alongside, can size the
    /// crossing travel from the same gap the layout uses. `nonisolated`
    /// because the target defaults to MainActor isolation and visualEffect's
    /// closure is not — an error, not a warning, under Swift 6.
    nonisolated fileprivate static let paneGap: CGFloat = 10

    /// Two typefaces side by side is exactly what a split arrangement is for,
    /// and on iPhone Duo it earns something the hand-rolled version can't: when
    /// the device is partially folded the system seats each pane on its own
    /// half of the book rather than letting one straddle the hinge.
    ///
    /// Held to `.horizontal`. A split arrangement would otherwise stack
    /// vertically whenever it is taller than wide, which is every phone in
    /// portrait — and side by side is the comparison, not an artefact of the
    /// old layout.
    @ViewBuilder
    private var comparePanes: some View {
        if #available(iOS 27.1, *) {
            ArrangementView {
                compareColumn(for: .left, family: left)
                    .modifier(SwapFlightEffect(
                        side: .left, flight: swapFlight, lift: swapLift
                    ))
            } secondary: {
                compareColumn(for: .right, family: right)
                    .modifier(SwapFlightEffect(
                        side: .right, flight: swapFlight, lift: swapLift
                    ))
            }
            .arrangementViewStyle(.split.axes([.horizontal]))
        } else {
            legacyPanes
        }
    }

    /// Pre-27.1 layout, unchanged: the panes are seated by hand inside a
    /// ZStack so they can fly across each other.
    private var legacyPanes: some View {
        GeometryReader { geo in
            let gap = Self.paneGap
            let cardWidth = (geo.size.width - gap) / 2
            let travel = cardWidth + gap

            ZStack {
                compareColumn(for: .left, family: left)
                    .frame(width: cardWidth, height: geo.size.height)
                    .modifier(SwapFlightModifier(
                        side: .left, flight: swapFlight, lift: swapLift, travel: travel
                    ))

                compareColumn(for: .right, family: right)
                    .frame(width: cardWidth, height: geo.size.height)
                    .modifier(SwapFlightModifier(
                        side: .right, flight: swapFlight, lift: swapLift, travel: travel
                    ))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Swap

    private func performSwap() {
        guard !isSwapping else { return }
        isSwapping = true

        if hapticsEnabled {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }

        withAnimation(.spring(response: 0.42, dampingFraction: 0.78)) {
            swapIconRotation += 180
        }

        // Cards arc across to each other's seats.
        withAnimation(.easeInOut(duration: 0.58)) {
            swapFlight = 1
        }

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(580))

            // Data swap + reset transforms with no animation — already visually swapped.
            var snap = Transaction()
            snap.disablesAnimations = true
            withTransaction(snap) {
                swap(&left, &right)
                swapFlight = 0
            }

            if hapticsEnabled {
                UIImpactFeedbackGenerator(style: .soft).impactOccurred(intensity: 0.7)
            }

            isSwapping = false
        }
    }

    // MARK: - Columns

    @ViewBuilder
    private func compareColumn(for side: CompareSide, family: FontFamily) -> some View {
        if isWide {
            wideColumn(for: side, family: family)
        } else {
            cardColumn(for: side, family: family)
        }
    }

    /// Wide half: picker on top, sample text grows to fill the half. The
    /// slider still drives size; the larger scale plus minimumScaleFactor
    /// lets text use the space without overflowing.
    private func wideColumn(for side: CompareSide, family: FontFamily) -> some View {
        VStack(spacing: 0) {
            fontPickerButton(for: side, family: family)
                .padding(.top, 8)

            Text(previewText(for: family))
                .font(styledFont(for: family, scale: 1.8))
                .foregroundStyle(Color.fontiCream)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.2)
                .lineLimit(8)
                .padding(.horizontal, 24)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .animation(.snappy(duration: 0.2), value: text)
                .animation(.snappy(duration: 0.2), value: size)
                .contentTransition(.interpolate)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.fontiInk)
        .contentShape(.rect)
    }

    private func cardColumn(for side: CompareSide, family: FontFamily) -> some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            Text(previewText(for: family))
                .font(styledFont(for: family))
                .foregroundStyle(Color.fontiCream)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.4)
                .lineLimit(6)
                .padding(.horizontal, 8)
                .animation(.snappy(duration: 0.2), value: text)
                .animation(.snappy(duration: 0.2), value: size)
                .contentTransition(.interpolate)

            Spacer(minLength: 0)

            fontPickerButton(for: side, family: family)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassEffect(in: .rect(cornerRadius: 22))
    }

    private func fontPickerButton(for side: CompareSide, family: FontFamily) -> some View {
            Button {
                guard !isSwapping else { return }
                pickingSide = side
            } label: {
                HStack(spacing: 6) {
                    Text(family.displayName)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                        .opacity(0.55)
                }
                .foregroundStyle(Color.fontiCream.opacity(0.75))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassEffect(in: .capsule)
            }
            .buttonStyle(.plain)
            .disabled(isSwapping)
            .accessibilityLabel("Change \(side == .left ? "left" : "right") font")
    }

    // MARK: - Shared controls

    /// Wide: one compact bar — slider, B, I, edit — with the composer
    /// sliding in above it.
    private var floatingControlBar: some View {
        VStack(spacing: 10) {
            if showComposer {
                composerField
                    .frame(maxWidth: 520)
            }

            FloatingGlassBar {
                Image(systemName: "textformat.size.smaller")
                    .font(.caption)
                    .foregroundStyle(Color.fontiCream.opacity(0.6))
                Slider(value: $size, in: 12...72)
                    .tint(.fontiAmber)
                    .frame(minWidth: 72, maxWidth: 200)
                    .accessibilityLabel("Text size")
                Image(systemName: "textformat.size.larger")
                    .font(.caption)
                    .foregroundStyle(Color.fontiCream.opacity(0.6))

                traitToggle("B", isOn: $isBold)
                    .font(.system(size: 16, weight: .bold))
                traitToggle("I", isOn: $isItalic)
                    .font(.system(size: 16).italic())
                editButton
            }
        }
        .animation(.smooth(duration: 0.3), value: showComposer)
    }

    private var composerField: some View {
        TextField("Your words.", text: $text, axis: .vertical)
            .lineLimit(1...3)
            .font(.system(size: 16))
            .foregroundStyle(Color.fontiCream)
            .tint(.fontiAmber)
            .focused($composerFocused)
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .glassEffect(in: .rect(cornerRadius: 16))
            .transition(.opacity.combined(with: .move(edge: .bottom)))
    }

    private var editButton: some View {
                Button {
                    showComposer.toggle()
                    if showComposer {
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(40))
                            composerFocused = true
                        }
                    } else {
                        composerFocused = false
                    }
                } label: {
                    Image(systemName: showComposer ? "checkmark" : "pencil")
                        .padding(.horizontal, 6)
                }
                .buttonStyle(.glass)
                .tint(showComposer ? .fontiAmber : .fontiCream)
                .accessibilityLabel(showComposer ? "Done editing" : "Edit text")
    }

    private var controls: some View {
        VStack(spacing: 12) {
            HStack {
                Text("12").font(.caption).foregroundStyle(Color.fontiCream.opacity(0.6))
                Slider(value: $size, in: 12...72)
                    .tint(.fontiAmber)
                Text("72").font(.caption).foregroundStyle(Color.fontiCream.opacity(0.6))
            }

            HStack(spacing: 10) {
                traitToggle("B", isOn: $isBold)
                    .font(.system(size: 16, weight: .bold))
                traitToggle("I", isOn: $isItalic)
                    .font(.system(size: 16).italic())

                Spacer(minLength: 8)

                editButton
            }

            if showComposer {
                composerField
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 22))
        .animation(.smooth(duration: 0.3), value: showComposer)
    }

    private func traitToggle(_ label: String, isOn: Binding<Bool>) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Text(label)
                .frame(width: 28, height: 24)
        }
        .buttonStyle(.glass)
        .tint(isOn.wrappedValue ? .fontiAmber : .fontiCream)
    }

    private func styledFont(for family: FontFamily, scale: CGFloat = 1) -> Font {
        var font = Font.custom(family.id, size: size * scale)
        if isBold { font = font.bold() }
        if isItalic { font = font.italic() }
        return font
    }
}

// MARK: - Flight motion

/// The arrangement seats each pane itself, so unlike `SwapFlightModifier` there
/// is no resting offset to apply — only the crossing travel. That distance
/// comes from the pane's own width through `visualEffect`, which reads geometry
/// without a parent `GeometryReader` and without disturbing layout.
@available(iOS 27.1, *)
private struct SwapFlightEffect: ViewModifier {
    let side: CompareSide
    let flight: CGFloat
    let lift: CGFloat

    func body(content: Content) -> some View {
        let direction: CGFloat = side == .left ? 1 : -1

        content
            .visualEffect { view, proxy in
                view.offset(
                    x: direction * flight * (proxy.size.width + CompareView.paneGap),
                    y: -lift * 18
                )
            }
            .rotation3DEffect(
                .degrees(Double(direction) * Double(lift) * 42),
                axis: (x: 0.15, y: 1, z: 0.05),
                perspective: 0.55
            )
            .scaleEffect(1 - lift * 0.06)
            .shadow(
                color: .black.opacity(0.25 + Double(lift) * 0.25),
                radius: 12 + lift * 16,
                y: 8 + lift * 10
            )
            .zIndex(side == .left ? (flight < 0.5 ? 2 : 1) : (flight < 0.5 ? 1 : 2))
    }
}

/// Vertical twin of the flight for the stacked compact layout.
private struct StackedSwapEffect: ViewModifier {
    let side: CompareSide
    let flight: CGFloat
    let lift: CGFloat
    let travel: CGFloat

    func body(content: Content) -> some View {
        let direction: CGFloat = side == .left ? 1 : -1
        content
            .offset(x: lift * 18 * direction, y: direction * flight * travel)
            .scaleEffect(1 - lift * 0.06)
            .shadow(color: .black.opacity(Double(lift) * 0.4), radius: 12 + lift * 16, y: 8)
            .zIndex(side == .left ? (flight < 0.5 ? 2 : 1) : (flight < 0.5 ? 1 : 2))
    }
}

private struct SwapFlightModifier: ViewModifier {
    let side: CompareSide
    let flight: CGFloat
    let lift: CGFloat
    let travel: CGFloat

    func body(content: Content) -> some View {
        let direction: CGFloat = side == .left ? 1 : -1
        // Start seated left/right of center.
        let restX: CGFloat = side == .left ? -(travel / 2) : (travel / 2)

        content
            .offset(
                x: restX + direction * flight * travel,
                y: -lift * 18
            )
            .rotation3DEffect(
                .degrees(Double(direction) * Double(lift) * 42),
                axis: (x: 0.15, y: 1, z: 0.05),
                perspective: 0.55
            )
            .scaleEffect(1 - lift * 0.06)
            .shadow(
                color: .black.opacity(0.25 + Double(lift) * 0.25),
                radius: 12 + lift * 16,
                y: 8 + lift * 10
            )
            // Crossing card flies in front.
            .zIndex(side == .left ? (flight < 0.5 ? 2 : 1) : (flight < 0.5 ? 1 : 2))
    }
}

private enum CompareSide: Identifiable {
    case left, right
    var id: String { self == .left ? "left" : "right" }
}

// MARK: - Font picker

private struct CompareFontPicker: View {
    let excluding: String
    let onPick: (FontFamily) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var families: [FontFamily] {
        SystemFontProvider.families()
            .filter { $0.id != excluding }
            .filter {
                query.isEmpty
                    || $0.displayName.localizedCaseInsensitiveContains(query)
            }
    }

    var body: some View {
        NavigationStack {
            List(families) { family in
                Button {
                    onPick(family)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Ag")
                            .font(.custom(family.id, size: 28))
                            .foregroundStyle(Color.fontiCream)
                        Text(family.displayName)
                            .font(.caption)
                            .foregroundStyle(Color.fontiCream.opacity(0.55))
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(Color.fontiInk)
            }
            .scrollContentBackground(.hidden)
            .background(Color.fontiInk.ignoresSafeArea())
            .searchable(text: $query, prompt: "Search fonts")
            .navigationTitle("Choose font")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .tint(.fontiCream)
                }
            }
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.medium, .large])
    }
}

#Preview {
    CompareView(
        session: CompareSession(
            left: FontFamily(id: "Georgia", displayName: "Georgia"),
            right: FontFamily(id: "Helvetica Neue", displayName: "Helvetica Neue"),
            initialText: "Find your type."
        )
    )
}
