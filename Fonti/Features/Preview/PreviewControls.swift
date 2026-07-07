import SwiftUI

struct PreviewControls<Share: View>: View {
    let family: FontFamily
    @Binding var size: CGFloat
    @Binding var isBold: Bool
    @Binding var isItalic: Bool
    let shareSlot: Share
    let arEnabled: Bool
    let onOpenAR: () -> Void

    private var supportsBold: Bool { FontTraitSupport.supportsBold(family: family.id) }
    private var supportsItalic: Bool { FontTraitSupport.supportsItalic(family: family.id) }

    var body: some View {
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
                arButton
                shareSlot
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 22))
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
