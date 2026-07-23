import SwiftUI

/// Glass control capsule that morphs into the text composer when editing.
struct PreviewControls<Share: View>: View {
    let family: FontFamily
    @Binding var size: CGFloat
    @Binding var isBold: Bool
    @Binding var isItalic: Bool
    @Binding var text: String
    let shareSlot: Share
    let arEnabled: Bool
    let isEditing: Bool
    var composerFocused: FocusState<Bool>.Binding
    let onEdit: () -> Void
    let onDone: () -> Void
    let onOpenAR: () -> Void

    private var supportsBold: Bool { FontTraitSupport.supportsBold(family: family.id) }
    private var supportsItalic: Bool { FontTraitSupport.supportsItalic(family: family.id) }

    var body: some View {
        Group {
            if isEditing {
                composerRow
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96)),
                            removal: .opacity.combined(with: .scale(scale: 1.02))
                        )
                    )
            } else {
                controlsColumn
                    .transition(
                        .asymmetric(
                            insertion: .opacity.combined(with: .scale(scale: 0.96)),
                            removal: .opacity.combined(with: .scale(scale: 0.96))
                        )
                    )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, isEditing ? 14 : 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(in: .rect(cornerRadius: 22))
        .animation(.spring(response: 0.42, dampingFraction: 0.86), value: isEditing)
    }

    // MARK: - Idle controls

    private var controlsColumn: some View {
        VStack(spacing: 14) {
            HStack {
                Text("12").font(.caption).foregroundStyle(Color.fontiCream.opacity(0.6))
                Slider(value: $size, in: 12...96)
                    .tint(.fontiAmber)
                Text("96").font(.caption).foregroundStyle(Color.fontiCream.opacity(0.6))
            }

            HStack(spacing: 10) {
                toggle("B", isOn: $isBold, enabled: supportsBold)
                    .font(.system(size: 16, weight: .bold))
                toggle("I", isOn: $isItalic, enabled: supportsItalic)
                    .font(.system(size: 16).italic())
                Spacer()
                editButton
                arButton
                shareSlot
            }
        }
    }

    // MARK: - Composer (same capsule)

    private var composerRow: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField("", text: $text, axis: .vertical)
                .lineLimit(1...3)
                .font(.system(size: 17))
                .foregroundStyle(Color.fontiCream)
                .tint(Color.fontiAmber)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.done)
                .focused(composerFocused)
                .onSubmit { onDone() }
                .overlay(alignment: .leading) {
                    if text.isEmpty {
                        Text("Your words.")
                            .font(.system(size: 17).italic())
                            .foregroundStyle(Color.fontiCream.opacity(0.35))
                            .allowsHitTesting(false)
                    }
                }

            Button(action: onDone) {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .contentTransition(.symbolEffect(.replace))
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.glass)
            .tint(.fontiAmber)
            .accessibilityLabel("Done editing")
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

    private var arButton: some View {
        Button {
            onOpenAR()
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        } label: {
            Image(systemName: "cube.transparent")
                .padding(.horizontal, 6)
        }
        .buttonStyle(.glass)
        .tint(.fontiCream)
        .disabled(!arEnabled)
        .opacity(arEnabled ? 1 : 0.35)
        .accessibilityLabel("Place in AR")
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
