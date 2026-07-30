import SwiftUI

/// Glass control capsule that morphs into the text composer when editing.
struct PreviewControls<Share: View>: View {
    let family: FontFamily
    @Binding var size: CGFloat
    @Binding var isBold: Bool
    @Binding var isItalic: Bool
    @Binding var text: String
    @Binding var tracking: CGFloat
    @Binding var leading: CGFloat
    let shareSlot: Share
    let isEditing: Bool
    var composerFocused: FocusState<Bool>.Binding
    let onEdit: () -> Void
    let onDone: () -> Void
    var onCompare: (() -> Void)? = nil

    @State private var showKinetic = false

    private var supportsBold: Bool { FontTraitSupport.supportsBold(family: family.id) }
    private var supportsItalic: Bool { FontTraitSupport.supportsItalic(family: family.id) }

    var body: some View {
        Group {
            if isEditing {
                composerColumn
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)),
                            removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom))
                        )
                    )
            } else {
                controlsColumn
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom)),
                            removal: .opacity.combined(with: .scale(scale: 0.96, anchor: .bottom))
                        )
                    )
            }
        }
        .padding(.horizontal, isEditing ? 18 : 16)
        .padding(.vertical, isEditing ? 16 : 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 22))
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: showKinetic)
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: isEditing)
        .onChange(of: isEditing) { _, editing in
            if editing { showKinetic = false }
        }
    }

    // MARK: - Idle controls

    private var controlsColumn: some View {
        VStack(spacing: 12) {
            if showKinetic {
                kineticSliders
                    .transition(.opacity.combined(with: .move(edge: .top)))
            } else {
                sizeSlider
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            HStack(spacing: 10) {
                toggle("B", isOn: $isBold, enabled: supportsBold)
                    .font(.system(size: 16, weight: .bold))
                toggle("I", isOn: $isItalic, enabled: supportsItalic)
                    .font(.system(size: 16).italic())
                kineticButton
                Spacer()
                editButton
                moreMenu
            }
        }
    }

    private var sizeSlider: some View {
        HStack {
            Text("12").font(.caption).foregroundStyle(Color.fontiCream.opacity(0.6))
            Slider(value: $size, in: 12...96)
                .tint(.fontiAmber)
            Text("96").font(.caption).foregroundStyle(Color.fontiCream.opacity(0.6))
        }
    }

    private var kineticSliders: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Text("Tracking")
                    .font(.caption2)
                    .foregroundStyle(Color.fontiCream.opacity(0.55))
                    .frame(width: 58, alignment: .leading)
                Slider(value: $tracking, in: -2...12, step: 0.5)
                    .tint(.fontiAmber)
                Text("\(tracking, specifier: "%g")")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.fontiCream.opacity(0.6))
                    .frame(width: 28, alignment: .trailing)
            }

            HStack(spacing: 10) {
                Text("Leading")
                    .font(.caption2)
                    .foregroundStyle(Color.fontiCream.opacity(0.55))
                    .frame(width: 58, alignment: .leading)
                Slider(value: $leading, in: 0...24, step: 1)
                    .tint(.fontiAmber)
                Text("\(Int(leading))")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Color.fontiCream.opacity(0.6))
                    .frame(width: 28, alignment: .trailing)
            }
        }
    }

    private var kineticButton: some View {
        Button {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.86)) {
                showKinetic.toggle()
            }
        } label: {
            Image(systemName: "arrow.left.and.line.vertical.and.arrow.right")
                .font(.system(size: 13, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
                .padding(.horizontal, 6)
        }
        .buttonStyle(.glass)
        .tint(showKinetic || tracking != 0 || leading != 4 ? .fontiAmber : .fontiCream)
        .accessibilityLabel(showKinetic ? "Show size" : "Tracking and leading")
        .accessibilityValue(showKinetic ? "Kinetic open" : "Kinetic closed")
    }

    // MARK: - Composer (same glass shell)

    private var composerColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Your words")
                .font(.caption2.weight(.semibold))
                .tracking(1.1)
                .textCase(.uppercase)
                .foregroundStyle(Color.fontiCream.opacity(0.45))

            HStack(alignment: .bottom, spacing: 12) {
                TextField("", text: $text, axis: .vertical)
                    .lineLimit(3...8)
                    .font(.system(size: 17))
                    .foregroundStyle(Color.fontiCream)
                    .tint(Color.fontiAmber)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .focused(composerFocused)
                    .onSubmit { onDone() }
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("Type anything…")
                                .font(.system(size: 17).italic())
                                .foregroundStyle(Color.fontiCream.opacity(0.32))
                                .allowsHitTesting(false)
                                .padding(.top, 1)
                        }
                    }

                Button(action: onDone) {
                    Image(systemName: "checkmark")
                        .fontWeight(.semibold)
                        .contentTransition(.symbolEffect(.replace))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.glass)
                .tint(.fontiAmber)
                .accessibilityLabel("Done editing")
            }
        }
    }

    private var editButton: some View {
        Button(action: onEdit) {
            Image(systemName: "pencil")
                .contentTransition(.symbolEffect(.replace))
                .padding(.horizontal, 6)
        }
        .buttonStyle(.glass)
        .tint(.fontiCream)
        .accessibilityLabel("Edit preview text")
    }

    private var moreMenu: some View {
        Menu {
            if let onCompare {
                Button {
                    onCompare()
                } label: {
                    Label("Compare", systemImage: "rectangle.split.2x1")
                }

                Divider()
            }

            shareSlot
        } label: {
            Image(systemName: "ellipsis")
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
        }
        .buttonStyle(.glass)
        .tint(.fontiCream)
        .accessibilityLabel("More")
    }

    private func toggle(_ label: String, isOn: Binding<Bool>, enabled: Bool) -> some View {
        Button {
            isOn.wrappedValue.toggle()
        } label: {
            Text(label)
                .frame(width: 28, height: 24)
        }
        .buttonStyle(.glass)
        .tint(isOn.wrappedValue && enabled ? .fontiAmber : .fontiCream)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
        .onChange(of: enabled) { _, nowEnabled in
            if !nowEnabled { isOn.wrappedValue = false }
        }
        .accessibilityLabel("\(label) \(isOn.wrappedValue ? "on" : "off")")
    }
}
