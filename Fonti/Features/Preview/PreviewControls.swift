import SwiftUI

/// Glass control capsule that morphs into the text composer when editing.
struct PreviewControls<Share: View>: View {
    let family: FontFamily
    @Binding var size: CGFloat
    @Binding var isBold: Bool
    @Binding var isItalic: Bool
    @Binding var text: String
    let shareSlot: Share
    let isEditing: Bool
    var composerFocused: FocusState<Bool>.Binding
    let onEdit: () -> Void
    let onDone: () -> Void
    var onCompare: (() -> Void)? = nil

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
    }

    // MARK: - Idle controls

    private var controlsColumn: some View {
        VStack(spacing: 12) {
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
                moreMenu
            }
        }
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
                    .lineLimit(2...5)
                    .font(.system(size: 18))
                    .foregroundStyle(Color.fontiCream)
                    .tint(Color.fontiAmber)
                    .textInputAutocapitalization(.sentences)
                    .submitLabel(.done)
                    .focused(composerFocused)
                    .onSubmit { onDone() }
                    .overlay(alignment: .topLeading) {
                        if text.isEmpty {
                            Text("Type anything…")
                                .font(.system(size: 18).italic())
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
