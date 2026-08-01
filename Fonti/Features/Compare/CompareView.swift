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

    @AppStorage("fonti.hapticsEnabled") private var hapticsEnabled: Bool = true

    init(session: CompareSession) {
        _left = State(initialValue: session.left)
        _right = State(initialValue: session.right)
        _text = State(initialValue: session.initialText)
        let stored = UserDefaults.standard.double(forKey: "fonti.defaultPreviewSize")
        _size = State(initialValue: stored == 0 ? 36 : min(CGFloat(stored), 48))
    }

    private var previewText: String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Compare" : text
    }

    /// Lift in the middle of the flight (0→1→0 via sine).
    private var swapLift: CGFloat {
        sin(swapFlight * .pi)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                GeometryReader { geo in
                    let gap: CGFloat = 10
                    let cardWidth = (geo.size.width - gap) / 2
                    let travel = cardWidth + gap

                    ZStack {
                        compareColumn(for: .left, family: left)
                            .frame(width: cardWidth, height: geo.size.height)
                            .modifier(SwapFlightModifier(
                                side: .left,
                                flight: swapFlight,
                                lift: swapLift,
                                travel: travel
                            ))

                        compareColumn(for: .right, family: right)
                            .frame(width: cardWidth, height: geo.size.height)
                            .modifier(SwapFlightModifier(
                                side: .right,
                                flight: swapFlight,
                                lift: swapLift,
                                travel: travel
                            ))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxHeight: .infinity)

                controls
                    .opacity(isSwapping ? 0.45 : 1)
                    .allowsHitTesting(!isSwapping)
            }
            .padding(16)
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
                    Button {
                        performSwap()
                    } label: {
                        Image(systemName: "arrow.left.arrow.right")
                            .rotationEffect(.degrees(swapIconRotation))
                    }
                    .tint(.fontiCream)
                    .disabled(isSwapping)
                    .accessibilityLabel("Swap fonts")
                }
            }
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

    private func compareColumn(for side: CompareSide, family: FontFamily) -> some View {
        VStack(spacing: 12) {
            Spacer(minLength: 0)

            Text(previewText)
                .font(styledFont(for: family))
                .foregroundStyle(Color.fontiCream)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.4)
                .lineLimit(6)
                .padding(.horizontal, 8)
                .animation(.snappy(duration: 0.2), value: previewText)
                .animation(.snappy(duration: 0.2), value: size)
                .contentTransition(.interpolate)

            Spacer(minLength: 0)

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
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .glassEffect(in: .rect(cornerRadius: 22))
    }

    // MARK: - Shared controls

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
            }

            if showComposer {
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

    private func styledFont(for family: FontFamily) -> Font {
        var font = Font.custom(family.id, size: size)
        if isBold { font = font.bold() }
        if isItalic { font = font.italic() }
        return font
    }
}

// MARK: - Flight motion

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
